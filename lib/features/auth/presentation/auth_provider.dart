import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/config/app_api_config.dart';
import '../data/auth_repository.dart';
import '../data/auth_api.dart';
import '../data/token_storage.dart';
import '../data/auth_models.dart';

final authRepositoryProvider = Provider((ref) {
  final api = AuthApi(baseUrl: AppApiConfig.authBaseUrl);
  return AuthRepository(api);
});

final tokenStorageProvider = Provider((ref) => TokenStorage());

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStorageProvider),
  );
});

class AuthState {
  final bool isLoading;
  final bool isInitialized;
  final String? error;
  final AuthUser? user;

  AuthState({
    this.isLoading = false, 
    this.isInitialized = false,
    this.error, 
    this.user
  });

  AuthState copyWith({
    bool? isLoading, 
    bool? isInitialized,
    String? error, 
    AuthUser? user
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final TokenStorage _storage;

  AuthNotifier(this._repository, this._storage) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final token = await _storage.getToken();
    if (token != null) {
      // Si ya hay un token, podríamos intentar recuperar el usuario
      // Pero para forzar el login manual según pide el usuario, 
      // lo dejamos así para que el router redirija a /login
    }
    state = state.copyWith(isInitialized: true);
  }

  Future<bool> login(String user, String pass) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.login(user, pass);
      await _storage.saveToken(response.token);
      
      // Guardamos credenciales para persistencia y biometría
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'saved_user', value: user);
      await secureStorage.write(key: 'saved_pass', value: pass);

      state = state.copyWith(isLoading: false, user: response.user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    const secureStorage = FlutterSecureStorage();
    final user = await secureStorage.read(key: 'saved_user');
    final pass = await secureStorage.read(key: 'saved_pass');
    if (user != null && pass != null) {
      return {'user': user, 'pass': pass};
    }
    return null;
  }

  Future<bool> loginWithSavedCredentials() async {
    final credentials = await getSavedCredentials();
    if (credentials != null) {
      return await login(credentials['user']!, credentials['pass']!);
    }
    return false;
  }

  Future<void> logout() async {
    await _storage.deleteToken();
    // Opcional: podemos borrar o mantener el user para auto-completar
    state = AuthState(isInitialized: true);
  }
}
