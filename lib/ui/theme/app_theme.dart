import 'package:flutter/material.dart';

/// Central place where the entire visual identity of the app is defined.
///
/// Why a dedicated class instead of inlining in `main.dart`?
///   * One source of truth for colors, typography and component shapes.
///   * Identical configuration for light and dark themes – we only swap
///     the [Brightness] so every component automatically picks up the
///     right palette via [Theme.of].
///   * Trivial to unit-test (just call [AppTheme.light] / [AppTheme.dark]
///     and assert on the resulting [ThemeData]).
///
/// The seed color is a calm indigo/violet that reads as "trust + focus" –
/// a good fit for a productivity / alarm app – while Material 3's
/// dynamic color algorithm derives an accessible, balanced palette from
/// it for both brightness modes.
class AppTheme {
  AppTheme._();

  /// Brand seed color. Single value drives the whole palette.
  static const Color seedColor = Color(0xFF6750A4);

  /// Common rounded shape used for cards, dialogs and bottom sheets.
  static final RoundedRectangleBorder _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );

  /// Public: complete light theme.
  static ThemeData light() => _build(Brightness.light);

  /// Public: complete dark theme.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final TextTheme baseText = brightness == Brightness.light
        ? Typography.blackMountainView
        : Typography.whiteMountainView;

    // A slightly tightened, modern text theme. We bump display sizes a bit
    // because the home screen relies on a very large time readout.
    final TextTheme textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -1,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,

      // AppBar that visually blends with the surface for a cleaner look.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),

      // Card defaults used by AlarmCard. Soft rounded surface, no harsh
      // shadow, subtle tint difference between light/dark modes.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _cardShape,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
      ),

      // FAB that picks up brand color and stands out without being loud.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // Switches: use brand color for the active track so toggling an
      // alarm "on" is visually obvious in both themes.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return null; // use default
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return null;
        }),
      ),

      // Chips used for weekday badges on each alarm card.
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.4),
        selectedColor: scheme.primary,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
        secondaryLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: const StadiumBorder(),
      ),

      // Dialogs (used for delete confirmation) — match card rounding.
      dialogTheme: DialogThemeData(
        shape: _cardShape,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
      ),

      // Snackbars used for transient feedback after toggle/delete.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
      ),

      // Subtle dividers — almost invisible, just enough to suggest structure.
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),

      // Pages animate consistently across platforms.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
