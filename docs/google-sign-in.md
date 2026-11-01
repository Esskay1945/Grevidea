# Google sign-in setup

No project client ID, signing fingerprint, Supabase URL or key is committed by this change.

1. Apply `backend/axum_gateway/migrations/007_google_oauth.sql` to the existing PostgreSQL database. The gateway continues using `DATABASE_URL`; the Supabase publishable key is not a database connection string and is not required here.
2. In the gateway's local, ignored environment file, set `GOOGLE_CLIENT_ID` to your Google **Web application** client ID. Retain the existing database and JWT configuration. Restart Axum.
3. In Google Cloud, configure an Android OAuth client for `com.grevidea.app` and the SHA-1 of the certificate that actually signs the installed APK. Configure the consent screen/test users as required. Debug keys differ between build machines; a GitHub runner's debug key is not your laptop's debug key. Use a stable release signing key for distributed builds.
4. Build locally with `--dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID` and `--dart-define=API_BASE_URL=YOUR_GATEWAY_URL`. The Google value must match the server's audience configuration. Do not commit a file containing real configuration values. A configured APK necessarily contains its public OAuth client ID; the repository and PR do not.
5. For a USB-connected Android phone, `adb reverse tcp:3000 tcp:3000` forwards the phone's `http://localhost:3000` to the laptop gateway. Keep the gateway running. For Android Emulator use `http://10.0.2.2:3000`. For remote use expose a reachable **HTTPS** gateway. Supabase's project HTTPS URL is not the Axum gateway URL.

The SDK obtains a Google ID token and posts it to `/api/v1/auth/google`. Axum validates the RS256 signature using cached keys from Google's fixed JWKS endpoint, audience, issuer, expiration, verified email and subject. Only verified claims determine identity. Existing Google users are looked up by `sub`; new-account initialization is transactional, including the welcome ledger entry.

An existing email/password account is never silently linked based only on a matching email. Sign in with the password, open Profile, and select **Link Google account**. The linking endpoint requires both an authenticated app session and a verified Google token with the same email. Subsequent Google sign-ins use the stable subject ID. Random unknown placeholder hashes prevent Google-only accounts from accepting a made-up password.

Google verification fails closed on invalid credentials or unavailable keys. Raw tokens are not logged or placed in URL queries. Email/password sign-in, password changes, theme, dashboard and tree animation are unchanged. Google account selection and real-device configuration still require manual verification with Google Play services and your Cloud configuration; CI uses synthetic cryptographic fixtures, not personal credentials.

## Installed APK cannot register or sign in

The default CI APK points at `http://localhost:3000`. On a phone that means the phone, not the laptop, unless USB reverse forwarding is active. Supabase does not run the Axum process.

Open **Connection settings** on Login or Sign Up. Enter the reachable laptop Axum URL and choose **Test and save**. The app checks that the URL is a Grevidea gateway and that its database is connected, then saves the URL locally. For USB use the forwarding command above; for Wi-Fi use the laptop IPv4 address on the same network and allow the gateway through the laptop firewall. The gateway must stay running while you test.

Installed APKs now obtain the public Google Web client ID from `/api/v1/auth/config`; rebuilding with a project-specific client ID is no longer required. Set `GOOGLE_CLIENT_ID` in the gateway's local environment and restart it, and apply migrations 006 and 007. The endpoint returns only the public client ID and readiness flags, never JWT or database secrets. Android OAuth still must match the actual installed APK signing certificate. A CI-signed APK uses that build machine's debug key until you configure a stable release signing key; the fingerprint from a different laptop build will not match it.

Authentication errors now distinguish an unreachable gateway, invalid credentials, duplicate registration, throttling, and server/database failures. Connection checks do not sign in or bypass authentication.
