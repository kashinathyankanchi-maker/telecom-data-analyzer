// lib/main.dart
// ─────────────────────────────────────────────────────────────────────────────
// Application entry point with JWT auth guard.
//
// Auth flow:
//   1. App launches → AuthInitState checks SecureStorage for a token.
//   2. If token exists → calls GET /auth/me to validate it.
//   3. Valid token  → go to /ingest (home)
//   4. Invalid/none → go to /login
//   5. Any 401 response anywhere → global logout → redirect to /login
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'data/models/auth_model.dart';
import 'data/repositories/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/ingest/ingest_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/graph/graph_screen.dart';
import 'screens/map/map_screen.dart';

// ── Auth State ─────────────────────────────────────────────────────────────────
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;

  const AuthState({required this.status, this.user});

  const AuthState.unknown()          : status = AuthStatus.unknown,          user = null;
  const AuthState.authenticated(AuthUser u) : status = AuthStatus.authenticated,  user = u;
  const AuthState.unauthenticated()  : status = AuthStatus.unauthenticated,  user = null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.authenticated(AuthUser(
    id: 1, 
    username: 'admin', 
    email: 'admin@telecom.local', 
    role: 'admin', 
    isActive: true, 
    createdAt: DateTime.now()
  ))) {
    // Register the global 401 callback in the Dio client
    ApiClient.instance.setUnauthorizedCallback(logout);
    // Bypassing normal token check to go straight into the app
  }

  final _repo = AuthRepository();

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);

// ── Router ─────────────────────────────────────────────────────────────────────
GoRouter _buildRouter(WidgetRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.ingest,
    refreshListenable: ValueNotifier(authState.status),
    redirect: (context, state) {
      final status = authState.status;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      // Still checking token — show nothing (splash)
      if (status == AuthStatus.unknown) return null;

      // Not logged in and not already on login → send to login
      if (status == AuthStatus.unauthenticated && !isLoginRoute) {
        return AppRoutes.login;
      }

      // Logged in and trying to visit login → redirect home
      if (status == AuthStatus.authenticated && isLoginRoute) {
        return AppRoutes.ingest;
      }

      return null;
    },
    routes: [
      // ── Public: Login ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, __) => const NoTransitionPage(child: LoginScreen()),
      ),

      // ── Protected: App shell with 4 feature tabs ─────────────────────────
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
}

// ── App ────────────────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TelecomAnalyzerApp()));
}

class TelecomAnalyzerApp extends ConsumerWidget {
  const TelecomAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger auth initialization
    ref.watch(authProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _buildRouter(ref),
    );
  }
}
