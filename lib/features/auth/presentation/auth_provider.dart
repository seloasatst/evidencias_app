import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_api_config.dart';
import '../data/auth_repository.dart';
import '../data/auth_api.dart';
import '../data/token_storage.dart';
import '../../home/presentation/route_provider.dart';
import '../data/auth_models.dart';

import '../../../core/network/http_client_provider.dart';

final authRepositoryProvider = Provider((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final api = AuthApi(
    baseUrl: AppApiConfig.authBaseUrl,
    client: httpClient,
  );
  return AuthRepository(api);
});

final tokenStorageProvider = Provider((ref) => TokenStorage());

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref,
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
  final Ref _ref;
  final AuthRepository _repository;
  final TokenStorage _storage;

  AuthNotifier(this._ref, this._repository, this._storage) : super(AuthState()) {
    _init();
  }

  static const _prefChecadorSapCode = 'checador_sap_code';
  static const _prefChecadorNombre = 'checador_nombre_empleado';

  Future<void> _persistChecadorIdentity(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();

    final sapCode = user.code.trim().isNotEmpty
        ? user.code.trim()
        : (user.cardCode?.trim().isNotEmpty == true
            ? user.cardCode!.trim()
            : user.username.trim());
    if (sapCode.isNotEmpty) {
      await prefs.setString(_prefChecadorSapCode, sapCode);
    }

    final nombre = user.name.trim().isNotEmpty
        ? user.name.trim()
        : user.username.trim();
    if (nombre.isNotEmpty) {
      await prefs.setString(_prefChecadorNombre, nombre);
    }
  }

  Future<void> _init() async {
    try {
      // Timeout de 5s para evitar bloqueo del Android KeyStore en dispositivos MediaTek
      await _storage.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (_) {
      // Si falla el almacenamiento seguro, continuamos de todas formas
    } finally {
      // isInitialized SIEMPRE se establece para que el router no se quede colgado
      if (mounted) state = state.copyWith(isInitialized: true);
    }
  }

  Future<bool> login(String user, String pass) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.login(user, pass);
      await _storage.saveToken(response.token);

      await _persistChecadorIdentity(response.user);
      
      // Guardamos credenciales para persistencia y biometría
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      await secureStorage.write(key: 'saved_user', value: user);
      await secureStorage.write(key: 'saved_pass', value: pass);

      state = state.copyWith(isLoading: false, user: response.user);
      
      // precarga de rutas: disparamos la carga en cuanto tenemos el usuario
      // ignoramos el resultado porque se cargará en el provider global
      _ref.read(pendingRoutesProvider.notifier).loadInitial();
      
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
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
