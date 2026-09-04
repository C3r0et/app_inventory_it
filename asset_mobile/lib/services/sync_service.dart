import 'dart:async';
import 'database_service.dart';
import 'api_service.dart';
import '../models/asset.dart';

/// Lightweight background synchronization service.
/// Automatically flushes offline-saved assets to the server when online.
class SyncService {
  static final SyncService instance = SyncService._internal();

  DatabaseService? _dbService;
  ApiService? _apiService;
  Timer? _timer;
  bool _isSyncing = false;

  SyncService._internal();

  void init(DatabaseService dbService, ApiService apiService) {
    _dbService = dbService;
    _apiService = apiService;
    start();
  }

  void start() {
    _timer?.cancel();
    // Check every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncPending();
    });
    // Trigger immediate check on start
    syncPending();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<int> syncPending() async {
    if (_isSyncing) return 0;
    if (_dbService == null || _apiService == null) return 0;

    try {
      // 1. Fast local SQLite query (takes ~1ms, 0 network usage)
      final unsynced = await _dbService!.getUnsyncedAssets();
      if (unsynced.isEmpty) return 0;

      // 2. Only if unsynced items exist, verify if server is reachable
      final isOnline = await ApiService.testConnection();
      if (!isOnline) return 0;

      _isSyncing = true;
      int successCount = 0;

      for (var asset in unsynced) {
        try {
          Asset syncedAsset;
          try {
            syncedAsset = await _apiService!.updateAsset(asset);
          } catch (_) {
            syncedAsset = await _apiService!.createAsset(asset);
          }

          await _dbService!.markAsSynced(asset.id, syncedAsset.imagePath);
          successCount++;
        } catch (e) {
          // Keep is_synced = 0 to retry in next cycle
          continue;
        }
      }


      return successCount;
    } catch (_) {
      return 0;
    } finally {
      _isSyncing = false;
    }
  }
}
