import 'package:flutter/material.dart';

/// Colour tokens copied from frontend/src/design-system/tokens (colors.css, semantic.css).
class TL {
  TL._();

  static const sea950 = Color(0xFF05171F);
  static const sea900 = Color(0xFF0A2532);
  static const sea800 = Color(0xFF0F3446);
  static const sea700 = Color(0xFF14465C);
  static const sea600 = Color(0xFF1A6180);
  static const sea500 = Color(0xFF2483A8);
  static const sea300 = Color(0xFF7FC6DD);
  static const sea100 = Color(0xFFDCF0F6);

  static const tide800 = Color(0xFF044F4D);
  static const tide700 = Color(0xFF056E6B);
  static const tide600 = Color(0xFF068B85);
  static const tide500 = Color(0xFF0FA89F);
  static const tide400 = Color(0xFF35C2B7);
  static const tide300 = Color(0xFF7BD9D0);
  static const tide100 = Color(0xFFD6F4F1);

  static const sand50 = Color(0xFFFBF8F2);

  static const coral700 = Color(0xFFA32E1A);
  static const coral600 = Color(0xFFC43B24);
  static const coral500 = Color(0xFFE24E32);
  static const coral100 = Color(0xFFFDE4DD);

  static const kelp600 = Color(0xFF3E7B2F);
  static const kelp500 = Color(0xFF52A03D);
  static const kelp100 = Color(0xFFE4F2DD);

  static const buoy600 = Color(0xFFB4740A);
  static const buoy500 = Color(0xFFE09414);
  static const buoy400 = Color(0xFFF5C45B);
  static const buoy100 = Color(0xFFFDF0D6);

  static const gray50 = Color(0xFFF7F8F9);
  static const gray100 = Color(0xFFEEF0F2);
  static const gray200 = Color(0xFFDCE0E4);
  static const gray300 = Color(0xFFC0C7CD);
  static const gray500 = Color(0xFF6D7A85);
  static const gray600 = Color(0xFF4E5A64);
  static const gray700 = Color(0xFF3A444C);

  static const textStrong = sea950;
  static const textBody = gray700;
  static const textMuted = gray500;

  static const radiusSm = 6.0;
  static const radiusMd = 10.0;
  static const radiusLg = 14.0;
  static const radiusXl = 20.0;

  /// Typefaces from tokens/fonts.css: Sora for headings, Instrument Sans for text,
  /// JetBrains Mono for references and figures. Bundled under assets/fonts.
  static const fontDisplay = 'Sora';
  static const fontBody = 'InstrumentSans';
  static const fontMono = 'JetBrainsMono';

  static const cardShadow = [
    BoxShadow(color: Color(0x140A2532), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: TL.tide600,
        brightness: Brightness.light,
      ).copyWith(
        primary: TL.tide600,
        onPrimary: Colors.white,
        secondary: TL.sea600,
        error: TL.coral600,
        surface: Colors.white,
      );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(TL.radiusMd),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TL.gray50,
    fontFamily: TL.fontBody,
    // Sizes follow tokens/typography.css (--text-h1 … --text-caption).
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: TL.fontDisplay,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.6,
        color: TL.textStrong,
      ),
      headlineMedium: TextStyle(
        fontFamily: TL.fontDisplay,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.5,
        color: TL.textStrong,
      ),
      headlineSmall: TextStyle(
        fontFamily: TL.fontDisplay,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.4,
        color: TL.textStrong,
      ),
      titleLarge: TextStyle(
        fontFamily: TL.fontDisplay,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: TL.textStrong,
      ),
      titleMedium: TextStyle(
        fontFamily: TL.fontDisplay,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: TL.textStrong,
      ),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: TL.textBody),
      bodySmall: TextStyle(fontSize: 13, height: 1.45, color: TL.textMuted),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    ),
    appBarTheme: const AppBarTheme(
      titleTextStyle: TextStyle(
        fontFamily: TL.fontDisplay,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: TL.textStrong,
      ),
      backgroundColor: Colors.white,
      foregroundColor: TL.textStrong,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(TL.gray300),
      enabledBorder: border(TL.gray300),
      focusedBorder: border(TL.tide500, 2),
      errorBorder: border(TL.coral600),
      focusedErrorBorder: border(TL.coral600, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TL.tide600,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TL.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TL.tide700),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: TL.tide100,
      side: const BorderSide(color: TL.gray300),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: TL.textBody,
      ),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TL.tide600 : null,
      ),
    ),
  );
}
