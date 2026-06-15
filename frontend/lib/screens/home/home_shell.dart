// lib/screens/home/home_shell.dart
// ─────────────────────────────────────────────────────────────────────────────
// Adaptive navigation shell:
//   Mobile  → BottomNavigationBar
//   Desktop → NavigationRail (extended)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../main.dart' show authProvider;

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _destinations = [
    _NavItem(icon: Icons.upload_file_outlined, activeIcon: Icons.upload_file, label: AppStrings.navIngest, route: AppRoutes.ingest),
    _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search, label: AppStrings.navSearch, route: AppRoutes.search),
    _NavItem(icon: Icons.hub_outlined, activeIcon: Icons.hub, label: AppStrings.navGraph, route: AppRoutes.graph),
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: AppStrings.navMap, route: AppRoutes.map),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _destinations.indexWhere((d) => location.startsWith(d.route));
    return idx < 0 ? 0 : idx;
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Responsive.isMobile(context);
    final index = _currentIndex(context);

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Telecom Analyzer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () => _logout(context, ref),
            ),
          ],
        ),
        body: child,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.bgBorder)),
          ),
          child: BottomNavigationBar(
            currentIndex: index,
            onTap: (i) => context.go(_destinations[i].route),
            items: _destinations.map((d) => BottomNavigationBarItem(
              icon: Icon(d.icon),
              activeIcon: Icon(d.activeIcon),
              label: d.label,
            )).toList(),
          ),
        ),
      );
    }

    // Desktop / tablet layout with NavigationRail
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: Responsive.isDesktop(context),
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(_destinations[i].route),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: _AppLogo(compact: !Responsive.isDesktop(context)),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.textMuted),
                    tooltip: 'Sign out',
                    onPressed: () => _logout(context, ref),
                  ),
                ),
              ),
            ),
            destinations: _destinations.map((d) => NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.activeIcon),
              label: Text(d.label),
            )).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.cell_tower, color: Colors.white, size: 20),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Telecom', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
              Text('Analyzer', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.route});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}
