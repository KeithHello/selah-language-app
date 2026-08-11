import 'package:flutter/material.dart';

import 'selah_colors.dart';
import 'selah_spacing.dart';
import 'selah_typography.dart';

/// Selah 应用主题组装。
/// 品牌方向：Quiet Growth——暖米色、柔和、陪伴、不施压。
class SelahTheme {
  const SelahTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SelahColors.bgPrimary,
      colorScheme: const ColorScheme.light(
        primary: SelahColors.coral,
        onPrimary: SelahColors.textOnAccent,
        secondary: SelahColors.lavender,
        onSecondary: SelahColors.textOnAccent,
        surface: SelahColors.cardPrimary,
        onSurface: SelahColors.textPrimary,
        error: SelahColors.danger,
        onError: SelahColors.textOnAccent,
        outline: SelahColors.border,
        outlineVariant: SelahColors.borderLight,
      ),
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: SelahTypography.displayLarge(color: SelahColors.textPrimary),
        displayMedium: SelahTypography.displayMedium(color: SelahColors.textPrimary),
        headlineLarge: SelahTypography.headlineLarge(color: SelahColors.textPrimary),
        headlineMedium: SelahTypography.headlineMedium(color: SelahColors.textPrimary),
        headlineSmall: SelahTypography.headlineSmall(color: SelahColors.textSecondary),
        titleLarge: SelahTypography.headlineLarge(color: SelahColors.textPrimary),
        titleMedium: SelahTypography.headlineMedium(color: SelahColors.textPrimary),
        bodyLarge: SelahTypography.bodyLarge(color: SelahColors.textPrimary),
        bodyMedium: SelahTypography.bodyMedium(color: SelahColors.textSecondary),
        bodySmall: SelahTypography.bodySmall(color: SelahColors.textTertiary),
        labelLarge: SelahTypography.labelLarge(color: SelahColors.textSecondary),
        labelMedium: SelahTypography.labelMedium(color: SelahColors.textTertiary),
        labelSmall: SelahTypography.labelSmall(color: SelahColors.textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: SelahColors.bgPrimary,
        foregroundColor: SelahColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: SelahTypography.headlineLarge(color: SelahColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: SelahColors.cardPrimary,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SelahCornerRadius.lg)),
          side: const BorderSide(color: SelahColors.borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SelahColors.coral,
          foregroundColor: SelahColors.textOnAccent,
          disabledBackgroundColor: SelahColors.textTertiary.withValues(alpha: 0.35),
          disabledForegroundColor: SelahColors.textOnAccent,
          elevation: 0,
          minimumSize: const Size(64, SelahSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: SelahSpacing.xl, vertical: SelahSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
          ),
          textStyle: SelahTypography.labelLarge(color: SelahColors.textOnAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SelahColors.textPrimary,
          minimumSize: const Size(64, SelahSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: SelahSpacing.xl, vertical: SelahSpacing.md),
          side: const BorderSide(color: SelahColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
          ),
          textStyle: SelahTypography.labelLarge(color: SelahColors.textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SelahColors.textSecondary,
          minimumSize: const Size(48, SelahSpacing.minTouchTarget),
          textStyle: SelahTypography.labelLarge(color: SelahColors.textSecondary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SelahColors.cardPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: SelahSpacing.lg, vertical: SelahSpacing.md),
        hintStyle: SelahTypography.bodyLarge(color: SelahColors.textTertiary),
        labelStyle: SelahTypography.labelLarge(color: SelahColors.textSecondary),
        errorStyle: SelahTypography.bodySmall(color: SelahColors.danger),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SelahCornerRadius.md),
          borderSide: const BorderSide(color: SelahColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SelahCornerRadius.md),
          borderSide: const BorderSide(color: SelahColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SelahCornerRadius.md),
          borderSide: const BorderSide(color: SelahColors.coral, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SelahCornerRadius.md),
          borderSide: const BorderSide(color: SelahColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SelahCornerRadius.md),
          borderSide: const BorderSide(color: SelahColors.danger, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SelahColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SelahColors.cardPrimary,
        indicatorColor: SelahColors.coralSoft,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return SelahTypography.labelSmall(
            color: selected ? SelahColors.coral : SelahColors.textTertiary,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SelahColors.textPrimary,
        contentTextStyle: SelahTypography.bodyMedium(color: SelahColors.cardPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SelahCornerRadius.md)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: SelahColors.textPrimary,
          borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
        ),
        textStyle: SelahTypography.bodySmall(color: SelahColors.cardPrimary),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SelahColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: SelahColors.coral,
        onPrimary: SelahColors.textOnAccent,
        secondary: SelahColors.lavender,
        onSecondary: SelahColors.textOnAccent,
        surface: SelahColors.darkCard,
        onSurface: SelahColors.darkTextPrimary,
        error: SelahColors.coral,
        onError: SelahColors.textOnAccent,
        outline: SelahColors.darkBorder,
        outlineVariant: SelahColors.darkBorder,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: SelahTypography.displayLarge(color: SelahColors.darkTextPrimary),
        displayMedium: SelahTypography.displayMedium(color: SelahColors.darkTextPrimary),
        headlineLarge: SelahTypography.headlineLarge(color: SelahColors.darkTextPrimary),
        headlineMedium: SelahTypography.headlineMedium(color: SelahColors.darkTextPrimary),
        headlineSmall: SelahTypography.headlineSmall(color: SelahColors.darkTextSecondary),
        bodyLarge: SelahTypography.bodyLarge(color: SelahColors.darkTextPrimary),
        bodyMedium: SelahTypography.bodyMedium(color: SelahColors.darkTextSecondary),
        bodySmall: SelahTypography.bodySmall(color: SelahColors.darkTextTertiary),
        labelLarge: SelahTypography.labelLarge(color: SelahColors.darkTextSecondary),
        labelMedium: SelahTypography.labelMedium(color: SelahColors.darkTextTertiary),
        labelSmall: SelahTypography.labelSmall(color: SelahColors.darkTextTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: SelahColors.darkBg,
        foregroundColor: SelahColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: SelahTypography.headlineLarge(color: SelahColors.darkTextPrimary),
      ),
      cardTheme: const CardThemeData(
        color: SelahColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SelahCornerRadius.lg)),
          side: BorderSide(color: SelahColors.darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SelahColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
