import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../services/mistral_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor)),
        backgroundColor: themeProvider.scaffoldBackgroundColor,
        elevation: 0,
        systemOverlayStyle: themeProvider.systemOverlayStyle,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // USER PROFILE CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: themeProvider.borderStrokeColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blueAccent.withOpacity(0.15),
                  child: const Icon(Icons.person, size: 30, color: Colors.blueAccent),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tim IT Support', style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('admin@pt-sss.co.id', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // DARK MODE TOGGLE SWITCH
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: themeProvider.cardBackgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeProvider.borderStrokeColor),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
              title: Text(
                'Tampilan Mode Gelap (Dark Mode)',
                style: TextStyle(
                  color: themeProvider.primaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                isDark ? 'Tema Gelap Slate (Aktif)' : 'Tema Terang Clean (Aktif)',
                style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12),
              ),
              value: isDark,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                themeProvider.toggleTheme(val);
              },
            ),
          ),

          // SERVER CONFIGURATION
          _buildSettingsItem(
            context,
            icon: Icons.cloud_outlined,
            title: 'Alamat Server Backend (IP / Domain)',
            subtitle: ApiService.serverHostDisplay,
            onTap: () => _updateIp(context),
          ),
          // MISTRAL AI CONFIGURATION
          _buildSettingsItem(
            context,
            icon: Icons.smart_toy_rounded,
            title: 'Mistral AI Vision (OCR)',
            subtitle: 'Konfigurasi API Key untuk scan tulisan tangan spidol',
            onTap: () => _updateMistralKey(context),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.sync,
            title: 'Sinkronisasi Data Manual',
            subtitle: 'Kirim data lokal yang belum tersimpan ke server',
            onTap: () => _syncData(context),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.delete_outline,
            title: 'Hapus Data Lokal',
            subtitle: 'Hapus aset yang tersimpan sementara di HP',
            onTap: () => _clearData(context),
            isDestructive: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: themeProvider.borderStrokeColor),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.info_outline,
            title: 'Tentang Aplikasi',
            subtitle: 'Aset Inventaris IT v1.1.0',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.cardBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeProvider.borderStrokeColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive ? Colors.redAccent.withOpacity(0.15) : Colors.blueAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.redAccent : Colors.blueAccent,
            size: 22,
          ),
        ),
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : themeProvider.primaryTextColor, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12)) : null,
        onTap: onTap,
        trailing: Icon(Icons.chevron_right_rounded, color: themeProvider.secondaryTextColor),
      ),
    );
  }

  Future<void> _updateIp(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();
    final controller = TextEditingController(text: ApiService.serverHostDisplay);
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: themeProvider.cardBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.cloud_sync_rounded, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Alamat Server Backend',
                  style: TextStyle(color: themeProvider.primaryTextColor, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bisa diisi dengan Alamat IP Lokal ataupun Nama Domain publik (HTTP / HTTPS).',
                    style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'IP atau Domain Backend',
                      labelStyle: TextStyle(color: themeProvider.secondaryTextColor),
                      hintText: 'Misal: 199.166.25.5 atau api.domain.com',
                      hintStyle: TextStyle(color: themeProvider.secondaryTextColor.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: themeProvider.inputBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Format yang didukung:\n• Domain: backend.domain.com atau https://api.domain.com\n• IP Lokal: 199.166.25.5 (otomatis port 8080)\n• Custom Port: 199.166.25.5:9000 atau domain.com:8080',
                    style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (testResult != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: (testSuccess == true ? Colors.green : Colors.red).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: testSuccess == true ? Colors.green : Colors.red),
                      ),
                      child: Row(
                        children: [
                          Icon(testSuccess == true ? Icons.check_circle : Icons.error, color: testSuccess == true ? Colors.green : Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testResult!,
                              style: TextStyle(color: testSuccess == true ? Colors.green : Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isTesting ? null : () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        setDialogState(() {
                          isTesting = true;
                          testResult = null;
                        });
                        final ok = await ApiService.testConnection(text);
                        setDialogState(() {
                          isTesting = false;
                          testSuccess = ok;
                          testResult = ok
                              ? 'Terhubung! (HTTP 200 OK)'
                              : 'Gagal terhubung. Periksa domain/IP atau pastikan server aktif.';
                        });
                      },
                      icon: isTesting 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering, size: 16),
                      label: Text(isTesting ? 'Menguji...' : 'Tes Koneksi Server'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal', style: TextStyle(color: themeProvider.secondaryTextColor)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    await ApiService.updateServerAddress(text);
                    if (mounted) {
                      setState(() {});
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alamat server berhasil diperbarui ke: ${ApiService.serverHostDisplay}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateMistralKey(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();
    final currentKey = await MistralService.getApiKey();
    final controller = TextEditingController(text: currentKey);
    bool isTesting = false;
    String? testResult;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: themeProvider.cardBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, color: Colors.purpleAccent),
                const SizedBox(width: 8),
                Text('Mistral AI OCR', style: TextStyle(color: themeProvider.primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Key Mistral digunakan untuk memproses foto tulisan tangan spidol dengan model Pixtral Vision.',
                  style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Mistral API Key',
                    labelStyle: TextStyle(color: themeProvider.secondaryTextColor),
                    filled: true,
                    fillColor: themeProvider.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                  ),
                ),
                const SizedBox(height: 12),
                if (testResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: testResult!.contains('Berhasil') ? Colors.green.shade900 : Colors.red.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      testResult!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: isTesting
                      ? null
                      : () async {
                          setDialogState(() {
                            isTesting = true;
                            testResult = null;
                          });
                          final ok = await MistralService.testConnection(controller.text.trim());
                          setDialogState(() {
                            isTesting = false;
                            testResult = ok ? '✓ Berhasil terhubung ke Mistral AI' : '✗ Gagal terhubung / API Key tidak valid';
                          });
                        },
                  icon: isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent))
                      : const Icon(Icons.bolt, color: Colors.purpleAccent, size: 18),
                  label: const Text('Uji Koneksi API', style: TextStyle(color: Colors.purpleAccent)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: themeProvider.secondaryTextColor))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                onPressed: () async {
                  final key = controller.text.trim();
                  if (key.isNotEmpty) {
                    await MistralService.saveApiKey(key);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('API Key Mistral berhasil disimpan!'), backgroundColor: Colors.green),
                    );
                  }
                },
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _syncData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    try {
      final dbService = context.read<DatabaseService>();
      final apiService = context.read<ApiService>();

      final unsyncedAssets = await dbService.getUnsyncedAssets();
      int successCount = 0;

      for (var asset in unsyncedAssets) {
        try {
          await apiService.createAsset(asset);
          await dbService.markAsSynced(asset.id);
          successCount++;
        } catch (e) {
          print('Failed to sync ${asset.id}: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Berhasil menyinkronkan $successCount aset ke server!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal sinkronisasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearData(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.cardBackgroundColor,
        title: Text('Hapus Data Lokal', style: TextStyle(color: themeProvider.primaryTextColor)),
        content: Text('Apakah Anda yakin? Seluruh data yang disimpan sementara di HP akan dihapus.', style: TextStyle(color: themeProvider.secondaryTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: TextStyle(color: themeProvider.secondaryTextColor))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur akan segera hadir')),
      );
    }
  }
}
