import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grevidea/core/network/api_service.dart';

class GoogleExchange extends ApiService {
  GoogleExchange() : super.forTesting();
  ApiResult result = const ApiResult(401, null);
  Completer<ApiResult>? pending;
  String? sentToken;
  @override Future<ApiResult> requestDetailed(String path, {Map<String,dynamic>? data, String method = 'POST'}) async {
    sentToken = data?['id_token'];
    if (pending != null) return await pending!.future;
    return result;
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Only a complete verified server response establishes Google identity', () async {
    final api = GoogleExchange();
    expect(await api.googleAuth('sdk-token'), isNull);
    expect(api.authenticatedEmail, isNull);
    api.result = const ApiResult(200, {'token':'gateway-jwt','email':'verified@example.test','user_id':'fixture-user'});
    expect(await api.googleAuth('sdk-token'), isNotNull);
    expect(api.sentToken, 'sdk-token');
    expect(api.authenticatedEmail, 'verified@example.test');
    api.result = const ApiResult(200, {'token':'incomplete'});
    expect(await api.googleAuth('sdk-token'), isNull);
    expect(api.authenticatedEmail, isNull);
  });
  test('Logout invalidates a pending Google exchange', () async {
    final api = GoogleExchange()..pending = Completer<ApiResult>();
    final exchange = api.googleAuth('sdk-token');
    api.setAuthToken(null);
    api.pending!.complete(const ApiResult(200, {'token':'gateway-jwt','email':'fixture@example.test','user_id':'fixture-user'}));
    expect(await exchange, isNull);
    expect(api.authenticatedEmail, isNull);
  });
}
