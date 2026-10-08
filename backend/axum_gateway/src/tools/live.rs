//! Live location APIs. No fabricated routes, alerts or emergency delivery claims.
use crate::{auth::AuthUser, error::{AppError, AppResult}, models::ApiResponse, AppState};
use axum::{extract::{State, Query, Path}, Json};
use serde::Deserialize;
use serde_json::{json, Value};
use uuid::Uuid;

pub fn validate_coordinates(lat: f64, lon: f64) -> AppResult<()> {
    if !lat.is_finite() || !lon.is_finite() || !(-90.0..=90.0).contains(&lat) || !(-180.0..=180.0).contains(&lon) { return Err(AppError::BadRequest("Invalid GPS coordinates".into())); }
    Ok(())
}
fn uid(auth: &AuthUser) -> AppResult<Uuid> { Uuid::parse_str(&auth.0.sub).map_err(|_| AppError::Auth("Invalid user".into())) }
pub(super) async fn fetch(state: &AppState, url: &str, params: &[(&str, String)]) -> AppResult<Value> {
    state.brain.http.get(url).query(params).header("User-Agent", "Grevidea/1.0 (environmental travel planner)").timeout(std::time::Duration::from_secs(15)).send().await.map_err(|_| AppError::BrainUnavailable("Environmental data service unavailable".into()))?.error_for_status().map_err(|_| AppError::BrainUnavailable("Environmental data provider rejected request".into()))?.json().await.map_err(|_| AppError::BrainUnavailable("Invalid external data".into()))
}
fn nominatim_gate() -> &'static tokio::sync::Mutex<Option<std::time::Instant>> {
    static GATE:std::sync::OnceLock<tokio::sync::Mutex<Option<std::time::Instant>>>=std::sync::OnceLock::new();
    GATE.get_or_init(||tokio::sync::Mutex::new(None))
}
pub async fn reverse_geocode(State(state):State<AppState>, _auth:AuthUser, Query(q):Query<Nearby>) -> AppResult<Json<ApiResponse<Value>>> {
    validate_coordinates(q.lat,q.lon)?;
    let mut last=nominatim_gate().lock().await;
    if let Some(instant)=*last {tokio::time::sleep(std::time::Duration::from_secs(1).saturating_sub(instant.elapsed())).await;}
    let data=fetch(&state,"https://nominatim.openstreetmap.org/reverse",&[("lat",q.lat.to_string()),("lon",q.lon.to_string()),("format","jsonv2".into())]).await;
    *last=Some(std::time::Instant::now());
    Ok(Json(ApiResponse::ok(data?)))
}
#[derive(Deserialize)]
pub struct Search { pub q: String }
pub async fn geocode(State(state): State<AppState>, _auth: AuthUser, Query(q): Query<Search>) -> AppResult<Json<ApiResponse<Value>>> {
    if q.q.trim().is_empty() || q.q.len() > 200 { return Err(AppError::BadRequest("Enter a destination".into())); }
    let mut last = nominatim_gate().lock().await;
    if let Some(instant) = *last { tokio::time::sleep(std::time::Duration::from_secs(1).saturating_sub(instant.elapsed())).await; }
    let result = fetch(&state, "https://nominatim.openstreetmap.org/search", &[("q", q.q), ("format", "jsonv2".into()), ("limit", "5".into())]).await;
    *last = Some(std::time::Instant::now());
    Ok(Json(ApiResponse::ok(result?)))
}
#[derive(Deserialize)]
pub struct Route { pub origin_lat: f64, pub origin_lon: f64, pub destination_lat: f64, pub destination_lon: f64 }
pub async fn route(State(state): State<AppState>, _auth: AuthUser, Json(r): Json<Route>) -> AppResult<Json<ApiResponse<Value>>> {
    validate_coordinates(r.origin_lat,r.origin_lon)?; validate_coordinates(r.destination_lat,r.destination_lon)?;
    let url = format!("https://router.project-osrm.org/route/v1/driving/{},{};{},{}",r.origin_lon,r.origin_lat,r.destination_lon,r.destination_lat);
    let mut data = fetch(&state,&url,&[("overview","full".into()),("geometries","geojson".into()),("alternatives","true".into())]).await?;
    if data["code"] != "Ok" { return Err(AppError::NotFound("No road route found".into())); }
    data["attribution"] = json!("© OpenStreetMap contributors; OSRM road routing. Transit comparisons are estimates, not railway routes.");
    let scoring = async {
    let mut scored = Vec::new();
    for (index, r) in data["routes"].as_array().unwrap_or(&vec![]).iter().take(3).enumerate() {
        let points = r["geometry"]["coordinates"].as_array();
        let mut samples = Vec::new();
        if let Some(points) = points { if !points.is_empty() {
            for i in [0,points.len()/2,points.len()-1] {
                if let (Some(lon),Some(lat))=(points[i][0].as_f64(),points[i][1].as_f64()) {
                    if let Ok(air)=fetch(&state,"https://air-quality-api.open-meteo.com/v1/air-quality", &[("latitude",lat.to_string()),("longitude",lon.to_string()),("current","us_aqi".into())]).await {
                        if let Some(value)=air["current"]["us_aqi"].as_f64() { samples.push(value); }
                    }
                }
            }
        }}
        let mean=if samples.len()==3 {Some(samples.iter().sum::<f64>()/3.0)} else {None};
        scored.push(json!({"route_index":index,"mean_model_us_aqi":mean,"samples":samples.len()}));
    }
    scored
    };
    let scored:Vec<Value>=tokio::time::timeout(std::time::Duration::from_secs(18),scoring).await.unwrap_or_default();
    let cleanest=scored.iter().filter_map(|s|Some((s["route_index"].as_u64()?,s["mean_model_us_aqi"].as_f64()?))).min_by(|a,b|a.1.total_cmp(&b.1)).map(|s|s.0);
    data["air_quality_scores"]=json!(scored);
    data["cleanest_route_index"]=json!(cleanest);
    data["air_quality_status"]=json!("Three-point CAMS model estimate; not station measurements or a verified safest route");
    Ok(Json(ApiResponse::ok(data)))
}
#[derive(Deserialize)]
pub struct Nearby { pub lat: f64, pub lon: f64, pub radius_km: Option<f64> }
fn radius(q: &Nearby) -> AppResult<f64> { validate_coordinates(q.lat,q.lon)?; let r=q.radius_km.unwrap_or(5.0); if !r.is_finite() || !(0.1..=5.0).contains(&r) { return Err(AppError::BadRequest("Radius must be 0.1–5 km".into())); } Ok(r) }
pub async fn weather(State(state): State<AppState>, _auth: AuthUser, Query(q): Query<Nearby>) -> AppResult<Json<ApiResponse<Value>>> {
    validate_coordinates(q.lat,q.lon)?;
    let data = fetch(&state,"https://api.open-meteo.com/v1/forecast", &[("latitude",q.lat.to_string()),("longitude",q.lon.to_string()),("current","temperature_2m,precipitation,weather_code".into()),("hourly","temperature_2m,precipitation".into()),("forecast_days","3".into()),("timezone","auto".into())]).await?;
    let air = fetch(&state,"https://air-quality-api.open-meteo.com/v1/air-quality", &[("latitude",q.lat.to_string()),("longitude",q.lon.to_string()),("current","us_aqi,pm2_5,pm10,ozone".into())]).await.ok();
    Ok(Json(ApiResponse::ok(json!({"weather":data,"air_quality":air,"source":"Open-Meteo / CAMS model forecast; not station telemetry", "flood_status":"Not an official flood warning"}))))
}
#[derive(Deserialize)]
pub struct Aid { pub category:String, pub description:String, pub latitude:f64, pub longitude:f64 }
pub async fn create_aid(State(state):State<AppState>, auth:AuthUser, Json(r):Json<Aid>) -> AppResult<Json<ApiResponse<Value>>> {
    validate_coordinates(r.latitude,r.longitude)?;
    if !["water","power","shelter","medical","food"].contains(&r.category.as_str()) || r.description.trim().is_empty() || r.description.len()>2000 { return Err(AppError::BadRequest("Choose a resource and enter a description".into())); }
    let id:Uuid=sqlx::query_scalar("INSERT INTO mutual_aid(user_id,category,description,latitude,longitude) VALUES($1,$2,$3,$4,$5) RETURNING id").bind(uid(&auth)?).bind(r.category).bind(r.description).bind(r.latitude).bind(r.longitude).fetch_one(&state.db).await?;
    Ok(Json(ApiResponse::ok(json!({"id":id,"status":"open"}))))
}
pub async fn nearby_aid(State(state):State<AppState>, _auth:AuthUser, Query(q):Query<Nearby>) -> AppResult<Json<ApiResponse<Value>>> {
    let r=radius(&q)?;
    let rows:Vec<Value>=sqlx::query_scalar("SELECT to_jsonb(m) FROM mutual_aid m WHERE ST_DWithin(ST_SetSRID(ST_MakePoint(longitude,latitude),4326)::geography,ST_SetSRID(ST_MakePoint($1,$2),4326)::geography,$3) ORDER BY created_at DESC LIMIT 100").bind(q.lon).bind(q.lat).bind(r*1000.0).fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(json!(rows))))
}
pub async fn coordinate_aid(State(state):State<AppState>, auth:AuthUser, Path(id):Path<Uuid>) -> AppResult<Json<ApiResponse<Value>>> {
    let updated=sqlx::query("UPDATE mutual_aid SET status='coordinated',coordinated_by=$1 WHERE id=$2 AND status='open' AND user_id<>$1").bind(uid(&auth)?).bind(id).execute(&state.db).await?.rows_affected();
    if updated!=1 { return Err(AppError::BadRequest("Request already coordinated, missing, or belongs to you".into())); }
    Ok(Json(ApiResponse::ok(json!({"id":id,"status":"coordinated"}))))
}
pub async fn nearby_carpools(State(state):State<AppState>, _auth:AuthUser, Query(q):Query<Nearby>) -> AppResult<Json<ApiResponse<Value>>> {
    let r=radius(&q)?;
    let rows:Vec<Value>=sqlx::query_scalar("SELECT to_jsonb(c) FROM carpool_listings c WHERE status='open' AND seats_available>0 AND departure_at>NOW() AND pickup_lat IS NOT NULL AND ST_DWithin(ST_SetSRID(ST_MakePoint(pickup_lon,pickup_lat),4326)::geography,ST_SetSRID(ST_MakePoint($1,$2),4326)::geography,$3) ORDER BY departure_at LIMIT 100").bind(q.lon).bind(q.lat).bind(r*1000.0).fetch_all(&state.db).await?;
    Ok(Json(ApiResponse::ok(json!(rows))))
}
pub async fn book_carpool(State(state):State<AppState>, auth:AuthUser, Path(id):Path<Uuid>) -> AppResult<Json<ApiResponse<Value>>> {
    let user=uid(&auth)?;
    let mut tx=state.db.begin().await?;
    let row:Option<(i32,Uuid)>=sqlx::query_as("SELECT seats_available,driver_id FROM carpool_listings WHERE id=$1 AND status='open' AND departure_at>NOW() FOR UPDATE").bind(id).fetch_optional(&mut *tx).await?;
    let (seats,driver)=row.ok_or_else(|| AppError::NotFound("Ride is unavailable".into()))?;
    if seats<1 || driver==user { return Err(AppError::BadRequest("No seats available or cannot book your own ride".into())); }
    let inserted=sqlx::query("INSERT INTO carpool_bookings(listing_id,passenger_id) VALUES($1,$2) ON CONFLICT DO NOTHING").bind(id).bind(user).execute(&mut *tx).await?.rows_affected();
    if inserted!=1 { return Err(AppError::BadRequest("Already booked this ride".into())); }
    sqlx::query("UPDATE carpool_listings SET seats_available=seats_available-1 WHERE id=$1").bind(id).execute(&mut *tx).await?;
    tx.commit().await?;
    Ok(Json(ApiResponse::ok(json!({"id":id,"seats_available":seats-1,"booked":true}))))
}
#[cfg(test)]
mod tests {
 use super::*;
 #[test] fn coordinates_reject_invalid_numbers() { assert!(validate_coordinates(f64::NAN,0.).is_err()); assert!(validate_coordinates(91.,0.).is_err()); assert!(validate_coordinates(19.2,72.9).is_ok()); }
 #[test] fn radius_is_bounded() { assert!(radius(&Nearby{lat:0.,lon:0.,radius_km:Some(-1.)}).is_err()); }
}

pub async fn shelters(State(state):State<AppState>, _auth:AuthUser, Query(q):Query<Nearby>) -> AppResult<Json<ApiResponse<Value>>> {
    let r=radius(&q)?;
    let url=std::env::var("MUNICIPAL_SHELTER_FEED_URL").map_err(|_|AppError::BrainUnavailable("No verified municipal shelter feed configured".into()))?;
    let data=fetch(&state,&url,&[]).await?;
    let shelters:Vec<Value>=data.as_array().ok_or_else(||AppError::BrainUnavailable("Invalid shelter registry".into()))?.iter().filter_map(|s|{
        let lat=s["lat"].as_f64()?;let lon=s["lng"].as_f64()?;
        if validate_coordinates(lat,lon).is_err() || s["isOpen"]!=true {return None;}
        let a=((lat-q.lat).to_radians()/2.).sin().powi(2)+q.lat.to_radians().cos()*lat.to_radians().cos()*((lon-q.lon).to_radians()/2.).sin().powi(2);
        let km=6371.*2.*a.sqrt().asin();
        if km>r{return None;}
        let mut shelter=s.clone();shelter["distance"]=json!(format!("{:.2} km",km));Some(shelter)
    }).collect();
    Ok(Json(ApiResponse::ok(json!(shelters))))
}

#[derive(Deserialize)]
pub struct HabitClaim { pub habit_id:String, pub day:Option<chrono::NaiveDate> }
pub async fn claim_habit(State(state):State<AppState>, auth:AuthUser, Json(req):Json<HabitClaim>) -> AppResult<Json<ApiResponse<Value>>> {
    let points=match req.habit_id.as_str(){"bus_commute"=>60,"green_plate"=>50,"solar_shift"=>45,"zero_plastic"=>40,"cycle_walk"=>75,"civic_report"=>80,"natural_light"=>35,"waste_segregation"=>40,_=>return Err(AppError::BadRequest("Unknown habit".into()))};
    let today=(chrono::Utc::now()+chrono::Duration::hours(5)+chrono::Duration::minutes(30)).date_naive();
    let day=req.day.unwrap_or(today);
    if day>today || day<today-chrono::Duration::days(7) {return Err(AppError::BadRequest("Habit claim date must be within the last seven days".into()));}
    let user=uid(&auth)?;let mut tx=state.db.begin().await?;
    // Serialize claims for one account, including the daily cap.
    sqlx::query("SELECT id FROM users WHERE id=$1 FOR UPDATE").bind(user).fetch_one(&mut *tx).await?;
    let exists:bool=sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM habit_claims WHERE user_id=$1 AND day=$2 AND habit_id=$3)").bind(user).bind(day).bind(&req.habit_id).fetch_one(&mut *tx).await?;
    if exists {return Ok(Json(ApiResponse::ok(json!({"claimed":true,"points_earned":0}))));}
    let count:i64=sqlx::query_scalar("SELECT COUNT(*) FROM habit_claims WHERE user_id=$1 AND day=$2").bind(user).bind(day).fetch_one(&mut *tx).await?;
    if count>=3{return Err(AppError::BadRequest("Today's three habits already claimed".into()));}
    sqlx::query("INSERT INTO habit_claims(user_id,day,habit_id) VALUES($1,$2,$3)").bind(user).bind(day).bind(&req.habit_id).execute(&mut *tx).await?;
    sqlx::query("INSERT INTO green_points_ledger(user_id,delta,reason) VALUES($1,$2,$3)").bind(user).bind(points).bind(format!("Daily habit: {}",req.habit_id)).execute(&mut *tx).await?;
    tx.commit().await?;
    Ok(Json(ApiResponse::ok(json!({"claimed":true,"points_earned":points}))))
}
#[derive(Deserialize)]
pub struct Redemption { pub reward_id:String }
pub async fn redeem_reward(State(state):State<AppState>, auth:AuthUser, Json(req):Json<Redemption>) -> AppResult<Json<ApiResponse<Value>>> {
    let cost=match req.reward_id.as_str(){"plant_tree"=>100,"eco_merchandise"=>400,"donate_ngo"=>250,_=>return Err(AppError::BadRequest("Unknown reward".into()))};
    let user=uid(&auth)?;let mut tx=state.db.begin().await?;
    sqlx::query("SELECT id FROM users WHERE id=$1 FOR UPDATE").bind(user).fetch_one(&mut *tx).await?;
    let balance:i64=sqlx::query_scalar("SELECT COALESCE(SUM(delta),0)::bigint FROM green_points_ledger WHERE user_id=$1").bind(user).fetch_one(&mut *tx).await?;
    if balance<i64::from(cost){return Err(AppError::BadRequest("Not enough Green Points".into()));}
    let id:Uuid=sqlx::query_scalar("INSERT INTO reward_redemptions(user_id,reward_id,cost) VALUES($1,$2,$3) RETURNING id").bind(user).bind(req.reward_id).bind(cost).fetch_one(&mut *tx).await?;
    sqlx::query("INSERT INTO green_points_ledger(user_id,delta,reason,reference_id) VALUES($1,$2,'Reward redemption',$3)").bind(user).bind(-cost).bind(id).execute(&mut *tx).await?;
    tx.commit().await?;
    Ok(Json(ApiResponse::ok(json!({"id":id,"balance":balance-i64::from(cost),"status":"pending_fulfillment"}))))
}
