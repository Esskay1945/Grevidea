import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/state/app_state.dart';
import 'auth_fixture.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Unknown email and OAuth sentinel cannot bypass server auth', () async {
    final state = AppState(api: AuthFixture());
    expect(await state.login('unknown@example.test', 'google_oauth_token'), isFalse);
    expect(state.isAuthenticated, isFalse);
    state.dispose();
  });
  test('Signup cannot replace an existing password; preferences contain no password', () async {
    final state = AppState(api: AuthFixture());
    await state.initPersistence();
    expect(await state.signup(name:'User',email:'user@example.test',password:'Original123'), isTrue);
    state.logout();
    expect(await state.signup(name:'Attacker',email:'user@example.test',password:'Replacement123'), isFalse);
    expect(state.isAuthenticated, isFalse);
    expect(await state.login('user@example.test', 'Replacement123'), isFalse);
    expect(await state.login('user@example.test', 'Original123'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('grevidea_users_db'), isNot(contains('Original123')));
    state.dispose();
  });
}
