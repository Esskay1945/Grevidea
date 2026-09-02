/// EPIC 3: Sustainable Marketplaces & Circular Economy (Tools T19–T28)

use crate::{auth::AuthUser, error::{AppError, AppResult}, models::*, AppState};
use axum::{extract::{Path, Query, State}, Json};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

// ── T19 — Carbon Cap & Trade Market ──────────────────────────────────────────

// List a carbon credit for sale
pub async fn list_carbon_credits(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CreateListingRequest>,
) -> AppResult<Json<ApiResponse<MarketplaceListing>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    if req.listing_type != "carbon_credit" && req.listing_type != "borrow"
        && req.listing_type != "trade" && req.listing_type != "donate" {
        return Err(AppError::BadRequest("Invalid listing type".into()));
    }

    let listing = sqlx::query_as::<_, MarketplaceListing>(
        r#"INSERT INTO marketplace_listings
           (seller_id, title, description, listing_type, carbon_credits, price_points, latitude, longitude)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
           RETURNING id, seller_id, title, description, listing_type, carbon_credits, price_points, is_available, latitude, longitude, created_at"#
    )
    .bind(user_id)
    .bind(&req.title)
    .bind(&req.description)
    .bind(&req.listing_type)
    .bind(req.carbon_credits)
    .bind(req.price_points)
    .bind(req.latitude)
    .bind(req.longitude)
    .fetch_one(&state.db).await?;

    state.brain.log_event("marketplace_listing_created", Some(&auth.0.sub), json!({
        "listing_id": listing.id,
        "type": req.listing_type,
        "carbon_credits": req.carbon_credits,
    })).await;

    Ok(Json(ApiResponse::ok(listing)))
}

pub async fn get_marketplace(
    State(state): State<AppState>,
    _auth: AuthUser,
    Query(p): Query<Pagination>,
) -> AppResult<Json<ApiResponse<Vec<MarketplaceListing>>>> {
    let offset = ((p.page - 1) * p.limit) as i64;
    let listings = sqlx::query_as::<_, MarketplaceListing>(
        r#"SELECT id, seller_id, title, description, listing_type, carbon_credits, price_points, is_available, latitude, longitude, created_at
           FROM marketplace_listings WHERE is_available = TRUE
           ORDER BY created_at DESC LIMIT $1 OFFSET $2"#
    )
    .bind(p.limit as i64)
    .bind(offset)
    .fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(listings)))
}

// ── T19b — Carbon Credit Trade (ACID transaction) ─────────────────────────────

#[derive(Deserialize)]
pub struct TradeRequest {
    pub listing_id: String,
}

pub async fn execute_trade(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<TradeRequest>,
) -> AppResult<Json<ApiResponse<serde_json::Value>>> {
    let buyer_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;
    let listing_id = Uuid::parse_str(&req.listing_id)
        .map_err(|_| AppError::BadRequest("Invalid listing ID".into()))?;

    // Fetch listing
    let listing = sqlx::query_as::<_, MarketplaceListing>(
        "SELECT id, seller_id, title, description, listing_type, carbon_credits, price_points, is_available, latitude, longitude, created_at
         FROM marketplace_listings WHERE id = $1 AND is_available = TRUE"
    )
    .bind(listing_id)
    .fetch_optional(&state.db).await?
    .ok_or_else(|| AppError::NotFound("Listing not found or already traded".into()))?;

    if listing.seller_id == buyer_id {
        return Err(AppError::BadRequest("Cannot buy your own listing".into()));
    }

    let price = listing.price_points.unwrap_or(0);
    let credits = listing.carbon_credits.unwrap_or(0.0);

    // Check buyer has enough points
    let buyer_balance: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(delta), 0) FROM green_points_ledger WHERE user_id = $1"
    ).bind(buyer_id).fetch_one(&state.db).await?.unwrap_or(0);

    if buyer_balance < price as i64 {
        return Err(AppError::BadRequest(format!("Insufficient points: have {}, need {}", buyer_balance, price)));
    }

    // ACID transaction: deduct from buyer, add to seller, mark listing sold
    let mut tx = state.db.begin().await?;

    sqlx::query("INSERT INTO green_points_ledger (user_id, delta, reason, reference_id) VALUES ($1, $2, $3, $4)")
        .bind(buyer_id).bind(-(price as i32)).bind("Carbon credit purchase").bind(listing_id)
        .execute(&mut *tx).await?;

    sqlx::query("INSERT INTO green_points_ledger (user_id, delta, reason, reference_id) VALUES ($1, $2, $3, $4)")
        .bind(listing.seller_id).bind(price).bind("Carbon credit sale").bind(listing_id)
        .execute(&mut *tx).await?;

    sqlx::query("UPDATE marketplace_listings SET is_available = FALSE WHERE id = $1")
        .bind(listing_id).execute(&mut *tx).await?;

    tx.commit().await?;

    state.brain.log_event("carbon_trade_completed", Some(&auth.0.sub), json!({
        "listing_id": listing_id, "seller_id": listing.seller_id,
        "price_points": price, "carbon_credits_kg": credits,
    })).await;

    Ok(Json(ApiResponse::with_message(json!({
        "traded": true, "listing_id": listing_id.to_string(),
        "carbon_credits_kg": credits, "points_spent": price,
    }), &format!("Trade complete! You acquired {:.1}kg of carbon credits for {} points.", credits, price))))
}

// ── T20 — EcoLens Product Scanner ─────────────────────────────────────────────

pub async fn scan_product(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<EcoLensScanRequest>,
) -> AppResult<Json<ApiResponse<EcoLensScanResult>>> {
    // Try OpenFoodFacts API first
    let off_url = format!("https://world.openfoodfacts.org/api/v2/product/{}.json", req.barcode);
    let off_resp = state.brain.http.get(&off_url)
        .header("User-Agent", "Grevidea/1.0")
        .send().await;

    let (name, brand, ecoscore, co2, water, packaging, certs, origin, organic) = match off_resp {
        Ok(r) if r.status().is_success() => {
            if let Ok(v) = r.json::<serde_json::Value>().await {
                let p = &v["product"];
                let name = p["product_name"].as_str().unwrap_or("Unknown Product").to_string();
                let brand = p["brands"].as_str().unwrap_or("Unknown").to_string();
                let eco_grade = p["ecoscore_grade"].as_str().unwrap_or("unknown");
                let eco_score = match eco_grade {
                    "a" => 90u8, "b" => 72, "c" => 55, "d" => 35, "e" => 15, _ => 50,
                };
                let co2_val = p["ecoscore_data"]["agribalyse"]["co2_total"]
                    .as_f64().unwrap_or(0.5);
                let water_val = co2_val * 15.0; // approximation
                let pkg_score = p["ecoscore_data"]["adjustments"]["packaging"]["score"]
                    .as_u64().unwrap_or(50) as u8;
                let origin = p["origins"].as_str().unwrap_or("Unknown").to_string();
                let is_organic = p["labels_tags"].as_array()
                    .map(|a| a.iter().any(|l| l.as_str().map(|s| s.contains("organic")).unwrap_or(false)))
                    .unwrap_or(false);
                let mut cert_list: Vec<String> = Vec::new();
                if is_organic { cert_list.push("Organic".to_string()); }
                if let Some(labels) = p["labels"].as_str() {
                    for l in labels.split(',').take(3) {
                        cert_list.push(l.trim().to_string());
                    }
                }
                (name, brand, eco_score, co2_val, water_val, pkg_score, cert_list, origin, is_organic)
            } else {
                fallback_product(&req.barcode, req.product_name.as_deref())
            }
        }
        _ => fallback_product(&req.barcode, req.product_name.as_deref()),
    };

    let grade = match ecoscore {
        80..=100 => "A", 60..=79 => "B", 40..=59 => "C", 20..=39 => "D", _ => "E",
    };

    let rec = if ecoscore >= 75 {
        "Excellent choice! This product has a low environmental impact.".to_string()
    } else if ecoscore >= 50 {
        "Moderate impact. Consider looking for organic or locally-sourced alternatives.".to_string()
    } else {
        "High environmental impact. We have greener alternatives for you!".to_string()
    };

    state.brain.log_event("product_scanned", Some(&auth.0.sub), json!({
        "barcode": req.barcode, "product": name, "ecoscore": ecoscore,
    })).await;

    Ok(Json(ApiResponse::ok(EcoLensScanResult {
        barcode: req.barcode,
        product_name: name,
        brand,
        ecoscore_grade: grade.to_string(),
        sustainability_score: ecoscore,
        co2_per_unit_kg: (co2 * 1000.0).round() / 1000.0,
        water_per_unit_l: (water * 10.0).round() / 10.0,
        packaging_score: packaging,
        certifications: certs,
        origin_country: origin,
        is_organic: organic,
        recommendation: rec,
        source: "openfoodfacts".to_string(),
    })))
}

fn fallback_product(_barcode: &str, name: Option<&str>) -> (String, String, u8, f64, f64, u8, Vec<String>, String, bool) {
    let product_name = name.unwrap_or("Unknown Product").to_string();
    (product_name, "Unknown".into(), 50, 0.5, 7.5, 50, vec![], "Unknown".into(), false)
}

// ── T25 — Green Product Recommender ───────────────────────────────────────────

const GREEN_ALTERNATIVES: &[(&str, &str, &str, u8, f64, &str, &str, &str)] = &[
    // (category, product, brand, score, co2, certs, why_better, price)
    ("toothbrush",  "Bamboo Toothbrush",         "Colgate Bamboo",    92, 0.02, "FSC",          "Biodegradable handle replaces 300 years of plastic", "₹80-150"),
    ("toothbrush",  "Neem Wood Toothbrush",      "Purexa",            95, 0.01, "Organic",      "Traditional neem with natural antimicrobial properties", "₹60-100"),
    ("shampoo",     "Shampoo Bar",               "The Body Shop",     88, 0.05, "Cruelty-Free", "Zero plastic packaging, lasts 80+ washes", "₹350-600"),
    ("shampoo",     "Refillable Shampoo",        "Bare Necessities",  85, 0.08, "Organic",      "Refill pouches use 85% less plastic", "₹250-400"),
    ("detergent",   "Soap Nut Wash",             "EcoNut",            95, 0.01, "Organic",      "Natural berry-based cleaning, fully compostable", "₹200-350"),
    ("detergent",   "Enzyme-based Detergent",    "Koparo",            87, 0.06, "Plant-Based",  "Biodegradable formula, no phosphates or SLS", "₹300-500"),
    ("trash_bag",   "Compostable Trash Bags",    "NatureZway",        90, 0.03, "BPI Certified","Breaks down in 6 months vs 500 years for plastic", "₹150-250"),
    ("water_bottle","Stainless Steel Bottle",    "Milton",            92, 0.15, "BIS",          "Replaces 1500+ single-use plastic bottles in lifetime", "₹400-800"),
    ("water_bottle","Copper Water Bottle",       "IndianArtVilla",    90, 0.20, "Handmade",     "Ayurvedic health benefits + zero plastic", "₹500-900"),
    ("food_wrap",   "Beeswax Food Wrap",         "Superbee",          93, 0.01, "Organic",      "Replaces single-use plastic wrap, reusable 150+ times", "₹300-500"),
    ("food_wrap",   "Silicone Food Covers",      "IKEA",              85, 0.10, "BPA-Free",     "Stretchy reusable covers replacing cling film", "₹200-400"),
    ("straw",       "Steel Straw Set",           "FinalStraw",        95, 0.05, "Recyclable",   "Lifetime reusable, replaces 500+ plastic straws", "₹150-300"),
    ("straw",       "Bamboo Straw Set",          "Bamboo India",      97, 0.005,"Organic",      "100% biodegradable, handmade by artisans", "₹100-200"),
    ("soap",        "Cold-Process Natural Soap",  "Rustic Art",       93, 0.02, "Organic,Vegan","Plastic-free, palm-oil free, handcrafted", "₹150-250"),
    ("tissue",      "Bamboo Toilet Paper",       "Beco",              88, 0.03, "FSC",          "Bamboo grows 30x faster than trees, no bleach", "₹300-500"),
    ("coffee",      "Organic Fair Trade Coffee", "Blue Tokai",        85, 0.30, "Fair Trade",   "Shade-grown, supporting small Indian farmers", "₹400-700"),
    ("snack",       "Millet-based Snacks",       "Slurrp Farm",       82, 0.05, "Organic",      "Low-water crop replacing rice/wheat, nutritious", "₹100-200"),
    ("cleaning",    "Vinegar All-Purpose Cleaner","Koparo",            90, 0.02, "Plant-Based",  "No toxic chemicals, safe for waterways", "₹200-350"),
    ("bag",         "Jute Shopping Bag",         "EcoRight",          95, 0.03, "Handmade",     "Biodegradable, supports rural artisans", "₹100-200"),
    ("bag",         "Recycled Plastic Backpack", "Freitag",           80, 0.15, "Recycled",     "Made from ocean-bound plastic waste", "₹1500-3000"),
    ("menstrual",   "Menstrual Cup",             "Sirona",            97, 0.01, "Medical Grade","Replaces 2400 pads in 10 years, zero waste", "₹350-500"),
    ("menstrual",   "Cloth Pads",                "Ecofemme",          93, 0.02, "Organic Cotton","Washable, reusable, supports women artisans", "₹250-400"),
    ("pen",         "Recycled Paper Pen",        "Ecoscribe",         90, 0.005,"Recycled",     "Body made from rolled newspaper, refillable", "₹20-50"),
    ("notebook",    "Stone Paper Notebook",      "Karst",             88, 0.08, "Waterproof",   "Made from calcium carbonate, no trees or water used", "₹500-800"),
    ("clothing",    "Organic Cotton T-shirt",    "No Nasties",        85, 0.50, "GOTS,Fair Trade","Fair-trade, GOTS certified organic cotton", "₹800-1500"),
    ("battery",     "Rechargeable Battery Set",  "Panasonic Eneloop", 90, 0.10, "Recyclable",   "1 set replaces 1500 disposable batteries", "₹700-1200"),
];

pub async fn recommend_alternatives(
    State(_state): State<AppState>,
    _auth: AuthUser,
    Json(req): Json<AlternativeRequest>,
) -> AppResult<Json<ApiResponse<Vec<GreenAlternative>>>> {
    let cat = req.category.to_lowercase();
    let alternatives: Vec<GreenAlternative> = GREEN_ALTERNATIVES.iter()
        .filter(|(c, _, _, _, _, _, _, _)| cat.contains(c) || c.contains(&cat.as_str()))
        .map(|(category, name, brand, score, co2, certs, why, price)| {
            GreenAlternative {
                product_name: name.to_string(),
                brand: brand.to_string(),
                category: category.to_string(),
                sustainability_score: *score,
                co2_per_unit_kg: *co2,
                certifications: certs.split(',').map(|s| s.trim().to_string()).collect(),
                why_better: why.to_string(),
                price_range: price.to_string(),
            }
        })
        .collect();

    if alternatives.is_empty() {
        // Return generic top picks
        let top_picks: Vec<GreenAlternative> = GREEN_ALTERNATIVES.iter()
            .filter(|(_, _, _, score, _, _, _, _)| *score >= 90)
            .take(5)
            .map(|(category, name, brand, score, co2, certs, why, price)| {
                GreenAlternative {
                    product_name: name.to_string(), brand: brand.to_string(),
                    category: category.to_string(), sustainability_score: *score,
                    co2_per_unit_kg: *co2,
                    certifications: certs.split(',').map(|s| s.trim().to_string()).collect(),
                    why_better: why.to_string(), price_range: price.to_string(),
                }
            })
            .collect();
        return Ok(Json(ApiResponse::with_message(top_picks,
            "No exact category match. Here are our top-rated sustainable products.")));
    }

    Ok(Json(ApiResponse::ok(alternatives)))
}

// ── T27 — Verified Seller Auditor (Fully Automated) ───────────────────────────

pub async fn verify_seller(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<SellerCertRequest>,
) -> AppResult<Json<ApiResponse<SellerCertResult>>> {
    let seller_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let mut checks_passed = Vec::new();
    let mut checks_failed = Vec::new();

    // Check 1: Certificate type is recognized
    let valid_types = ["ISO_14001", "BIS_ECOMARK", "FSC", "ORGANIC", "FAIR_TRADE", "GOTS", "OEKO_TEX"];
    if valid_types.contains(&req.cert_type.as_str()) {
        checks_passed.push(format!("Certificate type '{}' is recognized", req.cert_type));
    } else {
        checks_failed.push(format!("Certificate type '{}' is not in our recognized registry", req.cert_type));
    }

    // Check 2: Certificate number format validation
    let valid_format = match req.cert_type.as_str() {
        "ISO_14001"  => req.cert_number.len() >= 8 && req.cert_number.chars().any(|c| c.is_ascii_digit()),
        "BIS_ECOMARK"=> req.cert_number.starts_with("IS") || req.cert_number.starts_with("CM"),
        "FSC"        => req.cert_number.starts_with("FSC-") || req.cert_number.starts_with("C"),
        "ORGANIC"    => req.cert_number.len() >= 6,
        "FAIR_TRADE" => req.cert_number.starts_with("FLO") || req.cert_number.len() >= 6,
        _            => req.cert_number.len() >= 5,
    };
    if valid_format {
        checks_passed.push("Certificate number format matches issuer pattern".to_string());
    } else {
        checks_failed.push("Certificate number doesn't match expected format for this issuer".to_string());
    }

    // Check 3: Expiry date validation
    let expiry_valid = chrono::NaiveDate::parse_from_str(&req.expiry_date, "%Y-%m-%d")
        .map(|d| d > chrono::Utc::now().date_naive())
        .unwrap_or(false);
    if expiry_valid {
        checks_passed.push("Certificate has not expired".to_string());
    } else {
        checks_failed.push("Certificate has expired or date format is invalid".to_string());
    }

    // Check 4: Document hash integrity (SHA-256 format)
    let hash_valid = req.document_hash.len() == 64 && req.document_hash.chars().all(|c| c.is_ascii_hexdigit());
    if hash_valid {
        checks_passed.push("Document hash is valid SHA-256".to_string());
    } else {
        checks_failed.push("Document hash is not valid SHA-256 format".to_string());
    }

    // Check 5: Duplicate detection
    let existing: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM seller_certificates WHERE document_hash = $1 AND seller_id != $2"
    ).bind(&req.document_hash).bind(seller_id)
    .fetch_one(&state.db).await?.unwrap_or(0);
    if existing == 0 {
        checks_passed.push("No duplicate certificates detected".to_string());
    } else {
        checks_failed.push("This document hash has been submitted by another seller".to_string());
    }

    // Determine final status
    let status = if checks_failed.is_empty() { "verified" }
                 else if !expiry_valid { "expired" }
                 else { "rejected" };

    let expiry = chrono::NaiveDate::parse_from_str(&req.expiry_date, "%Y-%m-%d")
        .unwrap_or(chrono::Utc::now().date_naive());

    // Store certificate
    let cert_id: Uuid = sqlx::query_scalar(
        "INSERT INTO seller_certificates (seller_id, cert_type, cert_number, issuer, expiry_date, document_hash, status, verified_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, CASE WHEN $7 = 'verified' THEN NOW() ELSE NULL END)
         RETURNING id"
    )
    .bind(seller_id).bind(&req.cert_type).bind(&req.cert_number)
    .bind(&req.issuer).bind(expiry).bind(&req.document_hash).bind(status)
    .fetch_one(&state.db).await?;

    let msg = match status {
        "verified" => format!("✅ Certificate verified automatically. {} checks passed.", checks_passed.len()),
        "expired"  => "Certificate has expired. Please upload a renewed certificate.".to_string(),
        _          => format!("❌ Verification failed. {} checks failed.", checks_failed.len()),
    };

    Ok(Json(ApiResponse::ok(SellerCertResult {
        cert_id: cert_id.to_string(),
        status: status.to_string(),
        checks_passed,
        checks_failed,
        verified_at: if status == "verified" { Some(chrono::Utc::now().to_rfc3339()) } else { None },
        message: msg,
    })))
}

// ── T24 — Carbon Offset Suggester ─────────────────────────────────────────────

pub async fn suggest_offsets(
    State(state): State<AppState>,
    _auth: AuthUser,
    Json(req): Json<OffsetRequest>,
) -> AppResult<Json<ApiResponse<Vec<OffsetProject>>>> {
    let projects = sqlx::query_as::<_, OffsetProject>(
        "SELECT id, name, location, project_type, cost_per_kg, total_capacity_kg, used_capacity_kg, certifier, description
         FROM offset_projects
         WHERE is_verified = TRUE AND (total_capacity_kg - used_capacity_kg) >= $1
         ORDER BY cost_per_kg ASC LIMIT 5"
    )
    .bind(req.target_co2_kg)
    .fetch_all(&state.db).await?;

    Ok(Json(ApiResponse::with_message(projects,
        &format!("Showing verified offset projects for {:.1}kg CO₂.", req.target_co2_kg))))
}

// ── T26 — Marketplace Impact Calculator ───────────────────────────────────────

pub async fn marketplace_impact(
    State(state): State<AppState>,
    _auth: AuthUser,
) -> AppResult<Json<ApiResponse<MarketplaceImpact>>> {
    let total_borrows: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM marketplace_listings WHERE listing_type = 'borrow'"
    ).fetch_one(&state.db).await?.unwrap_or(0);

    let total_trades: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM marketplace_listings WHERE listing_type IN ('trade', 'carbon_credit') AND is_available = FALSE"
    ).fetch_one(&state.db).await?.unwrap_or(0);

    let total_donations: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM marketplace_listings WHERE listing_type = 'donate'"
    ).fetch_one(&state.db).await?.unwrap_or(0);

    let total_items = total_borrows + total_trades + total_donations;
    let avoided_co2 = (total_borrows as f64) * 50.0 + (total_trades as f64) * 25.0 + (total_donations as f64) * 30.0;

    let points_distributed: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COALESCE(SUM(delta), 0) FROM green_points_ledger WHERE reason LIKE '%Circular%' OR reason LIKE '%Carbon credit%'"
    ).fetch_one(&state.db).await?.unwrap_or(0);

    Ok(Json(ApiResponse::ok(MarketplaceImpact {
        total_borrows,
        total_trades,
        total_donations,
        avoided_manufacturing_co2_kg: avoided_co2,
        items_diverted_from_landfill: total_items,
        green_points_distributed: points_distributed,
        equivalent_trees: avoided_co2 / 21.0, // avg tree absorbs 21kg/year
        period: "all_time".to_string(),
    })))
}

// ── T28 — Circular Economy Tracker ────────────────────────────────────────────

pub async fn circular_economy_stats(
    State(state): State<AppState>,
    _auth: AuthUser,
) -> AppResult<Json<ApiResponse<CircularEconomyStats>>> {
    let total: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM marketplace_listings"
    ).fetch_one(&state.db).await?.unwrap_or(0);

    let active: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(*) FROM marketplace_listings WHERE is_available = TRUE"
    ).fetch_one(&state.db).await?.unwrap_or(0);

    let transactions = total - active; // sold/traded/borrowed items

    let unique_users: i64 = sqlx::query_scalar::<_, Option<i64>>(
        "SELECT COUNT(DISTINCT seller_id) FROM marketplace_listings"
    ).fetch_one(&state.db).await?.unwrap_or(0);

    let oldest: Option<chrono::DateTime<chrono::Utc>> = sqlx::query_scalar(
        "SELECT MIN(created_at) FROM marketplace_listings"
    ).fetch_one(&state.db).await?;

    let days_active = oldest
        .map(|o| (chrono::Utc::now() - o).num_days().max(1))
        .unwrap_or(1) as f64;

    let velocity = transactions as f64 / days_active;
    let co2_avoided = transactions as f64 * 35.0; // avg 35kg avoided per transaction
    let water_saved = transactions as f64 * 500.0; // avg 500L water saved

    Ok(Json(ApiResponse::ok(CircularEconomyStats {
        total_listings: total,
        active_listings: active,
        total_transactions: transactions,
        total_co2_avoided_kg: co2_avoided,
        total_water_saved_l: water_saved,
        unique_participants: unique_users,
        top_categories: vec!["Tools".into(), "Books".into(), "Electronics".into(), "Clothing".into()],
        circular_velocity: (velocity * 100.0).round() / 100.0,
    })))
}

// ── T21 — Resource Pool Manager (Borrow/Lend) ────────────────────────────────

#[derive(Deserialize)]
pub struct BorrowRequest {
    pub message: Option<String>,
}

#[derive(Serialize, sqlx::FromRow)]
pub struct BorrowRecord {
    pub id: Uuid,
    pub listing_id: Uuid,
    pub borrower_id: Uuid,
    pub status: String,
    pub message: Option<String>,
    pub co2_avoided_kg: f64,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn request_borrow(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(listing_id): Path<Uuid>,
    Json(req): Json<BorrowRequest>,
) -> AppResult<Json<ApiResponse<BorrowRecord>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    // Each borrow avoids ~50kg CO2 (avg manufactured product baseline)
    let co2_avoided = 50.0_f64;

    let record = sqlx::query_as::<_, BorrowRecord>(
        r#"INSERT INTO borrow_requests (listing_id, borrower_id, message, co2_avoided_kg)
           VALUES ($1, $2, $3, $4)
           RETURNING id, listing_id, borrower_id, status, message, co2_avoided_kg, created_at"#
    )
    .bind(listing_id)
    .bind(user_id)
    .bind(&req.message)
    .bind(co2_avoided)
    .fetch_one(&state.db).await?;

    // Award points for circular economy action
    sqlx::query(
        "INSERT INTO green_points_ledger (user_id, delta, reason, reference_id)
         VALUES ($1, 75, 'Circular Economy — borrow request', $2)"
    )
    .bind(user_id)
    .bind(record.id)
    .execute(&state.db).await?;

    state.brain.log_event("borrow_requested", Some(&auth.0.sub), json!({
        "listing_id": listing_id,
        "co2_avoided_kg": co2_avoided,
    })).await;

    Ok(Json(ApiResponse::with_message(record, "+75 Green Points for choosing circular economy!")))
}

// ── T22 — Green Gig Marketplace ───────────────────────────────────────────────

#[derive(Deserialize)]
pub struct GigRequest {
    pub title: String,
    pub description: String,
    pub gig_type: String,
    pub skills_required: Vec<String>,
    pub reward_points: i32,
    pub city: Option<String>,
}

#[derive(Serialize, sqlx::FromRow)]
pub struct GigListing {
    pub id: Uuid,
    pub poster_id: Uuid,
    pub title: String,
    pub description: String,
    pub gig_type: String,
    pub skills_required: Vec<String>,
    pub reward_points: i32,
    pub city: Option<String>,
    pub status: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn post_gig(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<GigRequest>,
) -> AppResult<Json<ApiResponse<GigListing>>> {
    let user_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    let gig = sqlx::query_as::<_, GigListing>(
        r#"INSERT INTO gig_listings (poster_id, title, description, gig_type, skills_required, reward_points, city)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id, poster_id, title, description, gig_type, skills_required, reward_points, city, status, created_at"#
    )
    .bind(user_id)
    .bind(&req.title)
    .bind(&req.description)
    .bind(&req.gig_type)
    .bind(&req.skills_required)
    .bind(req.reward_points)
    .bind(&req.city)
    .fetch_one(&state.db).await?;

    Ok(Json(ApiResponse::ok(gig)))
}

pub async fn get_gigs(
    State(state): State<AppState>,
    _auth: AuthUser,
    Query(p): Query<Pagination>,
) -> AppResult<Json<ApiResponse<Vec<GigListing>>>> {
    let offset = ((p.page - 1) * p.limit) as i64;
    let gigs = sqlx::query_as::<_, GigListing>(
        "SELECT id, poster_id, title, description, gig_type, skills_required, reward_points, city, status, created_at
         FROM gig_listings WHERE status = 'open' ORDER BY created_at DESC LIMIT $1 OFFSET $2"
    )
    .bind(p.limit as i64)
    .bind(offset)
    .fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(gigs)))
}

// ── T23 — Carpool Matcher ─────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CarpoolListingRequest {
    pub origin: String,
    pub destination: String,
    pub departure_at: chrono::DateTime<chrono::Utc>,
    pub seats_available: i32,
    pub price_points: Option<i32>,
}

#[derive(Serialize, sqlx::FromRow)]
pub struct CarpoolMatch {
    pub id: Uuid,
    pub driver_id: Uuid,
    pub origin: String,
    pub destination: String,
    pub departure_at: chrono::DateTime<chrono::Utc>,
    pub seats_available: i32,
    pub price_points: i32,
    pub co2_saved_per_rider: f64,
    pub status: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn post_carpool(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CarpoolListingRequest>,
) -> AppResult<Json<ApiResponse<CarpoolMatch>>> {
    let driver_id = Uuid::parse_str(&auth.0.sub)
        .map_err(|_| AppError::Auth("Invalid user ID".into()))?;

    // Assume 20km avg trip — riders save car baseline minus shared fraction
    let co2_per_rider = 0.192 * 20.0 * 0.6;

    let listing = sqlx::query_as::<_, CarpoolMatch>(
        r#"INSERT INTO carpool_listings (driver_id, origin, destination, departure_at, seats_available, price_points, co2_saved_per_rider)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id, driver_id, origin, destination, departure_at, seats_available, price_points, co2_saved_per_rider, status, created_at"#
    )
    .bind(driver_id)
    .bind(&req.origin)
    .bind(&req.destination)
    .bind(req.departure_at)
    .bind(req.seats_available)
    .bind(req.price_points.unwrap_or(0))
    .bind(co2_per_rider)
    .fetch_one(&state.db).await?;

    Ok(Json(ApiResponse::ok(listing)))
}

pub async fn get_carpools(
    State(state): State<AppState>,
    _auth: AuthUser,
    Query(p): Query<Pagination>,
) -> AppResult<Json<ApiResponse<Vec<CarpoolMatch>>>> {
    let offset = ((p.page - 1) * p.limit) as i64;
    let listings = sqlx::query_as::<_, CarpoolMatch>(
        r#"SELECT id, driver_id, origin, destination, departure_at, seats_available,
                  price_points, co2_saved_per_rider, status, created_at
           FROM carpool_listings WHERE status = 'open' AND departure_at > NOW()
           ORDER BY departure_at ASC LIMIT $1 OFFSET $2"#
    )
    .bind(p.limit as i64)
    .bind(offset)
    .fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(listings)))
}
