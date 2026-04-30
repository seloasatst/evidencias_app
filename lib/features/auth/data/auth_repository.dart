import 'auth_api.dart';
import 'auth_models.dart';

class AuthRepository {
  final AuthApi api;
  AuthRepository(this.api);

  Future<LoginResponse> login(String user, String pass) async {
    final json = await api.login(user, pass);
    return LoginResponse.fromJson(json);
  }
}
