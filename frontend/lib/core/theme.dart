// lib/core/theme.dart
// ─────────────────────────────────────────────────────────────────────────────
// App-wide design system: colors, typography, component themes.
// Dark-mode first. Uses the "Inter" font via google_fonts.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Color Palette ─────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bgBase      = Color(0xFF0A0E1A);  // near-black navy
  static const Color bgSurface   = Color(0xFF111827);  // card/panel background
  static const Color bgElevated  = Color(0xFF1C2537);  // elevated card
  static const Color bgBorder    = Color(0xFF2D3748);  // subtle dividers

  // Brand accent — electric cyan
  static const Color accent      = Color(0xFF00D4FF);
  static const Color accentDark  = Color(0xFF0099BB);
  static const Color accentGlow  = Color(0x2600D4FF);  // 15% opacity glow

  // Secondary accent — vivid violet
  static const Color secondary   = Color(0xFF7C3AED);
  static const Color secondaryGlow = Color(0x267C3AED);

  // Semantic colors
  static const Color success     = Color(0xFF10B981);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color error       = Color(0xFFEF4444);
  static const Color info        = Color(0xFF3B82F6);

  // Text hierarchy
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // Graph node colors
  static const Color nodeSuspect  = Color(0xFFEF4444);  // red = suspect
  static const Color nodeContact  = Color(0xFF00D4FF);  // cyan = contact
  static const Color nodeUnknown  = Color(0xFF475569);  // grey = no SDR
}

// ── Typography ─────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
    letterSpacing: 0.4,
  );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
}

// ── Theme Data ─────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.accent,
        secondary: AppColors.secondary,
        surface:   AppColors.bgSurface,
        error:     AppColors.error,
        onPrimary: AppColors.bgBase,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.bgElevated,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: AppTextStyles.displayLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        titleLarge: AppTextStyles.titleLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineMedium,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        shape: const Border(
          bottom: BorderSide(color: AppColors.bgBorder, width: 1),
        ),
      ),

      // Navigation Rail (desktop)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.bgSurface,
        selectedIconTheme: const IconThemeData(color: AppColors.accent, size: 24),
        unselectedIconTheme: const IconThemeData(color: AppColors.textMuted, size: 22),
        selectedLabelTextStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.accent),
        unselectedLabelTextStyle: AppTextStyles.bodySmall,
        indicatorColor: AppColors.accentGlow,
        elevation: 0,
      ),

      // Bottom Navigation Bar (mobile)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgSurface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.accent),
        unselectedLabelStyle: AppTextStyles.bodySmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Input / search fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: AppTextStyles.bodyMedium,
        labelStyle: AppTextStyles.bodyMedium,
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bgBase,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedColor: AppColors.accentGlow,
        labelStyle: AppTextStyles.bodySmall,
        side: const BorderSide(color: AppColors.bgBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.bgBorder,
        thickness: 1,
        space: 1,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bgBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgSurface,
        modalBackgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.bgBorder,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgElevated,
        contentTextStyle: AppTextStyles.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
