// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
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
  static const String baseUrl = 'https://6b28282ded1a.ngrok-free.app';

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

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Future<ApiResponse<T>> _handleResponse<T>(
      http.Response response,
      T Function(dynamic)? fromJson,
      ) async {
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    print('Response Headers: ${response.headers}');

    final Map<String, dynamic> responseData;

    try {
      responseData = json.decode(response.body);
    } catch (e) {
      print('JSON Decode Error: $e');
      throw ApiException('Invalid response format: ${response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // For successful responses, manually create ApiResponse with proper data handling
      final data = responseData['data'];
      print('Extracted data: $data');
      print('Data type: ${data.runtimeType}');

      T? parsedData;
      if (data != null && fromJson != null) {
        try {
          // Ensure data is Map<String, dynamic>
          if (data is Map<String, dynamic>) {
            print('Data is Map<String, dynamic>, proceeding with parsing...');
            print('Data contents: ${data.toString()}');
            parsedData = fromJson(data);
            print('Parsed data successfully: $parsedData');
          } else {
            print('Data is not Map<String, dynamic>, it is: ${data.runtimeType}');
            throw ApiException('Invalid data format received');
          }
        } catch (e) {
          print('Error parsing data: $e');
          print('Data that failed parsing: $data');
          throw ApiException('Failed to parse response data: ${e.toString()}');
        }
      }

      return ApiResponse<T>(
        status: responseData['status'] ?? 'success',
        message: responseData['message'] ?? 'Success',
        data: parsedData,
        errors: responseData['errors'] != null ? List<String>.from(responseData['errors']) : null,
        timestamp: responseData['timestamp'] ?? DateTime.now().toIso8601String(),
        code: responseData['code'],
        details: responseData['details'],
      );
    } else {
      // For error responses
      final apiResponse = ApiResponse<T>.fromJson(responseData, fromJson);
      print('API Error - Status: ${response.statusCode}, Message: ${apiResponse.message}');
      throw ApiException(
        apiResponse.message,
        code: apiResponse.code,
        statusCode: response.statusCode,
        details: apiResponse.details,
      );
    }
  }

  Future<ApiResponse<AuthData>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

    try {
      print('Making register request to: $baseUrl/auth/register');
      print('Request body: ${jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      })}');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      print('About to call _handleResponse with AuthData.fromJson for register');
      return _handleResponse<AuthData>(
        response,
            (data) {
          print('AuthData.fromJson called with data: $data');
          print('Data type in fromJson: ${data.runtimeType}');
          return AuthData.fromJson(data as Map<String, dynamic>);
        },
      );
    } on SocketException catch (e) {
      print('SocketException: $e');
      throw ApiException('No internet connection');
    } on HttpException catch (e) {
      print('HttpException: $e');
      throw ApiException('Server error occurred');
    } on TimeoutException catch (e) {
      print('TimeoutException: $e');
      throw ApiException('Request timeout');
    } catch (e) {
      print('Unexpected error in register: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Registration failed: ${e.toString()}');
    }
  }

  Future<ApiResponse<AuthData>> login({
    required String username,
    required String password,
  }) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

    try {
      print('Making login request to: $baseUrl/auth/login');
      print('Request body: ${jsonEncode({
        'username': username,
        'password': password,
      })}');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      print('About to call _handleResponse with AuthData.fromJson');
      return _handleResponse<AuthData>(
        response,
            (data) {
          print('AuthData.fromJson called with data: $data');
          print('Data type in fromJson: ${data.runtimeType}');
          return AuthData.fromJson(data as Map<String, dynamic>);
        },
      );
    } on SocketException catch (e) {
      print('SocketException: $e');
      throw ApiException('No internet connection');
    } on HttpException catch (e) {
      print('HttpException: $e');
      throw ApiException('Server error occurred');
    } on TimeoutException catch (e) {
      print('TimeoutException: $e');
      throw ApiException('Request timeout');
    } catch (e) {
      print('Unexpected error in login: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Login failed: ${e.toString()}');
    }
  }

  Future<ApiResponse<AuthData>> getCurrentUser() async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

    try {
      print('Making getCurrentUser request to: $baseUrl/auth/me');
      print('Headers: $_headers');

      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse<AuthData>(
        response,
            (data) => AuthData.fromJson(data['data']),
      );
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      print('Error in getCurrentUser: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get user info: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> logout() async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

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

  Future<ApiResponse<PaginatedData<Server>>> getServers({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

    try {
      final uri = Uri.parse('$baseUrl/servers').replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      });

      print('Making getServers request to: $uri');

      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      print('getServers Response Status Code: ${response.statusCode}');
      print('getServers Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = response.body;

        // Check if response is a direct array or structured response
        if (responseBody.trim().startsWith('[')) {
          // Direct array response
          final List<dynamic> serverList = json.decode(responseBody);
          print('Received direct array of ${serverList.length} servers');

          final servers = serverList
              .map((serverJson) => Server.fromJson(serverJson as Map<String, dynamic>))
              .toList();

          final paginatedData = PaginatedData<Server>(
            items: servers,
            total: servers.length,
            page: page,
            limit: limit,
            pages: 1,
          );

          return ApiResponse<PaginatedData<Server>>(
            status: 'success',
            message: 'Servers loaded successfully',
            data: paginatedData,
            timestamp: DateTime.now().toIso8601String(),
          );
        } else {
          // Structured response format
          return _handleResponse<PaginatedData<Server>>(
            response,
                (data) => PaginatedData.fromJson(
              data['servers'] != null
                  ? {'items': data['servers'], ...data}
                  : data,
                  (json) => Server.fromJson(json),
            ),
          );
        }
      } else {
        return _handleResponse<PaginatedData<Server>>(
          response,
              (data) => PaginatedData.fromJson(
            data['servers'] != null
                ? {'items': data['servers'], ...data}
                : data,
                (json) => Server.fromJson(json),
          ),
        );
      }
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      print('Error in getServers: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to get servers: ${e.toString()}');
    }
  }

  Future<ApiResponse<Server>> getServer(int serverId) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

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

  Future<ApiResponse<ServerHealth>> getServerHealth(int serverId) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

    try {
      print('Making getServerHealth request to: $baseUrl/servers/$serverId/health');

      final response = await http.get(
        Uri.parse('$baseUrl/servers/$serverId/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      print('getServerHealth Response Status Code: ${response.statusCode}');
      print('getServerHealth Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = response.body;

        // Check if response is direct object or structured response
        final responseData = json.decode(responseBody);

        if (responseData is Map<String, dynamic>) {
          // Check if it has 'status' and 'data' fields (structured) or direct health data
          if (responseData.containsKey('status') && responseData.containsKey('data')) {
            // Structured response
            return _handleResponse<ServerHealth>(
              response,
                  (data) => ServerHealth.fromJson(data as Map<String, dynamic>),
            );
          } else {
            // Direct health data response
            print('Received direct health data for server $serverId');
            final serverHealth = ServerHealth.fromJson(responseData);

            return ApiResponse<ServerHealth>(
              status: 'success',
              message: 'Server health retrieved successfully',
              data: serverHealth,
              timestamp: DateTime.now().toIso8601String(),
            );
          }
        } else {
          throw ApiException('Invalid server health response format');
        }
      } else {
        return _handleResponse<ServerHealth>(
          response,
              (data) => ServerHealth.fromJson(data as Map<String, dynamic>),
        );
      }
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      print('Error in getServerHealth: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to check server health: ${e.toString()}');
    }
  }

  Future<ApiResponse<PaginatedData<VPNConfig>>> getVPNConfigs({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

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
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

    try {
      print('Making createVPNConnection request to: $baseUrl/vpn/create');
      print('Request body: ${jsonEncode({'server_id': serverId})}');

      final response = await http.post(
        Uri.parse('$baseUrl/vpn/create'),
        headers: _headers,
        body: jsonEncode({
          'server_id': serverId,
        }),
      ).timeout(const Duration(seconds: 60));

      print('createVPNConnection Response Status Code: ${response.statusCode}');
      print('createVPNConnection Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);

        // Check if it's structured response or direct config data
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('status') && responseData.containsKey('data')) {
            // Structured response
            return _handleResponse<VPNConfig>(
              response,
                  (data) => VPNConfig.fromJson(data['config'] ?? data),
            );
          } else if (responseData.containsKey('config')) {
            // Direct response with config field
            final vpnConfig = VPNConfig.fromJson(responseData['config']);
            return ApiResponse<VPNConfig>(
              status: 'success',
              message: 'VPN connection created successfully',
              data: vpnConfig,
              timestamp: DateTime.now().toIso8601String(),
            );
          } else {
            // Direct config response
            final vpnConfig = VPNConfig.fromJson(responseData);
            return ApiResponse<VPNConfig>(
              status: 'success',
              message: 'VPN connection created successfully',
              data: vpnConfig,
              timestamp: DateTime.now().toIso8601String(),
            );
          }
        } else {
          throw ApiException('Invalid VPN creation response format');
        }
      } else {
        // Handle error responses
        final responseData = json.decode(response.body);
        String errorMessage = 'Failed to create VPN connection';

        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['detail'] ??
              responseData['message'] ??
              'Server error occurred';
        }

        throw ApiException(
          errorMessage,
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      print('Error in createVPNConnection: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Failed to create VPN connection: ${e.toString()}');
    }
  }

  Future<ApiResponse<VPNConfigFile>> downloadVPNConfig(int configId) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

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

  Future<ApiResponse<VPNConnectionStatus>> getVPNStatus(int configId) async {
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

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
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

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
    if (!await _checkConnectivity()) {
      throw ApiException('No internet connection available');
    }

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

  Future<bool> checkApiHealth() async {
    if (!await _checkConnectivity()) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}