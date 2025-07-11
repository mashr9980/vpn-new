import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final VPNApiService _apiService = VPNApiService();

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null && _token != null;
  bool get isInitialized => _isInitialized;

  // Initialize auth state from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      final prefs = await SharedPreferences.getInstance();

      final savedToken = prefs.getString('auth_token');
      final savedUserJson = prefs.getString('user_data');

      if (savedToken != null && savedUserJson != null) {
        _token = savedToken;
        _apiService.setToken(savedToken);

        // Try to get current user to validate token
        try {
          final response = await _apiService.getCurrentUser();
          if (response.isSuccess && response.data != null) {
            _user = response.data!.user;
            _token = savedToken;
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
      _isInitialized = true;
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
        debugPrint('Server logout failed: $e');
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
        _user = response.data!.user;
        await _saveUserData();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to refresh user: $e');
    }
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _setAuthData(AuthData authData) async {
    _user = authData.user;
    _token = authData.accessToken;
    _apiService.setToken(_token);

    await _saveAuthData(authData);
    notifyListeners();
  }

  Future<void> _clearAuthData() async {
    _user = null;
    _token = null;
    _apiService.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');

    notifyListeners();
  }

  Future<void> _saveAuthData(AuthData authData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', authData.accessToken);
    await prefs.setString('user_data', authData.user.toJson().toString());
  }

  Future<void> _saveUserData() async {
    if (_user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', _user!.toJson().toString());
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

  // Check if token is expired (simple check)
  bool get isTokenExpired {
    // In a real app, you might want to decode the JWT token
    // and check the expiration time
    return false;
  }
}