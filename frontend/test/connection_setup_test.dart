import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/core/network/api_service.dart';
import 'package:grevidea/state/app_state.dart';
import 'auth_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Registration reports an unreachable server and never authenticates', () async {
    final api = ApiService.forTesting(client: MockClient((_) async => throw http.ClientException('offline')));
    final result = await api.register(email:'new@example.test',password:'Password123!',displayName:'New user');
    expect(result, isNull);
    expect(api.authenticatedEmail, isNull);
    expect(api.authFailure, contains('Connection settings'));
    api.close();
  });
  test('Duplicate email response is retained instead of a generic login error', () async {
    final api = ApiService.forTesting(client: MockClient((_) async => http.Response(jsonEncode({'error':'Email already registered'}),400)));
    expect(await api.register(email:'existing@example.test',password:'Password123!',displayName:'Existing'), isNull);
    expect(api.authFailure, 'Email already registered');
    api.close();
  });
  test('Phone can register against its configured laptop gateway', () async {
    final api = ApiService.forTesting(client: MockClient((request) async {
      expect(request.url.host, '192.168.1.20');
      expect(request.url.port, 3000);
      expect(request.url.path, '/api/v1/auth/register');
      return http.Response(jsonEncode({'data':{'token':'fixture-jwt','user_id':'new-user','display_name':'New user'}}),200);
    }));
    api.setBaseUrl('http://192.168.1.20:3000');
    expect(await api.register(email:'new@example.test',password:'Password123!',displayName:'New user'), isNotNull);
    expect(api.authenticatedEmail, 'new@example.test');
    api.close();
  });
  test('Runtime Google configuration works without a client ID in the APK', () async {
    final api = ApiService.forTesting(client: MockClient((request) async => http.Response(jsonEncode({'data':{
      'google_client_id':'synthetic-client','google_configured':true,'google_database_ready':true,
    }}),200)));
    expect(await api.fetchGoogleClientId(), 'synthetic-client');
    api.close();
  });
  test('Connection checks distinguish gateway from Supabase and broken database', () async {
    expect(ApiService.validateBaseUrl('https://example.supabase.co'), contains('Supabase'));
    expect(ApiService.validateBaseUrl('http://192.168.1.20:3000'), isNull);
    final api = ApiService.forTesting(client: MockClient((_) async => http.Response(jsonEncode({
      'service':'grevidea-gateway','database_connected':false,
    }),200)));
    final result = await api.inspectConnection();
    expect(result['ready'], false);
    expect(result['message'], contains('DATABASE_URL'));
    api.close();
  });
  test('Saved gateway survives restart without restoring an authenticated session', () async {
    final state = AppState(api: AuthFixture());
    await state.initPersistence();
    await state.saveGatewayUrl('http://192.168.1.20:3000');
    final restored = AppState(api: AuthFixture());
    await restored.initPersistence();
    expect(restored.api.baseUrl, 'http://192.168.1.20:3000');
    expect(restored.isAuthenticated, false);
    state.dispose(); restored.dispose();
  });
}
