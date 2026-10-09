//! Conservative OSM corridor inference: conflicting or sparse evidence stays unknown.
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    models::ApiResponse,
    AppState,
};
use axum::{extract::State, Json};
use serde::Deserialize;
use serde_json::{json, Value};
#[derive(Clone, Deserialize)]
pub struct Point {
    pub latitude: f64,
    pub longitude: f64,
    pub accuracy: f64,
}
#[derive(Deserialize)]
pub struct Trace {
    pub points: Vec<Point>,
    pub peak_speed_kmh: f64,
}
pub fn segment_distance(point: &Point, a: (f64, f64), b: (f64, f64)) -> f64 {
    let scale = 111320.;
    let x = (a.1 - point.longitude) * point.latitude.to_radians().cos() * scale;
    let y = (a.0 - point.latitude) * scale;
    let dx = (b.1 - a.1) * point.latitude.to_radians().cos() * scale;
    let dy = (b.0 - a.0) * scale;
    let denom = dx * dx + dy * dy;
    let t = if denom > 0. {
        (-(x * dx + y * dy) / denom).clamp(0., 1.)
    } else {
        0.
    };
    ((x + t * dx).powi(2) + (y + t * dy).powi(2)).sqrt()
}
pub fn classify(points: &[Point], ways: &Value) -> Value {
    if points.len() < 3 {
        return json!({"mode":"unknown_transit","confidence":0.0,"reason":"Insufficient trajectory evidence"});
    }
    let mut rail = 0;
    let mut road = 0;
    let mut metro = 0;
    for point in points {
        let mut near_rail = false;
        let mut near_road = false;
        let mut near_metro = false;
        for way in ways["elements"].as_array().unwrap_or(&vec![]) {
            let Some(geometry) = way["geometry"].as_array() else {
                continue;
            };
            let close = geometry.windows(2).any(|segment| {
                let a = (
                    segment[0]["lat"].as_f64().unwrap_or(999.),
                    segment[0]["lon"].as_f64().unwrap_or(999.),
                );
                let b = (
                    segment[1]["lat"].as_f64().unwrap_or(999.),
                    segment[1]["lon"].as_f64().unwrap_or(999.),
                );
                segment_distance(point, a, b) <= point.accuracy.clamp(10., 35.)
            });
            if !close {
                continue;
            }
            match way["tags"]["railway"].as_str() {
                Some("rail") => near_rail = true,
                Some("subway") | Some("light_rail") => {
                    near_rail = true;
                    near_metro = true;
                }
                _ => {}
            }
            if ["motorway", "trunk", "primary", "secondary"]
                .contains(&way["tags"]["highway"].as_str().unwrap_or(""))
            {
                near_road = true;
            }
        }
        if near_rail {
            rail += 1;
        }
        if near_road {
            road += 1;
        }
        if near_metro {
            metro += 1;
        }
    }
    let n = points.len() as f64;
    let r = rail as f64 / n;
    let d = road as f64 / n;
    let (mode, confidence) = if r >= 0.85 && d <= 0.15 {
        (
            if metro as f64 / n >= 0.85 {
                "metro"
            } else {
                "train"
            },
            0.9,
        )
    } else if d >= 0.85 && r <= 0.15 {
        ("car", 0.85)
    } else {
        ("unknown_transit", 0.0)
    };
    json!({"mode":mode,"confidence":confidence,"rail_coverage":r,"road_coverage":d,"source":"OpenStreetMap corridor proximity inference","reason":if mode=="unknown_transit" {"Sparse/conflicting corridor evidence; confirmation required"}else if mode=="car" {"Road vehicle inferred; bus versus private car still requires confirmation"}else{"Trajectory aligns with rail corridor; estimate can be corrected"}})
}
pub async fn infer(
    State(state): State<AppState>,
    _auth: AuthUser,
    Json(r): Json<Trace>,
) -> AppResult<Json<ApiResponse<Value>>> {
    if !r.peak_speed_kmh.is_finite()
        || !(0.0..=180.).contains(&r.peak_speed_kmh)
        || r.points.len() > 256
    {
        return Err(AppError::BadRequest(
            "Invalid velocity or too many trace points".into(),
        ));
    }
    for p in &r.points {
        super::live::validate_coordinates(p.latitude, p.longitude)?;
        if !p.accuracy.is_finite() || !(0.0..=50.).contains(&p.accuracy) {
            return Err(AppError::BadRequest("Trace accuracy must be 0–50 m".into()));
        }
    }
    if r.peak_speed_kmh <= 25. {
        return Ok(Json(ApiResponse::ok(
            json!({"mode":if r.peak_speed_kmh<7. {"walk"}else{"bicycle"},"confidence":1.0,"source":"Velocity threshold estimate"}),
        )));
    }
    let samples: Vec<Point> = if r.points.len() <= 7 {
        r.points.clone()
    } else {
        (0..7)
            .map(|i| r.points[i * (r.points.len() - 1) / 6].clone())
            .collect()
    };
    if samples.len() < 3 {
        return Ok(Json(ApiResponse::ok(classify(&samples, &json!({})))));
    }
    let clauses=samples.iter().map(|p|format!("way(around:50,{},{})[railway~\"^(rail|subway|light_rail)$\"];way(around:50,{},{})[highway~\"^(motorway|trunk|primary|secondary)$\"];",p.latitude,p.longitude,p.latitude,p.longitude)).collect::<String>();
    let query = format!("[out:json][timeout:12];({clauses});out tags geom;");
    let url = std::env::var("OVERPASS_URL")
        .unwrap_or_else(|_| "https://overpass-api.de/api/interpreter".into());
    let data: Value = state
        .brain
        .http
        .post(url)
        .form(&[("data", query)])
        .header("User-Agent", "Grevidea/1.0")
        .timeout(std::time::Duration::from_secs(15))
        .send()
        .await
        .map_err(|_| AppError::BrainUnavailable("Transport map provider unavailable".into()))?
        .error_for_status()
        .map_err(|_| AppError::BrainUnavailable("Transport map provider rejected request".into()))?
        .json()
        .await
        .map_err(|_| AppError::BrainUnavailable("Invalid transport map data".into()))?;
    Ok(Json(ApiResponse::ok(classify(&samples, &data))))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ambiguous_parallel_road_and_rail_never_auto_classifies() {
        let points = vec![
            Point {
                latitude: 19.2,
                longitude: 72.9,
                accuracy: 10.,
            },
            Point {
                latitude: 19.21,
                longitude: 72.9,
                accuracy: 10.,
            },
            Point {
                latitude: 19.22,
                longitude: 72.9,
                accuracy: 10.,
            },
        ];
        let geometry = json!([{"lat":19.19,"lon":72.9},{"lat":19.23,"lon":72.9}]);
        let rail = json!({"elements":[{"tags":{"railway":"subway"},"geometry":geometry}]});
        assert_eq!(classify(&points, &rail)["mode"], "metro");
        let ambiguous = json!({"elements":[{"tags":{"railway":"rail"},"geometry":geometry},{"tags":{"highway":"primary"},"geometry":geometry}]});
        assert_eq!(classify(&points, &ambiguous)["mode"], "unknown_transit");
    }
    #[test]
    fn projection_measures_segment_not_only_vertices() {
        let point = Point {
            latitude: 19.2,
            longitude: 72.9,
            accuracy: 10.,
        };
        assert!(segment_distance(&point, (19.1, 72.9), (19.3, 72.9)) < 0.001);
    }
}
