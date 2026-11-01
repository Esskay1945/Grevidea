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
