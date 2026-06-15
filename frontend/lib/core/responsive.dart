// lib/core/responsive.dart
// ─────────────────────────────────────────────────────────────────────────────
// Layout breakpoint helpers.
// Mobile  < 600px  → BottomNavigationBar, Drawer filters, ModalBottomSheets
// Tablet  600–1199 → NavigationRail (compact)
// Desktop ≥ 1200px → NavigationRail (extended), persistent side panels
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/widgets.dart';

enum ScreenSize { mobile, tablet, desktop }

class Responsive {
  Responsive._();

  static const double mobileBreak  = 600;
  static const double desktopBreak = 1200;

  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreak)  return ScreenSize.mobile;
    if (width < desktopBreak) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  static bool isMobile(BuildContext context)  => of(context) == ScreenSize.mobile;
  static bool isTablet(BuildContext context)  => of(context) == ScreenSize.tablet;
  static bool isDesktop(BuildContext context) => of(context) == ScreenSize.desktop;

  /// Returns true when NavigationRail should be shown instead of BottomNav.
  static bool showNavRail(BuildContext context) => !isMobile(context);

  /// Returns true when side panels (search filters, details) should be persistent.
  static bool showPersistentPanels(BuildContext context) => isDesktop(context);

  /// Padding that scales with screen width.
  static EdgeInsets pagePadding(BuildContext context) {
    return switch (of(context)) {
      ScreenSize.mobile  => const EdgeInsets.all(16),
      ScreenSize.tablet  => const EdgeInsets.all(24),
      ScreenSize.desktop => const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
    };
  }

  /// Maximum content width to prevent lines being too long on ultra-wide screens.
  static double maxContentWidth(BuildContext context) {
    return switch (of(context)) {
      ScreenSize.mobile  => double.infinity,
      ScreenSize.tablet  => 800,
      ScreenSize.desktop => 1200,
    };
  }
}

/// Convenience widget: builds different layouts based on screen size.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return switch (Responsive.of(context)) {
      ScreenSize.desktop => desktop ?? tablet ?? mobile,
      ScreenSize.tablet  => tablet ?? mobile,
      ScreenSize.mobile  => mobile,
    };
  }
}
