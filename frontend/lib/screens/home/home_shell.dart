// lib/screens/home/home_shell.dart
// Adaptive navigation shell for Windows desktop (NavigationRail).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../providers/data_store.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index   = _currentIndex(context);
    final counts  = ref.watch(dbCountsProvider);
    final total   = counts.when(data: (c) => c.values.fold(0, (a, b) => a + b), loading: () => 0, error: (_, __) => 0);

    // Always use NavigationRail on Windows
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (total > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accentGlow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$total records',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontSize: 10),
                          ),
                        ),
                      const Icon(Icons.storage, color: AppColors.textMuted, size: 18),
                    ],
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
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.cell_tower, color: Colors.white, size: 20),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Telecom', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
            Text('Analyzer', style: AppTextStyles.bodySmall),
          ]),
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
