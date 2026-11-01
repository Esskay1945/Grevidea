import 'package:grevidea/core/network/api_service.dart';
class AuthFixture extends ApiService {
  AuthFixture() : super.forTesting();
  final users = <String, String>{};
  @override Future<bool> checkHealth() async => false;
  @override Future<Map<String,dynamic>?> register({required String email, required String password, required String displayName}) async {
    if (users.containsKey(email)) return null;
    users[email] = password;
    return {'token': 'test-only', 'user_id': email, 'display_name': displayName};
  }
  @override Future<Map<String,dynamic>?> login(String email, String password) async =>
    users[email] == password ? {'token':'test-only','display_name': email.split('@').first} : null;
  @override Future<dynamic> request(String path, {Map<String,dynamic>? data}) async => null;
}
