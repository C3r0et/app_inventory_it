import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'scanner_screen.dart';
import 'asset_list_screen.dart';
import 'settings_screen.dart';
import 'rapid_scan_screen.dart';
import '../services/theme_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = [
    const HomeScreen(),        // 0: Dashboard
    const AssetListScreen(),   // 1: Assets
    const RapidScanScreen(),   // 2: Gudang
    const SettingsScreen(),    // 3: Settings
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    // Langsung berpindah ke tab tujuan tanpa animasi cepat melewati halaman perantara
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: themeProvider.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: themeProvider.scaffoldBackgroundColor,
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(),
          children: _screens,
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: themeProvider.borderStrokeColor, width: 1)),
        ),
        child: BottomAppBar(
          color: themeProvider.cardBackgroundColor,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          elevation: 0,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(context, icon: Icons.dashboard_rounded, label: 'Dashboard', index: 0),
                _buildTabItem(context, icon: Icons.inventory_2_rounded, label: 'Assets', index: 1),
                const SizedBox(width: 48), // Empty space for FAB
                _buildTabItem(context, icon: Icons.warehouse_rounded, label: 'Gudang', index: 2),
                _buildTabItem(context, icon: Icons.settings_rounded, label: 'Settings', index: 3),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScannerScreen()),
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildTabItem(BuildContext context, {required IconData icon, required String label, required int index}) {
    final themeProvider = context.watch<ThemeProvider>();
    final isSelected = _selectedIndex == index;
    final color = isSelected 
        ? (themeProvider.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
        : themeProvider.secondaryTextColor;
    
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
