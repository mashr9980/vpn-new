import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart' hide ApiException;

class VPNProvider with ChangeNotifier {
  final VPNApiService _apiService = VPNApiService();

  // Servers
  List<Server> _servers = [];
  bool _isLoadingServers = false;
  String? _serversError;

  // Server health
  final Map<int, ServerHealth> _serverHealthMap = {};
  final Map<int, bool> _healthCheckLoading = {};

  // VPN Connection
  VPNConnection _vpnConnection = VPNConnection(state: VPNState.disconnected);
  Timer? _statusTimer;

  // Configs
  List<VPNConfig> _configs = [];
  bool _isLoadingConfigs = false;
  String? _configsError;

  // Getters
  List<Server> get servers => _servers;
  bool get isLoadingServers => _isLoadingServers;
  String? get serversError => _serversError;

  VPNConnection get vpnConnection => _vpnConnection;
  bool get isConnected => _vpnConnection.isConnected;
  bool get isConnecting => _vpnConnection.isConnecting;
  VPNState get vpnState => _vpnConnection.state;

  List<VPNConfig> get configs => _configs;
  bool get isLoadingConfigs => _isLoadingConfigs;
  String? get configsError => _configsError;

  ServerHealth? getServerHealth(int serverId) => _serverHealthMap[serverId];
  bool isHealthCheckLoading(int serverId) => _healthCheckLoading[serverId] ?? false;

  // Set API token
  void setToken(String? token) {
    _apiService.setToken(token);
  }

  // Load servers
  Future<void> loadServers({bool refresh = false}) async {
    if (_isLoadingServers && !refresh) return;

    try {
      _isLoadingServers = true;
      _serversError = null;
      notifyListeners();

      final response = await _apiService.getServers(limit: 50);

      if (response.isSuccess && response.data != null) {
        _servers = response.data!.items;
        _serversError = null;

        // Load health for all servers
        _loadAllServerHealth();
      } else {
        _serversError = response.message;
      }
    } catch (e) {
      _serversError = _getErrorMessage(e);
    } finally {
      _isLoadingServers = false;
      notifyListeners();
    }
  }

  // Load server health for all servers
  Future<void> _loadAllServerHealth() async {
    for (final server in _servers) {
      _loadServerHealth(server.id, notify: false);
    }
    notifyListeners();
  }

  // Load server health
  Future<void> _loadServerHealth(int serverId, {bool notify = true}) async {
    try {
      _healthCheckLoading[serverId] = true;
      if (notify) notifyListeners();

      final response = await _apiService.getServerHealth(serverId);

      if (response.isSuccess) {
        _serverHealthMap[serverId] = response.data!;
      }
    } catch (e) {
      debugPrint('Failed to load health for server $serverId: $e');
    } finally {
      _healthCheckLoading[serverId] = false;
      if (notify) notifyListeners();
    }
  }

  // Refresh server health
  Future<void> refreshServerHealth(int serverId) async {
    await _loadServerHealth(serverId);
  }

  // Load VPN configs
  Future<void> loadConfigs({bool refresh = false}) async {
    if (_isLoadingConfigs && !refresh) return;

    try {
      _isLoadingConfigs = true;
      _configsError = null;
      notifyListeners();

      final response = await _apiService.getVPNConfigs(limit: 50);

      if (response.isSuccess && response.data != null) {
        _configs = response.data!.items;
        _configsError = null;

        // If we have an active config, update VPN state
        if (_configs.isNotEmpty && _vpnConnection.isDisconnected) {
          final activeConfig = _configs.first;
          _vpnConnection = VPNConnection(
            state: VPNState.connected,
            config: activeConfig,
          );
          _startStatusMonitoring();
        }
      } else {
        _configsError = response.message;
      }
    } catch (e) {
      _configsError = _getErrorMessage(e);
    } finally {
      _isLoadingConfigs = false;
      notifyListeners();
    }
  }

  // Connect to VPN
  Future<bool> connectToVPN(Server server) async {
    try {
      // Check if already connected to this server
      if (_vpnConnection.isConnected &&
          _vpnConnection.config?.serverId == server.id) {
        return true;
      }

      // Set connecting state
      _vpnConnection = VPNConnection(state: VPNState.connecting);
      notifyListeners();

      final response = await _apiService.createVPNConnection(server.id);

      if (response.isSuccess && response.data != null) {
        _vpnConnection = VPNConnection(
          state: VPNState.connected,
          config: response.data!,
        );

        // Add to configs list
        _configs = [response.data!, ..._configs.where((c) => c.id != response.data!.id)];

        // Start monitoring
        _startStatusMonitoring();

        notifyListeners();
        return true;
      } else {
        _vpnConnection = VPNConnection(
          state: VPNState.error,
          errorMessage: response.message,
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _vpnConnection = VPNConnection(
        state: VPNState.error,
        errorMessage: _getErrorMessage(e),
      );
      notifyListeners();
      return false;
    }
  }

  // Disconnect from VPN
  Future<bool> disconnectVPN() async {
    if (!_vpnConnection.isConnected || _vpnConnection.config == null) {
      return true;
    }

    try {
      _vpnConnection = VPNConnection(
        state: VPNState.disconnecting,
        config: _vpnConnection.config,
      );
      notifyListeners();

      final response = await _apiService.disconnectVPN(_vpnConnection.config!.id);

      if (response.isSuccess) {
        _vpnConnection = VPNConnection(state: VPNState.disconnected);

        // Remove from configs
        _configs = _configs.where((c) => c.id != _vpnConnection.config?.id).toList();

        // Stop monitoring
        _stopStatusMonitoring();

        notifyListeners();
        return true;
      } else {
        _vpnConnection = VPNConnection(
          state: VPNState.error,
          config: _vpnConnection.config,
          errorMessage: response.message,
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _vpnConnection = VPNConnection(
        state: VPNState.error,
        config: _vpnConnection.config,
        errorMessage: _getErrorMessage(e),
      );
      notifyListeners();
      return false;
    }
  }

  // Force disconnect
  Future<bool> forceDisconnectVPN() async {
    if (!_vpnConnection.isConnected || _vpnConnection.config == null) {
      return true;
    }

    try {
      final response = await _apiService.forceDisconnectVPN(_vpnConnection.config!.id);

      if (response.isSuccess) {
        _vpnConnection = VPNConnection(state: VPNState.disconnected);
        _configs = _configs.where((c) => c.id != _vpnConnection.config?.id).toList();
        _stopStatusMonitoring();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Start status monitoring
  void _startStatusMonitoring() {
    _stopStatusMonitoring();

    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateConnectionStatus();
    });

    // Initial status update
    _updateConnectionStatus();
  }

  // Stop status monitoring
  void _stopStatusMonitoring() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  // Update connection status
  Future<void> _updateConnectionStatus() async {
    if (!_vpnConnection.isConnected || _vpnConnection.config == null) {
      return;
    }

    try {
      final response = await _apiService.getVPNStatus(_vpnConnection.config!.id);

      if (response.isSuccess) {
        _vpnConnection = VPNConnection(
          state: VPNState.connected,
          config: _vpnConnection.config,
          status: response.data!,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update VPN status: $e');
    }
  }

  // Get VPN config file
  Future<VPNConfigFile?> getConfigFile(VPNConfig config) async {
    try {
      final response = await _apiService.downloadVPNConfig(config.id);
      if (response.isSuccess) {
        return response.data!;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get config file: $e');
      return null;
    }
  }

  // Clear errors
  void clearServersError() {
    _serversError = null;
    notifyListeners();
  }

  void clearConfigsError() {
    _configsError = null;
    notifyListeners();
  }

  void clearVPNError() {
    if (_vpnConnection.hasError) {
      _vpnConnection = VPNConnection(state: VPNState.disconnected);
      notifyListeners();
    }
  }

  // Reset VPN state
  void resetVPNState() {
    _vpnConnection = VPNConnection(state: VPNState.disconnected);
    _stopStatusMonitoring();
    notifyListeners();
  }

  // Get error message
  String _getErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  @override
  void dispose() {
    _stopStatusMonitoring();
    super.dispose();
  }
}