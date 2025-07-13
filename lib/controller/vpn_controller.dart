// lib/controllers/vpn_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import '../models/app_models.dart';
import '../services/api_service.dart' hide ApiException;

class VPNController extends GetxController {
  final VPNApiService _apiService = Get.find<VPNApiService>();

  // Servers
  final RxList<Server> _servers = <Server>[].obs;
  final RxBool _isLoadingServers = false.obs;
  final RxString _serversError = ''.obs;

  // Server health
  final RxMap<int, ServerHealth> _serverHealthMap = <int, ServerHealth>{}.obs;
  final RxMap<int, bool> _healthCheckLoading = <int, bool>{}.obs;

  // VPN Connection
  final Rx<VPNConnection> _vpnConnection = VPNConnection(state: VPNState.disconnected).obs;
  Timer? _statusTimer;

  // Configs
  final RxList<VPNConfig> _configs = <VPNConfig>[].obs;
  final RxBool _isLoadingConfigs = false.obs;
  final RxString _configsError = ''.obs;

  // Getters
  List<Server> get servers => _servers;
  bool get isLoadingServers => _isLoadingServers.value;
  String get serversError => _serversError.value;

  VPNConnection get vpnConnection => _vpnConnection.value;
  bool get isConnected => _vpnConnection.value.isConnected;
  bool get isConnecting => _vpnConnection.value.isConnecting;
  VPNState get vpnState => _vpnConnection.value.state;

  List<VPNConfig> get configs => _configs;
  bool get isLoadingConfigs => _isLoadingConfigs.value;
  String get configsError => _configsError.value;

  ServerHealth? getServerHealth(int serverId) => _serverHealthMap[serverId];
  bool isHealthCheckLoading(int serverId) => _healthCheckLoading[serverId] ?? false;

  @override
  void onClose() {
    _stopStatusMonitoring();
    super.onClose();
  }

  // Set API token
  void setToken(String? token) {
    _apiService.setToken(token);
  }

  // Load servers
  Future<void> loadServers({bool refresh = false}) async {
    if (_isLoadingServers.value && !refresh) return;

    try {
      _isLoadingServers.value = true;
      _serversError.value = '';

      final response = await _apiService.getServers(limit: 50);

      if (response.isSuccess && response.data != null) {
        _servers.value = response.data!.items;
        _serversError.value = '';

        // Load health for all servers
        _loadAllServerHealth();
      } else {
        _serversError.value = response.message;
      }
    } catch (e) {
      _serversError.value = _getErrorMessage(e);
    } finally {
      _isLoadingServers.value = false;
    }
  }

  // Load server health for all servers
  Future<void> _loadAllServerHealth() async {
    for (final server in _servers) {
      _loadServerHealth(server.id, notify: false);
    }
  }

  // Load server health
  Future<void> _loadServerHealth(int serverId, {bool notify = true}) async {
    try {
      _healthCheckLoading[serverId] = true;

      final response = await _apiService.getServerHealth(serverId);

      if (response.isSuccess && response.data != null) {
        _serverHealthMap[serverId] = response.data!;
      }
    } catch (e) {
      print('Failed to load health for server $serverId: $e');
    } finally {
      _healthCheckLoading[serverId] = false;
    }
  }

  // Refresh server health
  Future<void> refreshServerHealth(int serverId) async {
    await _loadServerHealth(serverId);
  }

  // Load VPN configs
  Future<void> loadConfigs({bool refresh = false}) async {
    if (_isLoadingConfigs.value && !refresh) return;

    try {
      _isLoadingConfigs.value = true;
      _configsError.value = '';

      final response = await _apiService.getVPNConfigs(limit: 50);

      if (response.isSuccess && response.data != null) {
        _configs.value = response.data!.items;
        _configsError.value = '';

        // If we have an active config, update VPN state
        if (_configs.isNotEmpty && _vpnConnection.value.isDisconnected) {
          final activeConfig = _configs.first;
          _vpnConnection.value = VPNConnection(
            state: VPNState.connected,
            config: activeConfig,
          );
          _startStatusMonitoring();
        }
      } else {
        _configsError.value = response.message;
      }
    } catch (e) {
      _configsError.value = _getErrorMessage(e);
    } finally {
      _isLoadingConfigs.value = false;
    }
  }

  // Connect to VPN
  Future<bool> connectToVPN(Server server) async {
    try {
      // Check if already connected to this server
      if (_vpnConnection.value.isConnected &&
          _vpnConnection.value.config?.serverId == server.id) {
        return true;
      }

      // Set connecting state
      _vpnConnection.value = VPNConnection(state: VPNState.connecting);

      // Check if user already has a config for this server
      final existingConfig = FirstWhereExt(_configs).firstWhereOrNull((config) => config.serverId == server.id);

      if (existingConfig != null) {
        // Use existing config instead of creating new one
        _vpnConnection.value = VPNConnection(
          state: VPNState.connected,
          config: existingConfig,
        );

        // Start monitoring
        _startStatusMonitoring();

        return true;
      }

      final response = await _apiService.createVPNConnection(server.id);

      if (response.isSuccess && response.data != null) {
        _vpnConnection.value = VPNConnection(
          state: VPNState.connected,
          config: response.data!,
        );

        // Add to configs list
        _configs.value = [response.data!, ..._configs.where((c) => c.id != response.data!.id)];

        // Start monitoring
        _startStatusMonitoring();

        return true;
      } else {
        _vpnConnection.value = VPNConnection(
          state: VPNState.error,
          errorMessage: response.message,
        );
        return false;
      }
    } catch (e) {
      String errorMessage = _getErrorMessage(e);

      // Handle specific error for existing config
      if (errorMessage.contains('already has an active configuration')) {
        // Reload configs and try to use existing one
        await loadConfigs(refresh: true);
        final existingConfig = FirstWhereExt(_configs).firstWhereOrNull((config) => config.serverId == server.id);

        if (existingConfig != null) {
          _vpnConnection.value = VPNConnection(
            state: VPNState.connected,
            config: existingConfig,
          );
          _startStatusMonitoring();
          return true;
        }
      }

      _vpnConnection.value = VPNConnection(
        state: VPNState.error,
        errorMessage: errorMessage,
      );
      return false;
    }
  }

  // Disconnect from VPN
  Future<bool> disconnectVPN() async {
    if (!_vpnConnection.value.isConnected || _vpnConnection.value.config == null) {
      return true;
    }

    try {
      _vpnConnection.value = VPNConnection(
        state: VPNState.disconnecting,
        config: _vpnConnection.value.config,
      );

      final response = await _apiService.disconnectVPN(_vpnConnection.value.config!.id);

      if (response.isSuccess) {
        _vpnConnection.value = VPNConnection(state: VPNState.disconnected);

        // Remove from configs
        _configs.removeWhere((c) => c.id == _vpnConnection.value.config?.id);

        // Stop monitoring
        _stopStatusMonitoring();

        return true;
      } else {
        _vpnConnection.value = VPNConnection(
          state: VPNState.error,
          config: _vpnConnection.value.config,
          errorMessage: response.message,
        );
        return false;
      }
    } catch (e) {
      _vpnConnection.value = VPNConnection(
        state: VPNState.error,
        config: _vpnConnection.value.config,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  // Force disconnect
  Future<bool> forceDisconnectVPN() async {
    if (!_vpnConnection.value.isConnected || _vpnConnection.value.config == null) {
      return true;
    }

    try {
      final response = await _apiService.forceDisconnectVPN(_vpnConnection.value.config!.id);

      if (response.isSuccess) {
        _vpnConnection.value = VPNConnection(state: VPNState.disconnected);
        _configs.removeWhere((c) => c.id == _vpnConnection.value.config?.id);
        _stopStatusMonitoring();
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
    if (!_vpnConnection.value.isConnected || _vpnConnection.value.config == null) {
      return;
    }

    try {
      final response = await _apiService.getVPNStatus(_vpnConnection.value.config!.id);

      if (response.isSuccess && response.data != null) {
        _vpnConnection.value = VPNConnection(
          state: VPNState.connected,
          config: _vpnConnection.value.config,
          status: response.data!,
        );
      }
    } catch (e) {
      print('Failed to update VPN status: $e');
    }
  }

  // Get VPN config file
  Future<VPNConfigFile?> getConfigFile(VPNConfig config) async {
    try {
      final response = await _apiService.downloadVPNConfig(config.id);
      if (response.isSuccess && response.data != null) {
        return response.data!;
      }
      return null;
    } catch (e) {
      print('Failed to get config file: $e');
      return null;
    }
  }

  // Clear errors
  void clearServersError() {
    _serversError.value = '';
  }

  void clearConfigsError() {
    _configsError.value = '';
  }

  void clearVPNError() {
    if (_vpnConnection.value.hasError) {
      _vpnConnection.value = VPNConnection(state: VPNState.disconnected);
    }
  }

  // Reset VPN state
  void resetVPNState() {
    _vpnConnection.value = VPNConnection(state: VPNState.disconnected);
    _stopStatusMonitoring();
  }

  // Get error message
  String _getErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }
}