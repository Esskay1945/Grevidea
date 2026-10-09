//! Fresh station observations, distance-weighted along route segments.
use super::live::validate_coordinates;
use crate::{
    error::{AppError, AppResult},
    AppState,
};
use chrono::{DateTime, Utc};
use serde_json::{json, Value};
fn distance(a: (f64, f64), b: (f64, f64)) -> f64 {
    let lat = ((a.1 + b.1) / 2.).to_radians();
    (((a.0 - b.0) * lat.cos()).powi(2) + (a.1 - b.1).powi(2)).sqrt() * 111.195
}
pub fn score_routes(routes: &Value, stations: &Value, now: DateTime<Utc>) -> Vec<Value> {
    let valid: Vec<(f64, f64, f64)> = stations
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|s| {
            let lat = s["latitude"].as_f64()?;
            let lon = s["longitude"].as_f64()?;
            let pm = s["pm2_5_ug_m3"].as_f64()?;
            let measured = DateTime::parse_from_rfc3339(s["measured_at"].as_str()?).ok()?;
            if validate_coordinates(lat, lon).is_err()
                || !(0.0..=2000.0).contains(&pm)
                || measured > now
                || now.signed_duration_since(measured).num_minutes() > 60
            {
                return None;
            }
            Some((lon, lat, pm))
        })
        .take(2000)
        .collect();
    routes.as_array().into_iter().flatten().take(3).enumerate().map(|(index,route)|{
  let points:Vec<(f64,f64)>=route["geometry"]["coordinates"].as_array().into_iter().flatten().filter_map(|p|Some((p[0].as_f64()?,p[1].as_f64()?))).collect();
  let mut total=0.;let mut covered=0.;let mut exposure=0.;
  for pair in points.windows(2){let length=distance(pair[0],pair[1]);total+=length;
   let midpoint=((pair[0].0+pair[1].0)/2.,(pair[0].1+pair[1].1)/2.);
   let nearest=valid.iter().map(|s|(distance(midpoint,(s.0,s.1)),s.2)).min_by(|a,b|a.0.total_cmp(&b.0));
   if let Some((km,pm))=nearest.filter(|x|x.0<=2.) {let _=km;covered+=length;exposure+=length*pm;}
  }
  let coverage=if total>0. {covered/total}else{0.};
  json!({"route_index":index,"station_coverage_fraction":coverage,"mean_station_pm2_5_ug_m3":if coverage>=0.8 && covered>0. {Some(exposure/covered)}else{None},"pm2_5_distance_integral":if coverage>=0.8 {Some(exposure)}else{None},"observation_max_age_minutes":60})
 }).collect()
}
pub async fn fetch_scores(
    state: &AppState,
    routes: &Value,
    lat: f64,
    lon: f64,
) -> AppResult<Vec<Value>> {
    let url = std::env::var("AQI_STATION_FEED_URL")
        .map_err(|_| AppError::BrainUnavailable("Station feed not configured".into()))?;
    if !url.starts_with("https://")
        && !(std::env::var("ALLOW_LOCAL_TEST_PROVIDERS").as_deref() == Ok("true")
            && url.starts_with("http://127.0.0.1:"))
    {
        return Err(AppError::BrainUnavailable(
            "Station feed must use HTTPS".into(),
        ));
    }
    let mut request = state
        .brain
        .http
        .get(url)
        .query(&[("lat", lat), ("lon", lon)])
        .timeout(std::time::Duration::from_secs(10));
    if let Ok(token) = std::env::var("AQI_STATION_FEED_TOKEN") {
        request = request.bearer_auth(token);
    }
    let stations: Value = request
        .send()
        .await
        .map_err(|_| AppError::BrainUnavailable("Station feed unavailable".into()))?
        .error_for_status()
        .map_err(|_| AppError::BrainUnavailable("Station feed unavailable".into()))?
        .json()
        .await
        .map_err(|_| AppError::BrainUnavailable("Invalid station feed".into()))?;
    if !stations.is_array() || stations.as_array().is_some_and(|a| a.len() > 2000) {
        return Err(AppError::BrainUnavailable(
            "Invalid station feed size".into(),
        ));
    }
    Ok(score_routes(routes, &stations, Utc::now()))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn station_score_requires_fresh_spatial_coverage() {
        let now = Utc::now();
        let routes = json!([{"geometry":{"coordinates":[[72.9,19.2],[72.901,19.201]]}}]);
        let feed = json!([{"latitude":19.2,"longitude":72.9,"pm2_5_ug_m3":12.,"measured_at":now.to_rfc3339()}]);
        assert_eq!(
            score_routes(&routes, &feed, now)[0]["mean_station_pm2_5_ug_m3"],
            12.
        );
        assert!(
            score_routes(&routes, &feed, now + chrono::Duration::hours(2))[0]
                ["mean_station_pm2_5_ug_m3"]
                .is_null()
        );
    }
}
