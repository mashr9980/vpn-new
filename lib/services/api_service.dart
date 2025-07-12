// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  ApiException(this.message, {this.code, this.statusCode, this.details});

  @override
  String toString() => message;
}

class VPNApiService {
  static const String baseUrl = 'http://192.168.18.23:8002/api/v1';

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<ApiResponse<T>> _handleResponse<T>(
      http.Response response,
      T Function(dynamic)? fromJson,
      ) async {
    final Map<String, dynamic> responseData;

    try {
      responseData = json.decode(response.body);
    } catch (e) {
      throw ApiException('Invalid response format');
    }

    final apiResponse = ApiResponse<T>.fromJson(responseData, fromJson);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return apiResponse;
    } else {
      throw ApiException(
        apiResponse.message,
        code: apiResponse.code,
        statusCode: response.statusCode,
        details: apiResponse.details,
      );
    }
  }

  // Authentication
  Future<ApiResponse<AuthData>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<AuthData>(
        response,
            (data) => AuthData.fromJson(data),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } on HttpException {
      throw ApiException('Server error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Registration failed: ${e.toString()}');
    }
  }

  Future<ApiResponse<AuthData>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<AuthData>(
        response,
            (data) => AuthData.fromJson(data),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } on HttpException {
      throw ApiException('Server error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Login failed: ${e.toString()}');
    }
  }

  Future<ApiResponse<AuthData>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<AuthData>(
        response,
            (data) => AuthData.fromJson(data),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get user info: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<Map<String, dynamic>>(
        response,
            (data) => data,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Logout failed: ${e.toString()}');
    }
  }

  // Servers
  Future<ApiResponse<PaginatedData<Server>>> getServers({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/servers').replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      });

      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<PaginatedData<Server>>(
        response,
            (data) => PaginatedData.fromJson(
          data['servers'] != null
              ? {'items': data['servers'], ...data}
              : data,
              (json) => Server.fromJson(json),
        ),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get servers: ${e.toString()}');
    }
  }

  Future<ApiResponse<Server>> getServer(int serverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/servers/$serverId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<Server>(
        response,
            (data) => Server.fromJson(data),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get server: ${e.toString()}');
    }
  }

  // Fixed: Return ServerHealth directly instead of ApiResponse<ServerHealth>
  Future<ApiResponse<ServerHealth>> getServerHealth(int serverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/servers/$serverId/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<ServerHealth>(
        response,
            (data) => ServerHealth.fromJson(data),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to check server health: ${e.toString()}');
    }
  }

  // VPN
  Future<ApiResponse<PaginatedData<VPNConfig>>> getVPNConfigs({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/vpn/configs').replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      });

      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<PaginatedData<VPNConfig>>(
        response,
            (data) => PaginatedData.fromJson(
          data,
              (json) => VPNConfig.fromJson(json),
        ),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get VPN configs: ${e.toString()}');
    }
  }

  Future<ApiResponse<VPNConfig>> createVPNConnection(int serverId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vpn/create'),
        headers: _headers,
        body: jsonEncode({
          'server_id': serverId,
        }),
      ).timeout(const Duration(seconds: 60));

      return _handleResponse<VPNConfig>(
        response,
            (data) => VPNConfig.fromJson(data['config']),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to create VPN connection: ${e.toString()}');
    }
  }

  // Fixed: Return ApiResponse<VPNConfigFile> to match return type
  Future<ApiResponse<VPNConfigFile>> downloadVPNConfig(int configId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vpn/config/$configId/download'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<VPNConfigFile>(
        response,
            (data) => VPNConfigFile.fromJson(data),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to download VPN config: ${e.toString()}');
    }
  }

  // Fixed: Return ApiResponse<VPNConnectionStatus> to match usage
  Future<ApiResponse<VPNConnectionStatus>> getVPNStatus(int configId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vpn/config/$configId/status'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<VPNConnectionStatus>(
        response,
            (data) => VPNConnectionStatus.fromJson(data),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get VPN status: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> disconnectVPN(int configId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/vpn/config/$configId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<Map<String, dynamic>>(
        response,
            (data) => data,
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to disconnect VPN: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> forceDisconnectVPN(int configId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vpn/config/$configId/force-disconnect'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<Map<String, dynamic>>(
        response,
            (data) => data,
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to force disconnect VPN: ${e.toString()}');
    }
  }

  // Health check
  Future<bool> checkApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl.replaceAll('/api/v1', '')}/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}