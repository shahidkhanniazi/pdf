import 'package:flutter/material.dart';

/// Colours and type taken from the website's theme (parchment, gold, brown).
class Brand {
  static const gold = Color(0xFFE2B85C);
  static const cinema = Color(0xFF0B0806);

  // Light
  static const lBg = Color(0xFFF4ECD8);
  static const lSurface = Color(0xFFFBF6EA);
  static const lSurface2 = Color(0xFFE9DCBC);
  static const lText = Color(0xFF2B2118);
  static const lMuted = Color(0xFF6F5D4A);
  static const lBorder = Color(0xFFD8C49C);
  static const lAccent = Color(0xFFA67C2D);
  static const lAccentStrong = Color(0xFF7A5A1E);

  // Dark
  static const dBg = Color(0xFF0D0A07);
  static const dSurface = Color(0xFF1B150F);
  static const dSurface2 = Color(0xFF261E16);
  static const dText = Color(0xFFF2E9D8);
  static const dMuted = Color(0xFFB4A48A);
  static const dBorder = Color(0x1FF2E9D8);
  static const dAccent = Color(0xFFD6A84C);
  static const dAccentStrong = Color(0xFFECC472);
}

const String fontUrdu = 'NotoNastaliqUrdu';
const String fontBody = 'Lora';
const String fontHeading = 'PlayfairDisplay';
const String fontUi = 'Inter';

ThemeData buildTheme(Brightness brightness, {required bool urdu}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? Brand.dAccent : Brand.lAccent,
    onPrimary: dark ? const Color(0xFF1A1208) : Colors.white,
    primaryContainer: dark ? Brand.dSurface2 : Brand.lSurface2,
    onPrimaryContainer: dark ? Brand.dText : Brand.lText,
    secondary: dark ? Brand.dAccentStrong : Brand.lAccentStrong,
    onSecondary: dark ? const Color(0xFF1A1208) : Colors.white,
    surface: dark ? Brand.dBg : Brand.lBg,
    onSurface: dark ? Brand.dText : Brand.lText,
    onSurfaceVariant: dark ? Brand.dMuted : Brand.lMuted,
    surfaceContainerLowest: dark ? Brand.dBg : Brand.lSurface,
    surfaceContainerLow: dark ? Brand.dSurface : Brand.lSurface,
    surfaceContainer: dark ? Brand.dSurface : Brand.lSurface,
    surfaceContainerHigh: dark ? Brand.dSurface2 : Brand.lSurface2,
    surfaceContainerHighest: dark ? Brand.dSurface2 : Brand.lSurface2,
    outline: dark ? Brand.dBorder : Brand.lBorder,
    outlineVariant: dark ? Brand.dBorder : Brand.lBorder,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
  );

  final uiFont = urdu ? fontUrdu : fontUi;
  final headFont = urdu ? fontUrdu : fontHeading;
  // Nastaliq needs a lot more line height than Latin type.
  final h = urdu ? 1.9 : null;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: uiFont,
    scaffoldBackgroundColor: scheme.surface,
  );

  final text = base.textTheme.apply(
    fontFamily: uiFont,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  TextStyle? head(TextStyle? s, double size) => s?.copyWith(
      fontFamily: headFont,
      fontWeight: FontWeight.w700,
      fontSize: urdu ? size * 0.9 : size,
      height: urdu ? 1.8 : 1.15);

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: head(text.displaySmall, 34),
      headlineMedium: head(text.headlineMedium, 28),
      headlineSmall: head(text.headlineSmall, 24),
      titleLarge: head(text.titleLarge, 20),
      titleMedium: text.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, height: h ?? 1.3),
      titleSmall: text.titleSmall?.copyWith(height: h ?? 1.3),
      bodyLarge: text.bodyLarge?.copyWith(height: h ?? 1.5),
      bodyMedium: text.bodyMedium?.copyWith(height: h ?? 1.45),
      bodySmall: text.bodySmall
          ?.copyWith(height: h ?? 1.4, color: scheme.onSurfaceVariant),
      labelSmall: text.labelSmall?.copyWith(
          letterSpacing: urdu ? 0 : 1.1, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: headFont,
        fontWeight: FontWeight.w700,
        fontSize: urdu ? 19 : 21,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? Brand.dSurface : Brand.lSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outline.withValues(alpha: dark ? 1 : .6)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? Brand.dSurface : Brand.lSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: .18),
      height: 66,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: uiFont, fontSize: urdu ? 11 : 12, height: urdu ? 1.4 : null),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: dark ? Brand.dSurface : Brand.lSurface,
      selectedColor: scheme.primary.withValues(alpha: .25),
      side: BorderSide(color: scheme.outline),
      labelStyle: TextStyle(fontFamily: uiFont, color: scheme.onSurface, height: h),
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? Brand.gold : Brand.lAccent,
        foregroundColor: dark ? const Color(0xFF1A1208) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, height: h),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, height: h),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontFamily: uiFont, height: h),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// Body font for long reading.
TextStyle readingStyle(BuildContext context, {required bool urdu, double scale = 1}) {
  final c = Theme.of(context).colorScheme;
  return TextStyle(
    fontFamily: urdu ? fontUrdu : fontBody,
    fontSize: (urdu ? 19 : 18) * scale,
    height: urdu ? 2.2 : 1.8,
    color: c.onSurface,
  );
}
