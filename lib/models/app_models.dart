class ApiResponse<T> {
  final String status;
  final String message;
  final T? data;
  final List<String>? errors;
  final String timestamp;
  final String? code;
  final Map<String, dynamic>? details;

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
    this.errors,
    required this.timestamp,
    this.code,
    this.details,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic)? fromJsonT) {
    return ApiResponse<T>(
      status: json['status'] ?? 'error',
      message: json['message'] ?? 'Unknown error',
      data: json['data'] != null && fromJsonT != null ? fromJsonT(json['data']) : json['data'],
      errors: json['errors'] != null ? List<String>.from(json['errors']) : null,
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      code: json['code'],
      details: json['details'],
    );
  }

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';
  bool get isWarning => status == 'warning';
  bool get isValidationError => code == 'VALIDATION_ERROR';
  bool get isAuthError => code == 'AUTH_ERROR';
  bool get isConflictError => code == 'RESOURCE_CONFLICT';
  bool get isNotFoundError => code == 'RESOURCE_NOT_FOUND';
}

class User {
  final int id;
  final String username;
  final String email;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.isActive,
    required this.isAdmin,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isActive: json['is_active'] ?? true,
      isAdmin: json['is_admin'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_active': isActive,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AuthData {
  final User user;
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  AuthData({
    required this.user,
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      user: User.fromJson(json['user']),
      accessToken: json['access_token'],
      tokenType: json['token_type'] ?? 'bearer',
      expiresIn: json['expires_in'] ?? 3600,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
    };
  }
}

class Server {
  final int id;
  final String name;
  final String location;
  final String endpoint;
  final int port;
  final bool isActive;
  final DateTime createdAt;
  final String? panelUrl;

  Server({
    required this.id,
    required this.name,
    required this.location,
    required this.endpoint,
    required this.port,
    required this.isActive,
    required this.createdAt,
    this.panelUrl,
  });

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      endpoint: json['endpoint'],
      port: json['port'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      panelUrl: json['panel_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'endpoint': endpoint,
      'port': port,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'panel_url': panelUrl,
    };
  }

  String get fullEndpoint => '$endpoint:$port';
}

class ServerHealth {
  final int serverId;
  final bool isHealthy;
  final double responseTime;
  final bool wireguardStatus;
  final int peerCount;
  final double lastCheck;
  final String? errorMessage;
  final String? panelUrl;

  ServerHealth({
    required this.serverId,
    required this.isHealthy,
    required this.responseTime,
    required this.wireguardStatus,
    required this.peerCount,
    required this.lastCheck,
    this.errorMessage,
    this.panelUrl,
  });

  factory ServerHealth.fromJson(Map<String, dynamic> json) {
    return ServerHealth(
      serverId: json['server_id'],
      isHealthy: json['is_healthy'] ?? false,
      responseTime: (json['response_time'] ?? 0).toDouble(),
      wireguardStatus: json['wireguard_status'] ?? false,
      peerCount: json['peer_count'] ?? 0,
      lastCheck: (json['last_check'] ?? 0).toDouble(),
      errorMessage: json['error_message'],
      panelUrl: json['panel_url'],
    );
  }

  String get statusText {
    if (isHealthy) return 'Healthy';
    if (errorMessage != null) return 'Issues detected';
    return 'Unhealthy';
  }

  String get responseTimeText {
    if (responseTime < 100) return 'Excellent (${responseTime.toInt()}ms)';
    if (responseTime < 200) return 'Good (${responseTime.toInt()}ms)';
    if (responseTime < 500) return 'Fair (${responseTime.toInt()}ms)';
    return 'Poor (${responseTime.toInt()}ms)';
  }
}

class VPNConfig {
  final int id;
  final int serverId;
  final String allocatedIp;
  final String configContent;
  final bool isActive;
  final DateTime createdAt;
  final Server server;

  VPNConfig({
    required this.id,
    required this.serverId,
    required this.allocatedIp,
    required this.configContent,
    required this.isActive,
    required this.createdAt,
    required this.server,
  });

  factory VPNConfig.fromJson(Map<String, dynamic> json) {
    return VPNConfig(
      id: json['id'],
      serverId: json['server_id'],
      allocatedIp: json['allocated_ip'],
      configContent: json['config_content'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      server: Server.fromJson(json['server']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'allocated_ip': allocatedIp,
      'config_content': configContent,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'server': server.toJson(),
    };
  }
}

class VPNConfigFile {
  final String configContent;
  final String qrCode;
  final Map<String, dynamic> serverInfo;
  final Map<String, dynamic> connectionInfo;

  VPNConfigFile({
    required this.configContent,
    required this.qrCode,
    required this.serverInfo,
    required this.connectionInfo,
  });

  factory VPNConfigFile.fromJson(Map<String, dynamic> json) {
    return VPNConfigFile(
      configContent: json['config_content'],
      qrCode: json['qr_code'],
      serverInfo: Map<String, dynamic>.from(json['server_info'] ?? {}),
      connectionInfo: Map<String, dynamic>.from(json['connection_info'] ?? {}),
    );
  }
}

class VPNConnectionStatus {
  final int configId;
  final bool isConnected;
  final String allocatedIp;
  final int bytesSent;
  final int bytesReceived;
  final DateTime? lastHandshake;
  final String? endpoint;
  final DateTime? connectionTime;

  VPNConnectionStatus({
    required this.configId,
    required this.isConnected,
    required this.allocatedIp,
    required this.bytesSent,
    required this.bytesReceived,
    this.lastHandshake,
    this.endpoint,
    this.connectionTime,
  });

  factory VPNConnectionStatus.fromJson(Map<String, dynamic> json) {
    return VPNConnectionStatus(
      configId: json['config_id'],
      isConnected: json['is_connected'] ?? false,
      allocatedIp: json['allocated_ip'],
      bytesSent: json['bytes_sent'] ?? 0,
      bytesReceived: json['bytes_received'] ?? 0,
      lastHandshake: json['last_handshake'] != null
          ? DateTime.parse(json['last_handshake'])
          : null,
      endpoint: json['endpoint'],
      connectionTime: json['connection_time'] != null
          ? DateTime.parse(json['connection_time'])
          : null,
    );
  }

  String get statusText {
    if (isConnected) return 'Connected';
    if (connectionTime != null) return 'Disconnected';
    return 'Not connected';
  }

  String get dataUsageText {
    final totalBytes = bytesSent + bytesReceived;
    if (totalBytes < 1024) return '${totalBytes}B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)}KB';
    if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  Duration? get connectionDuration {
    if (connectionTime == null) return null;
    return DateTime.now().difference(connectionTime!);
  }

  String get connectionDurationText {
    final duration = connectionDuration;
    if (duration == null) return 'Unknown';

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

enum VPNState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class VPNConnection {
  final VPNState state;
  final VPNConfig? config;
  final VPNConnectionStatus? status;
  final String? errorMessage;

  VPNConnection({
    required this.state,
    this.config,
    this.status,
    this.errorMessage,
  });

  bool get isConnected => state == VPNState.connected;
  bool get isConnecting => state == VPNState.connecting;
  bool get isDisconnected => state == VPNState.disconnected;
  bool get isDisconnecting => state == VPNState.disconnecting;
  bool get hasError => state == VPNState.error;
  bool get isActive => isConnected || isConnecting || isDisconnecting;
}

class PaginatedData<T> {
  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  PaginatedData({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  factory PaginatedData.fromJson(
      Map<String, dynamic> json,
      T Function(Map<String, dynamic>) fromJsonT
      ) {
    return PaginatedData<T>(
      items: (json['items'] as List)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      pages: json['pages'] ?? 0,
    );
  }

  bool get hasMore => page < pages;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}