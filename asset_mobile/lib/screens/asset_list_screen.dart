import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../models/asset.dart';
import 'asset_form_screen.dart';
import 'simple_scanner_screen.dart';

enum SortOption { idAsc, idDesc, type, location, status, dateNewest, dateOldest }

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({super.key});

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  List<Asset> _filteredAssets = [];
  bool _isLoading = true;
  bool _isSyncingServer = false;
  String _filterStatus = 'ALL';
  SortOption _currentSort = SortOption.idAsc;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    // Silent auto-sync dari server saat membuka tab Assets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndRefresh(silent: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncAndRefresh({bool silent = false}) async {
    if (_isSyncingServer) return;
    if (!silent && mounted) {
      setState(() => _isSyncingServer = true);
    }

    final dbService = context.read<DatabaseService>();
    try {
      final remoteAssets = await ApiService.getAssets();
      await dbService.syncAssets(remoteAssets);
    } catch (e) {
      // Offline fallback: tetap membaca lokal SQLite
    } finally {
      if (mounted) {
        setState(() => _isSyncingServer = false);
      }
    }
    await _loadAssets();
  }

  Future<void> _loadAssets() async {
    final dbService = context.read<DatabaseService>();
    final query = _searchController.text.trim();
    final assets = await dbService.getAllAssets(
      query: query.isNotEmpty ? query : null,
      statusFilter: _filterStatus,
      limit: 150,
    );
    if (mounted) {
      setState(() {
        _filteredAssets = assets;
        _sortAssets();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _loadAssets();
    });
  }

  void _sortAssets() {
    _filteredAssets.sort((a, b) {
      switch (_currentSort) {
        case SortOption.idAsc:
          return a.id.compareTo(b.id);
        case SortOption.idDesc:
          return b.id.compareTo(a.id);
        case SortOption.type:
          return a.type.compareTo(b.type);
        case SortOption.location:
          return a.location.compareTo(b.location);
        case SortOption.status:
          return a.status.compareTo(b.status);
        case SortOption.dateNewest:
          return (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0));
        case SortOption.dateOldest:
          return (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0));
      }
    });
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleScannerScreen()),
    );
    if (result != null && result is String) {
      if (mounted) {
        setState(() {
          _searchController.text = result;
        });
        _loadAssets();
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
        title: Text('Daftar Aset IT', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor)),
        backgroundColor: themeProvider.scaffoldBackgroundColor,
        elevation: 0,
        systemOverlayStyle: themeProvider.systemOverlayStyle,
        actions: [
          PopupMenuButton<SortOption>(
            icon: Icon(Icons.sort, color: themeProvider.primaryTextColor),
            color: themeProvider.cardBackgroundColor,
            onSelected: (SortOption result) {
              setState(() {
                _currentSort = result;
                _sortAssets();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              PopupMenuItem<SortOption>(
                value: SortOption.idAsc,
                child: Text('ID (A-Z)', style: TextStyle(color: themeProvider.primaryTextColor)),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.idDesc,
                child: Text('ID (Z-A)', style: TextStyle(color: themeProvider.primaryTextColor)),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.type,
                child: Text('Tipe', style: TextStyle(color: themeProvider.primaryTextColor)),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.location,
                child: Text('Lokasi', style: TextStyle(color: themeProvider.primaryTextColor)),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.status,
                child: Text('Status', style: TextStyle(color: themeProvider.primaryTextColor)),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.dateNewest,
                child: Text('Terbaru', style: TextStyle(color: themeProvider.primaryTextColor)),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.dateOldest,
                child: Text('Terlama', style: TextStyle(color: themeProvider.primaryTextColor)),
              ),
            ],
          ),
          IconButton(
            icon: _isSyncingServer 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                : Icon(Icons.refresh_rounded, color: themeProvider.primaryTextColor),
            tooltip: 'Tarik Data Terbaru dari Server',
            onPressed: _isSyncingServer ? null : () => _syncAndRefresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: themeProvider.primaryTextColor),
                  decoration: InputDecoration(
                    hintText: 'Cari aset (ID, Stiker GA, Tipe, Lokasi)...',
                    hintStyle: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: themeProvider.secondaryTextColor),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
                      onPressed: _scanBarcode,
                    ),
                    filled: true,
                    fillColor: themeProvider.cardBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeProvider.borderStrokeColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeProvider.borderStrokeColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tersedia', 'AVAILABLE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Terpakai', 'IN_USE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rusak', 'BROKEN'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Asset List with Pull-to-Refresh
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : RefreshIndicator(
                    onRefresh: () => _syncAndRefresh(),
                    color: Colors.blueAccent,
                    backgroundColor: themeProvider.cardBackgroundColor,
                    child: _filteredAssets.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off_rounded, color: themeProvider.secondaryTextColor, size: 48),
                                    const SizedBox(height: 12),
                                    Text('Aset tidak ditemukan', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 15)),
                                    const SizedBox(height: 6),
                                    Text('Tarik ke bawah untuk memuat ulang dari server', style: TextStyle(color: themeProvider.secondaryTextColor.withValues(alpha: 0.6), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _filteredAssets.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemBuilder: (context, index) {
                              final asset = _filteredAssets[index];
                              final statusColor = _getStatusColor(asset.status);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: themeProvider.cardBackgroundColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: asset.isSynced ? themeProvider.borderStrokeColor : Colors.amber.withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                child: Icon(
                                  _getTypeIcon(asset.type),
                                  color: statusColor,
                                  size: 22,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    asset.id,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor, fontSize: 15),
                                  ),
                                  if (asset.legacyInvCode != null && asset.legacyInvCode!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        asset.legacyInvCode!,
                                        style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${asset.type} • ${asset.location}',
                                  style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      asset.status,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded, color: themeProvider.secondaryTextColor),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AssetFormScreen(asset: asset),
                                  ),
                                );
                                _loadAssets();
                              },
                            ),
                          );
                        },
                      ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AssetFormScreen()),
          );
          _loadAssets();
        },
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final themeProvider = context.watch<ThemeProvider>();
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : themeProvider.primaryTextColor, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _isLoading = true;
        });
        _loadAssets();
      },
      selectedColor: Colors.blueAccent,
      backgroundColor: themeProvider.cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? Colors.blueAccent : themeProvider.borderStrokeColor),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE': return const Color(0xFF4ADE80); // Green 400
      case 'IN_USE': return const Color(0xFFFACC15); // Yellow 400
      case 'BROKEN': return const Color(0xFFF87171); // Red 400
      case 'REPAIRING': return const Color(0xFFFB923C); // Orange 400
      case 'GHOST': return const Color(0xFFA78BFA); // Violet 400
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PC':
      case 'CPU': return Icons.computer;
      case 'LAPTOP':
      case 'LAP': return Icons.laptop;
      case 'MONITOR':
      case 'MN': return Icons.monitor;
      case 'KEYBOARD':
      case 'KB': return Icons.keyboard;
      case 'MOUSE':
      case 'MS': return Icons.mouse;
      case 'HEADSET':
      case 'HD':
      case 'HS': return Icons.headset;
      default: return Icons.devices;
    }
  }
}
