import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Added import here
import '../services/database_service.dart';
import '../services/api_service.dart';
import 'asset_form_screen.dart';
import 'bulk_scan_screen.dart';

import '../services/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, int> _counts = {
    'TOTAL': 0,
    'AVAILABLE': 0,
    'IN_USE': 0,
    'BROKEN': 0,
  };
  bool _isLoading = true;
  bool _isOnline = false;
  bool _isSyncing = false;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Auto-sync on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkConnection();
      if (_isOnline) {
        _syncData(silent: true);
      }
    });

    // Background Sync every 60 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_isOnline && !_isSyncing) {
        _syncData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    try {
      final apiService = context.read<ApiService>();
      final online = await apiService.checkConnection();
      if (mounted) {
        setState(() {
          _isOnline = online;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    // Only show loading indicator on initial load
    if (_counts['TOTAL'] == 0) {
      setState(() => _isLoading = true);
    }
    
    try {
      final dbService = context.read<DatabaseService>();
      final counts = await dbService.getAssetCounts();
      
      if (mounted) {
        setState(() {
          _counts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncData({bool silent = false}) async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    final dbService = context.read<DatabaseService>();
    final apiService = context.read<ApiService>();

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing data...')),
      );
    }

    try {
      final unsyncedAssets = await dbService.getUnsyncedAssets();
      
      for (var asset in unsyncedAssets) {
        try {
          await apiService.createAsset(asset);
          await dbService.markAsSynced(asset.id);
        } catch (e) {
          print('Failed to sync ${asset.id}: $e');
        }
      } // End of push loop

      // 2. Pull from Server
      if (!silent) print('Fetching assets from server...');
      final remoteAssets = await ApiService.getAssets();
      if (!silent) print('Fetched ${remoteAssets.length} assets from server');
      
      await dbService.syncAssets(remoteAssets);
      if (!silent) print('Sync assets to local DB completed');
      
      await _loadDashboardData();
      if (!silent) print('Dashboard data reloaded');
      
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync completed. Fetched ${remoteAssets.length} assets.')),
        );
      }
    } catch (e) {
      if (mounted && !silent) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: themeProvider.systemOverlayStyle,
        title: Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                if (!_isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Text(
                      'OFFLINE MODE',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Icon(
                  _isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: _isOnline ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFFA855F7)],
                        ).createShader(bounds),
                        child: const Text(
                          'IT Asset Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time Inventory Overview',
                        style: TextStyle(
                          fontSize: 13,
                          color: themeProvider.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Summary Cards Grid (Slate 800 + Slate 700 border)
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  _buildSummaryCard(
                    context,
                    title: 'Total Assets',
                    count: _counts['TOTAL'] ?? 0,
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF60A5FA), // Blue 400
                    subtitle: 'Semua unit tercatat',
                  ),
                  _buildSummaryCard(
                    context,
                    title: 'Available',
                    count: _counts['AVAILABLE'] ?? 0,
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF4ADE80), // Green 400
                    subtitle: 'Siap digunakan',
                  ),
                  _buildSummaryCard(
                    context,
                    title: 'In Use',
                    count: _counts['IN_USE'] ?? 0,
                    icon: Icons.person_rounded,
                    color: const Color(0xFFFACC15), // Yellow 400
                    subtitle: 'Sedang terpakai',
                  ),
                  _buildSummaryCard(
                    context,
                    title: 'Broken / Rusak',
                    count: _counts['BROKEN'] ?? 0,
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFF87171), // Red 400
                    subtitle: 'Perlu penanganan',
                  ),
                  _buildSummaryCard(
                    context,
                    title: 'Aset Lt. 2',
                    count: _counts['FLOOR_2'] ?? 0,
                    icon: Icons.apartment_rounded,
                    color: const Color(0xFF38BDF8), // Sky 400
                    subtitle: 'Area Lantai 2',
                  ),
                  _buildSummaryCard(
                    context,
                    title: 'Aset Lt. 3',
                    count: _counts['FLOOR_3'] ?? 0,
                    icon: Icons.apartment_rounded,
                    color: const Color(0xFFA78BFA), // Violet 400
                    subtitle: 'Area Lantai 3',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.primaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context,
                      icon: Icons.add_rounded,
                      label: 'Tambah Aset',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AssetFormScreen()),
                        ).then((_) => _loadDashboardData());
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      context,
                      icon: Icons.sync_rounded,
                      label: 'Sinkron Data',
                      color: const Color(0xFF10B981),
                      onTap: () => _syncData(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      context,
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Bulk Scan',
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const BulkScanScreen()),
                        ).then((_) => _loadDashboardData());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderStrokeColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.secondaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: themeProvider.secondaryTextColor.withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final themeProvider = context.watch<ThemeProvider>();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: themeProvider.cardBackgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: themeProvider.borderStrokeColor, width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: themeProvider.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
