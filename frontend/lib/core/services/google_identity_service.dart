import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Public OAuth configuration is supplied locally at build time, never committed.
class GoogleIdentityService {
  static const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static Future<String?> acquireIdToken() async {
    if (clientId.isEmpty) throw StateError('Google sign-in is not configured in this build.');
    final google = GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: kIsWeb ? clientId : null,
      serverClientId: kIsWeb ? null : clientId,
    );
    final account = await google.signIn();
    if (account == null) return null;
    final credentials = await account.authentication;
    final token = credentials.idToken;
    if (token == null || token.isEmpty) throw StateError('Google did not return an ID token.');
    return token;
  }
}
