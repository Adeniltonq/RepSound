import 'package:flutter/material.dart';

/// Paleta do RepSound: azul vivo sobre preto profundo (tema escuro) e branco
/// limpo (tema claro).
abstract final class AppColors {
  static const blue = Color(0xFF3B82F6);
  static const blueLight = Color(0xFF60A5FA);
  static const blueDeep = Color(0xFF1D4ED8);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);

  static const black = Color(0xFF07080B);
  static const ink = Color(0xFF0D1017);
  static const inkSoft = Color(0xFF141821);

  static const accents = <Color>[blue, cyan, violet, green, amber, rose];

  static const accentNames = <String>[
    'Azul',
    'Ciano',
    'Violeta',
    'Verde',
    'Âmbar',
    'Rosa',
  ];
}

abstract final class AppTheme {
  static ThemeData dark({
    Color accent = AppColors.blue,
    bool animations = true,
  }) =>
      _build(Brightness.dark, accent, animations);

  static ThemeData light({
    Color accent = AppColors.blue,
    bool animations = true,
  }) =>
      _build(Brightness.light, accent, animations);

  static ThemeData _build(
    Brightness brightness,
    Color accent,
    bool animations,
  ) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? Color.alphaBlend(accent.withValues(alpha: 0.22), AppColors.ink)
          : Color.alphaBlend(accent.withValues(alpha: 0.12), Colors.white),
      onPrimaryContainer: isDark ? Colors.white : AppColors.blueDeep,
      secondary: isDark ? AppColors.blueLight : AppColors.blueDeep,
      onSecondary: isDark ? AppColors.black : Colors.white,
      surface: isDark ? AppColors.ink : Colors.white,
      onSurface: isDark ? const Color(0xFFF3F6FB) : const Color(0xFF0A1020),
      onSurfaceVariant: isDark
          ? const Color(0xFF9AA6B8)
          : const Color(0xFF5B6779),
      surfaceContainerLowest: isDark ? AppColors.black : const Color(0xFFF6F8FC),
      surfaceContainerLow: isDark ? const Color(0xFF0A0D13) : const Color(0xFFF0F4FA),
      surfaceContainer: isDark ? AppColors.ink : Colors.white,
      surfaceContainerHigh: isDark ? AppColors.inkSoft : const Color(0xFFF4F7FC),
      surfaceContainerHighest: isDark
          ? const Color(0xFF1A1F2A)
          : const Color(0xFFE9EEF7),
      outline: isDark ? const Color(0xFF2A3140) : const Color(0xFFD3DCE9),
      outlineVariant: isDark ? const Color(0xFF1B2130) : const Color(0xFFE4EBF5),
      error: const Color(0xFFFF6B81),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.3),
        );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.black : const Color(0xFFF7F9FD),
      canvasColor: isDark ? AppColors.black : const Color(0xFFF7F9FD),
      textTheme: textTheme,
      pageTransitionsTheme: animations
          ? null
          : const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: _InstantPageTransitionsBuilder(),
                TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
                TargetPlatform.linux: _InstantPageTransitionsBuilder(),
                TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
                TargetPlatform.windows: _InstantPageTransitionsBuilder(),
                TargetPlatform.fuchsia: _InstantPageTransitionsBuilder(),
              },
            ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.ink : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.inkSoft : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.inkSoft : Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isDark ? AppColors.inkSoft : Colors.white,
        modalBarrierColor: Colors.black.withValues(alpha: 0.62),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF0A0C11).withValues(alpha: 0.98)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: accent.withValues(alpha: isDark ? 0.20 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : scheme.onSurfaceVariant,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? accent : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.inkSoft : Colors.white,
        selectedColor: accent.withValues(alpha: isDark ? 0.20 : 0.12),
        secondarySelectedColor: accent,
        disabledColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.inkSoft : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.14),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1D2431) : const Color(0xFF101827),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? const Color(0xFF171C26) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.12)),
        ),
      ),
    );
  }
}

/// Transição instantânea usada quando o usuário desliga as animações.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
