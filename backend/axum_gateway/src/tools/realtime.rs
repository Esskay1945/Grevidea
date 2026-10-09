//! Postgres LISTEN/NOTIFY fanout keeps independent gateway replicas consistent.
use super::live::Nearby;
use crate::{
    auth::{AuthUser, Claims},
    error::{AppError, AppResult},
    AppState,
};
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    http::HeaderMap,
    response::Response,
};
use serde::Deserialize;
use serde_json::json;
pub async fn listen_changes(state: AppState) {
    loop {
        let result = async {
            let mut listener = sqlx::postgres::PgListener::connect_with(&state.db).await?;
            listener.listen("grevidea_live").await?;
            loop {
                listener.recv().await?;
                let _ = state.live_changes.send(());
            }
            #[allow(unreachable_code)]
            Ok::<(), sqlx::Error>(())
        }
        .await;
        if result.is_err() {
            tracing::warn!("Live database listener reconnecting");
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
        }
    }
}
pub async fn connect(
    State(state): State<AppState>,
    headers: HeaderMap,
    upgrade: WebSocketUpgrade,
) -> AppResult<Response> {
    let token = headers
        .get("authorization")
        .and_then(|h| h.to_str().ok())
        .and_then(|h| h.strip_prefix("Bearer "))
        .or_else(|| {
            headers
                .get("sec-websocket-protocol")
                .and_then(|h| h.to_str().ok())
                .and_then(|h| {
                    h.split(',')
                        .find_map(|v| v.trim().strip_prefix("grevidea.jwt."))
                })
        })
        .ok_or_else(|| AppError::Auth("WebSocket authentication required".into()))?;
    let claims = Claims::verify(token, &state.config.jwt_secret)?;
    Ok(upgrade
        .protocols(["grevidea"])
        .on_upgrade(move |socket| session(socket, state, claims)))
}
#[derive(Deserialize)]
struct Watch {
    lat: f64,
    lon: f64,
    radius_km: Option<f64>,
}
async fn snapshot(
    socket: &mut WebSocket,
    state: &AppState,
    auth: &AuthUser,
    watch: &Watch,
) -> Result<(), ()> {
    let aid = super::live::nearby_aid(
        State(state.clone()),
        auth.clone(),
        axum::extract::Query(Nearby {
            lat: watch.lat,
            lon: watch.lon,
            radius_km: watch.radius_km,
        }),
    )
    .await
    .map_err(|_| ())?;
    let rides = super::live::nearby_carpools(
        State(state.clone()),
        auth.clone(),
        axum::extract::Query(Nearby {
            lat: watch.lat,
            lon: watch.lon,
            radius_km: watch.radius_km,
        }),
    )
    .await
    .map_err(|_| ())?;
    socket
        .send(Message::Text(
            json!({"type":"snapshot","mutual_aid":aid.0.data,"carpools":rides.0.data}).to_string(),
        ))
        .await
        .map_err(|_| ())
}
async fn session(mut socket: WebSocket, state: AppState, claims: Claims) {
    let auth = AuthUser(claims.clone());
    let mut receiver = state.live_changes.subscribe();
    let message = tokio::time::timeout(std::time::Duration::from_secs(10), socket.recv()).await;
    let Ok(Some(Ok(Message::Text(text)))) = message else {
        return;
    };
    let Ok(mut watch) = serde_json::from_str::<Watch>(&text) else {
        return;
    };
    if snapshot(&mut socket, &state, &auth, &watch).await.is_err() {
        return;
    }
    let mut keepalive = tokio::time::interval(std::time::Duration::from_secs(25));
    loop {
        tokio::select! {
         _=keepalive.tick()=>{if chrono::Utc::now().timestamp()>=claims.exp || socket.send(Message::Ping(vec![])).await.is_err(){break;}}
         notification=receiver.recv()=>{if notification.is_err() && matches!(notification,Err(tokio::sync::broadcast::error::RecvError::Closed)){break;}if snapshot(&mut socket,&state,&auth,&watch).await.is_err(){break;}}
         message=socket.recv()=>{match message {
          Some(Ok(Message::Text(text)))=>{if text.len()>1000{break;}let Ok(next)=serde_json::from_str::<Watch>(&text)else{break;};watch=next;if snapshot(&mut socket,&state,&auth,&watch).await.is_err(){break;}},
          Some(Ok(Message::Close(_)))|None|Some(Err(_))=>break,
          _=>{}
         }}
        }
    }
    let _ = socket.close().await;
}
