// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/auth_controller.dart';
import '../../controller/vpn_controller.dart';
import '../../core/theme/app_theme.dart';
// import '../../controllers/auth_controller.dart';
// import '../../controllers/vpn_controller.dart';
import '../../models/app_models.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthController _authController = Get.find<AuthController>();
  final VPNController _vpnController = Get.find<VPNController>();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Load initial data
    _loadInitialData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _vpnController.loadServers(),
      _vpnController.loadConfigs(),
    ]);
  }

  void _handleLogout() async {
    await _authController.logout();
    Get.offAllNamed(AppRoutes.login);
  }

  void _startPulseAnimation() {
    _pulseController.repeat(reverse: true);
  }

  void _stopPulseAnimation() {
    _pulseController.stop();
    _pulseController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInitialData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),

                const SizedBox(height: 32),

                // VPN Connection Status
                _buildVPNStatus(),

                const SizedBox(height: 32),

                // Quick Actions
                _buildQuickActions(),

                const SizedBox(height: 32),

                // Server List
                _buildServerList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() {
      final user = _authController.user;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.medium,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: AppColors.white,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey600,
                    ),
                  ),
                  Text(
                    user?.username ?? 'User',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey900,
                    ),
                  ),
                ],
              ),
            ),

            // Logout button
            IconButton(
              onPressed: _handleLogout,
              icon: const Icon(
                Icons.logout,
                color: AppColors.grey600,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVPNStatus() {
    return Obx(() {
      final vpnConnection = _vpnController.vpnConnection;
      final isConnected = vpnConnection.isConnected;
      final isConnecting = vpnConnection.isConnecting;

      // Control pulse animation based on connection state
      if (isConnecting && !_pulseController.isAnimating) {
        _startPulseAnimation();
      } else if (!isConnecting && _pulseController.isAnimating) {
        _stopPulseAnimation();
      }

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isConnected
              ? AppGradients.success
              : isConnecting
              ? LinearGradient(
              colors: [AppColors.connecting, AppColors.connecting.withOpacity(0.8)]
          )
              : LinearGradient(
              colors: [AppColors.grey300, AppColors.grey400]
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.medium,
        ),
        child: Column(
          children: [
            // Connection button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnecting ? _pulseAnimation.value : 1.0,
                  child: GestureDetector(
                    onTap: () => _handleVPNToggle(),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.large,
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.security
                            : isConnecting
                            ? Icons.sync
                            : Icons.security_outlined,
                        size: 50,
                        color: isConnected
                            ? AppColors.success
                            : isConnecting
                            ? AppColors.connecting
                            : AppColors.grey500,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Status text
            Text(
              _getStatusText(vpnConnection.state),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            // Connection info
            if (isConnected && vpnConnection.config != null)
              Text(
                'Connected to ${vpnConnection.config!.server.location}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.white.withOpacity(0.9),
                ),
              ),

            if (vpnConnection.hasError)
              Text(
                vpnConnection.errorMessage ?? 'Connection error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    });
  }

  Widget _buildQuickActions() {
    return Obx(() {
      return Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.refresh,
              title: 'Refresh',
              subtitle: 'Update servers',
              onTap: () => _loadInitialData(),
              isLoading: _vpnController.isLoadingServers,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: _buildActionCard(
              icon: Icons.speed,
              title: 'Speed Test',
              subtitle: 'Check connection',
              onTap: () {
                Get.snackbar(
                  'Speed Test',
                  'Feature coming soon!',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.small,
        ),
        child: Column(
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                icon,
                size: 24,
                color: AppColors.primary,
              ),

            const SizedBox(height: 12),

            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.grey900,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList() {
    return Obx(() {
      if (_vpnController.isLoadingServers) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (_vpnController.serversError.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load servers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _vpnController.serversError,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Retry',
                onPressed: () => _vpnController.loadServers(refresh: true),
                isOutlined: true,
                backgroundColor: AppColors.error,
                textColor: AppColors.error,
              ),
            ],
          ),
        );
      }

      final servers = _vpnController.servers;

      if (servers.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: AppColors.grey400,
              ),
              const SizedBox(height: 16),
              Text(
                'No servers available',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Servers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.grey900,
            ),
          ),

          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: servers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final server = servers[index];
              return _buildServerCard(server);
            },
          ),
        ],
      );
    });
  }

  Widget _buildServerCard(Server server) {
    return Obx(() {
      final health = _vpnController.getServerHealth(server.id);
      final isHealthLoading = _vpnController.isHealthCheckLoading(server.id);
      final currentConfig = _vpnController.vpnConnection.config;
      final isConnectedToThis = currentConfig?.serverId == server.id;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.small,
          border: isConnectedToThis
              ? Border.all(color: AppColors.success, width: 2)
              : null,
        ),
        child: Row(
          children: [
            // Server info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey900,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    server.location,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Health status
                  if (isHealthLoading)
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Checking...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    )
                  else if (health != null)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: health.isHealthy ? AppColors.success : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          health.responseTimeText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Connect button
            if (isConnectedToThis)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Connected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              CustomButton(
                text: 'Connect',
                onPressed: () => _connectToServer(server),
                isLoading: _vpnController.isConnecting,
                height: 36,
                width: 80,
              ),
          ],
        ),
      );
    });
  }

  String _getStatusText(VPNState state) {
    switch (state) {
      case VPNState.connected:
        return 'Connected';
      case VPNState.connecting:
        return 'Connecting...';
      case VPNState.disconnecting:
        return 'Disconnecting...';
      case VPNState.error:
        return 'Connection Failed';
      case VPNState.disconnected:
      default:
        return 'Disconnected';
    }
  }

  Future<void> _handleVPNToggle() async {
    if (_vpnController.isConnected) {
      await _vpnController.disconnectVPN();
    } else {
      // Show server selection if not connected
      _showServerSelection();
    }
  }

  void _showServerSelection() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Server',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _vpnController.servers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final server = _vpnController.servers[index];
                  return ListTile(
                    title: Text(server.name),
                    subtitle: Text(server.location),
                    onTap: () {
                      Get.back();
                      _connectToServer(server);
                    },
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToServer(Server server) async {
    final success = await _vpnController.connectToVPN(server);

    if (success) {
      Get.snackbar(
        'Success',
        'Connected to ${server.name}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.white,
      );
    } else {
      Get.snackbar(
        'Connection Failed',
        'Unable to connect to ${server.name}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    }
  }
}