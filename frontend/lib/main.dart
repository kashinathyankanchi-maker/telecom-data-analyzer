// lib/main.dart
// Windows-only Telecom Data Analyzer
// No backend, no authentication — all data is processed locally via SQLite.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/database.dart';
import 'core/theme.dart';
import 'screens/home/home_shell.dart';
import 'screens/ingest/ingest_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/graph/graph_screen.dart';
import 'screens/map/map_screen.dart';

// ── Router ─────────────────────────────────────────────────────────────────────
final _router = GoRouter(
  initialLocation: AppRoutes.ingest,
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.ingest,
          pageBuilder: (_, __) => const NoTransitionPage(child: IngestScreen()),
        ),
        GoRoute(
          path: AppRoutes.search,
          pageBuilder: (_, __) => const NoTransitionPage(child: SearchScreen()),
        ),
        GoRoute(
          path: AppRoutes.graph,
          pageBuilder: (_, __) => const NoTransitionPage(child: GraphScreen()),
        ),
        GoRoute(
          path: AppRoutes.map,
          pageBuilder: (_, __) => const NoTransitionPage(child: MapScreen()),
        ),
      ],
    ),
  ],
);

// ── App ────────────────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize SQLite FFI for Windows
  AppDatabase.initFfi();
  runApp(const ProviderScope(child: TelecomAnalyzerApp()));
}

class TelecomAnalyzerApp extends StatelessWidget {
  const TelecomAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
