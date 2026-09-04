import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'services/database_service.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';
import 'services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();

  final dbService = DatabaseService();
  final apiService = ApiService();
  SyncService.instance.init(dbService, apiService);

  runApp(MyApp(dbService: dbService, apiService: apiService));
}

class MyApp extends StatelessWidget {
  final DatabaseService? dbService;
  final ApiService? apiService;

  const MyApp({super.key, this.dbService, this.apiService});

  @override
  Widget build(BuildContext context) {
    final db = dbService ?? DatabaseService();
    final api = apiService ?? ApiService();

    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],

      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Sahabat Sakinah Asset',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

