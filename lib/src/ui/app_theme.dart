import 'package:flutter/material.dart';

// ---------- Palette ----------

class AppColors {
  // Backgrounds
  static const bg = Color(0xFF0B0D14);
  static const surface = Color(0xFF131624);
  static const surfaceElevated = Color(0xFF1A2033);
  static const surfaceHighlight = Color(0xFF222840);

  // Primary — blue
  static const primary = Color(0xFF3B82F6);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDim = Color(0xFF1E3A8A);

  // Accent — warm amber
  static const accent = Color(0xFFF59E0B);
  static const accentLight = Color(0xFFFBBF24);

  // Secondary — teal
  static const teal = Color(0xFF14B8A6);
  static const tealDim = Color(0xFF0D9488);

  // Text
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

  // Status
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Borders
  static const border = Color(0xFF2D3655);
  static const borderLight = Color(0xFF3D4A6A);

  // Dialogue box
  static const dialogueBg = Color(0xF0080E1C);
  static const dialogueBorder = Color(0xFF2A3D6A);
}

// ---------- Theme ----------

ThemeData buildAppTheme() {
  final cs = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryDim,
    onPrimaryContainer: AppColors.primaryLight,
    secondary: AppColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF0D4040),
    onSecondaryContainer: AppColors.teal,
    tertiary: AppColors.accent,
    onTertiary: const Color(0xFF1C0E00),
    tertiaryContainer: const Color(0xFF4A2E00),
    onTertiaryContainer: AppColors.accentLight,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: const Color(0xFF4A1010),
    onErrorContainer: const Color(0xFFFFB4B4),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceHighlight,
    outline: AppColors.border,
    outlineVariant: AppColors.borderLight,
    shadow: Colors.black,
    scrim: Colors.black87,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.bg,
    inversePrimary: AppColors.primaryDim,
    surfaceTint: AppColors.primary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: AppColors.bg,
    cardColor: AppColors.surfaceElevated,
    dividerColor: AppColors.border,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    ),

    // Tabs
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.border,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 13),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHighlight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),

    // Dropdown
    dropdownMenuTheme: const DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHighlight,
      ),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.primaryDim
              : AppColors.surfaceHighlight),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHighlight,
      selectedColor: AppColors.primaryDim,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),

    // ListTile
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      subtitleTextStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHighlight,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // Text
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      displaySmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
      titleSmall: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      labelLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
      labelMedium: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      labelSmall: TextStyle(color: AppColors.textMuted, fontSize: 11),
    ),

    // Toggle buttons
    toggleButtonsTheme: ToggleButtonsThemeData(
      color: AppColors.textSecondary,
      selectedColor: AppColors.primaryLight,
      fillColor: AppColors.primaryDim,
      borderColor: AppColors.border,
      selectedBorderColor: AppColors.primary,
      borderRadius: BorderRadius.circular(6),
      constraints: const BoxConstraints(minHeight: 30, minWidth: 48),
      textStyle: const TextStyle(fontSize: 12),
    ),

    // Scrollbar
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.borderLight),
      radius: const Radius.circular(4),
      thickness: WidgetStateProperty.all(4),
    ),
  );
}
