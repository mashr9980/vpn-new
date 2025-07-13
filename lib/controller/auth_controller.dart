// lib/controllers/auth_controller.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/app_models.dart';
import '../services/api_service.dart' hide ApiException;

class AuthController extends GetxController {
  final VPNApiService _apiService = Get.find<VPNApiService>();
  final _storage = GetStorage();

  // Reactive variables
  final Rx<User?> _user = Rx<User?>(null);
  final RxString _token = ''.obs;
  final RxBool _isLoading = false.obs;
  final RxString _error = ''.obs;
  final RxBool _isInitialized = false.obs;

  // Getters
  User? get user => _user.value;
  String get token => _token.value;
  bool get isLoading => _isLoading.value;
  String get error => _error.value;
  bool get isAuthenticated => user != null && token.isNotEmpty;
  bool get isInitialized => _isInitialized.value;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  // Initialize auth state from storage
  Future<void> initialize() async {
    if (_isInitialized.value) return;

    try {
      _setLoading(true);

      final savedToken = _storage.read('auth_token');
      final savedUserData = _storage.read('user_data');

      if (savedToken != null && savedUserData != null) {
        _token.value = savedToken;
        _apiService.setToken(savedToken);

        // Try to get current user to validate token
        try {
          final response = await _apiService.getCurrentUser();
          if (response.isSuccess && response.data != null) {
            _user.value = response.data!.user;
            _token.value = savedToken;
          } else {
            // Token is invalid, clear storage
            await _clearAuthData();
          }
        } catch (e) {
          // Token is invalid, clear storage
          await _clearAuthData();
        }
      }
    } catch (e) {
      _setError('Failed to initialize auth: ${e.toString()}');
    } finally {
      _setLoading(false);
      _isInitialized.value = true;
    }
  }

  // Register user
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _apiService.register(
        username: username,
        email: email,
        password: password,
      );

      if (response.isSuccess && response.data != null) {
        await _setAuthData(response.data!);
        return true;
      } else {
        _setError(response.message);
        return false;
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Login user
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _apiService.login(
        username: username,
        password: password,
      );

      if (response.isSuccess && response.data != null) {
        await _setAuthData(response.data!);
        return true;
      } else {
        _setError(response.message);
        return false;
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      _setLoading(true);

      // Try to logout from server
      try {
        await _apiService.logout();
      } catch (e) {
        // Continue with local logout even if server logout fails
        print('Server logout failed: $e');
      }

      await _clearAuthData();
    } catch (e) {
      _setError('Logout failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    if (!isAuthenticated) return;

    try {
      final response = await _apiService.getCurrentUser();
      if (response.isSuccess && response.data != null) {
        _user.value = response.data!.user;
        await _saveUserData();
      }
    } catch (e) {
      print('Failed to refresh user: $e');
    }
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void _setError(String error) {
    _error.value = error;
  }

  void _clearError() {
    _error.value = '';
  }

  Future<void> _setAuthData(AuthData authData) async {
    _user.value = authData.user;
    _token.value = authData.accessToken;
    _apiService.setToken(_token.value);

    await _saveAuthData(authData);
  }

  Future<void> _clearAuthData() async {
    _user.value = null;
    _token.value = '';
    _apiService.setToken(null);

    await _storage.remove('auth_token');
    await _storage.remove('user_data');
  }

  Future<void> _saveAuthData(AuthData authData) async {
    await _storage.write('auth_token', authData.accessToken);
    await _storage.write('user_data', authData.user.toJson());
  }

  Future<void> _saveUserData() async {
    if (_user.value == null) return;
    await _storage.write('user_data', _user.value!.toJson());
  }

  String _getErrorMessage(dynamic error) {
    if (error is ApiException) {
      // Handle specific API errors
      switch (error.code) {
        case 'VALIDATION_ERROR':
          return 'Please check your input and try again';
        case 'AUTH_ERROR':
          return 'Invalid username or password';
        case 'RESOURCE_CONFLICT':
          if (error.message.contains('username')) {
            return 'Username already exists';
          } else if (error.message.contains('email')) {
            return 'Email already registered';
          }
          return error.message;
        case 'RESOURCE_NOT_FOUND':
          return 'User not found';
        default:
          return error.message;
      }
    }

    return error.toString();
  }

  // Clear error manually
  void clearError() {
    _clearError();
  }
}