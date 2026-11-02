import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/state/app_state.dart';
import 'auth_fixture.dart';

class NoAuthServer extends AuthFixture {
  @override Future<Map<String,dynamic>?> login(String email,String password) => throw StateError('Login must not contact a server');
  @override Future<Map<String,dynamic>?> register({required String email,required String password,required String displayName}) => throw StateError('Registration must not contact a server');
  @override Future<Map<String,dynamic>?> googleAuth(String token) => throw StateError('Google must not contact a server');
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Local login and registration accept arbitrary credentials without a server', () async {
    final api = NoAuthServer();
    final state = AppState(api: api);
    expect(await state.signup(name:'Local tester',email:'local@example.test',password:'Anything123'), isTrue);
    state.completeOnboarding();
    state.logout();
    expect(await state.login('local@example.test','Different123'), isTrue);
    expect(state.hasCompletedOnboarding, isTrue);
    expect(api.authenticatedEmail, isNull);
    expect(api.userId, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('grevidea_users_db'), isNot(contains('Anything123')));
    state.logout(); state.dispose();
  });
  test('Google button uses a local profile without an SDK token or backend', () async {
    final api = NoAuthServer();
    final state = AppState(api: api);
    expect(await state.loginLocallyWithGoogle(), isTrue);
    expect(state.isAuthenticated, isTrue);
    expect(state.userName, 'Local User');
    expect(api.authenticatedEmail, isNull);
    state.logout(); state.dispose();
  });
}
