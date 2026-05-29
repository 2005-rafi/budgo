import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff39693b),
      surfaceTint: Color(0xff39693b),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffbaf0b6),
      onPrimaryContainer: Color(0xff215025),
      secondary: Color(0xff4a662d),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffcbeda5),
      onSecondaryContainer: Color(0xff334e17),
      tertiary: Color(0xff4a672d),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffcbeea5),
      onTertiaryContainer: Color(0xff334e17),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffff8f2),
      onSurface: Color(0xff1f1b13),
      onSurfaceVariant: Color(0xff4d4639),
      outline: Color(0xff7f7667),
      outlineVariant: Color(0xffd0c5b4),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff353027),
      inversePrimary: Color(0xff9fd49c),
      primaryFixed: Color(0xffbaf0b6),
      onPrimaryFixed: Color(0xff002106),
      primaryFixedDim: Color(0xff9fd49c),
      onPrimaryFixedVariant: Color(0xff215025),
      secondaryFixed: Color(0xffcbeda5),
      onSecondaryFixed: Color(0xff0f2000),
      secondaryFixedDim: Color(0xffb0d18b),
      onSecondaryFixedVariant: Color(0xff334e17),
      tertiaryFixed: Color(0xffcbeea5),
      onTertiaryFixed: Color(0xff0e2000),
      tertiaryFixedDim: Color(0xffb0d18b),
      onTertiaryFixedVariant: Color(0xff334e17),
      surfaceDim: Color(0xffe2d9cc),
      surfaceBright: Color(0xfffff8f2),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffcf2e5),
      surfaceContainer: Color(0xfff6eddf),
      surfaceContainerHigh: Color(0xfff1e7d9),
      surfaceContainerHighest: Color(0xffebe1d4),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff0e3f16),
      surfaceTint: Color(0xff39693b),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff487849),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff233d07),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff59763a),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff233d07),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff58763a),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffff8f2),
      onSurface: Color(0xff141109),
      onSurfaceVariant: Color(0xff3c3529),
      outline: Color(0xff595244),
      outlineVariant: Color(0xff746c5d),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff353027),
      inversePrimary: Color(0xff9fd49c),
      primaryFixed: Color(0xff487849),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff2f5f32),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff59763a),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff415d24),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff58763a),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff415d24),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffcec5b8),
      surfaceBright: Color(0xfffff8f2),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffcf2e5),
      surfaceContainer: Color(0xfff1e7d9),
      surfaceContainerHigh: Color(0xffe5dcce),
      surfaceContainerHighest: Color(0xffdad0c3),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff01340d),
      surfaceTint: Color(0xff39693b),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff235328),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff1a3200),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff365119),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff1a3200),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff365119),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffff8f2),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff322b1f),
      outlineVariant: Color(0xff50483b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff353027),
      inversePrimary: Color(0xff9fd49c),
      primaryFixed: Color(0xff235328),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff093b13),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff365119),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff203904),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff365119),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff203904),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc0b8ab),
      surfaceBright: Color(0xfffff8f2),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff9efe2),
      surfaceContainer: Color(0xffebe1d4),
      surfaceContainerHigh: Color(0xffdcd3c6),
      surfaceContainerHighest: Color(0xffcec5b8),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff9fd49c),
      surfaceTint: Color(0xff9fd49c),
      onPrimary: Color(0xff063911),
      primaryContainer: Color(0xff215025),
      onPrimaryContainer: Color(0xffbaf0b6),
      secondary: Color(0xffb0d18b),
      onSecondary: Color(0xff1e3702),
      secondaryContainer: Color(0xff334e17),
      onSecondaryContainer: Color(0xffcbeda5),
      tertiary: Color(0xffb0d18b),
      onTertiary: Color(0xff1e3702),
      tertiaryContainer: Color(0xff334e17),
      onTertiaryContainer: Color(0xffcbeea5),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff17130b),
      onSurface: Color(0xffebe1d4),
      onSurfaceVariant: Color(0xffd0c5b4),
      outline: Color(0xff998f80),
      outlineVariant: Color(0xff4d4639),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffebe1d4),
      inversePrimary: Color(0xff39693b),
      primaryFixed: Color(0xffbaf0b6),
      onPrimaryFixed: Color(0xff002106),
      primaryFixedDim: Color(0xff9fd49c),
      onPrimaryFixedVariant: Color(0xff215025),
      secondaryFixed: Color(0xffcbeda5),
      onSecondaryFixed: Color(0xff0f2000),
      secondaryFixedDim: Color(0xffb0d18b),
      onSecondaryFixedVariant: Color(0xff334e17),
      tertiaryFixed: Color(0xffcbeea5),
      onTertiaryFixed: Color(0xff0e2000),
      tertiaryFixedDim: Color(0xffb0d18b),
      onTertiaryFixedVariant: Color(0xff334e17),
      surfaceDim: Color(0xff17130b),
      surfaceBright: Color(0xff3e392f),
      surfaceContainerLowest: Color(0xff110e07),
      surfaceContainerLow: Color(0xff1f1b13),
      surfaceContainer: Color(0xff231f17),
      surfaceContainerHigh: Color(0xff2e2921),
      surfaceContainerHighest: Color(0xff39342b),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffb4eab0),
      surfaceTint: Color(0xff9fd49c),
      onPrimary: Color(0xff002d09),
      primaryContainer: Color(0xff6b9d6a),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffc5e79f),
      onSecondary: Color(0xff152b00),
      secondaryContainer: Color(0xff7b9a5a),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffc5e79f),
      onTertiary: Color(0xff152b00),
      tertiaryContainer: Color(0xff7b9a5a),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff17130b),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffe7dbc9),
      outline: Color(0xffbbb1a0),
      outlineVariant: Color(0xff998f7f),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffebe1d4),
      inversePrimary: Color(0xff225227),
      primaryFixed: Color(0xffbaf0b6),
      onPrimaryFixed: Color(0xff001603),
      primaryFixedDim: Color(0xff9fd49c),
      onPrimaryFixedVariant: Color(0xff0e3f16),
      secondaryFixed: Color(0xffcbeda5),
      onSecondaryFixed: Color(0xff081400),
      secondaryFixedDim: Color(0xffb0d18b),
      onSecondaryFixedVariant: Color(0xff233d07),
      tertiaryFixed: Color(0xffcbeea5),
      onTertiaryFixed: Color(0xff071400),
      tertiaryFixedDim: Color(0xffb0d18b),
      onTertiaryFixedVariant: Color(0xff233d07),
      surfaceDim: Color(0xff17130b),
      surfaceBright: Color(0xff49443a),
      surfaceContainerLowest: Color(0xff0a0703),
      surfaceContainerLow: Color(0xff211d15),
      surfaceContainer: Color(0xff2c271f),
      surfaceContainerHigh: Color(0xff373229),
      surfaceContainerHighest: Color(0xff423d34),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffc7fec3),
      surfaceTint: Color(0xff9fd49c),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff9bd098),
      onPrimaryContainer: Color(0xff000f02),
      secondary: Color(0xffd9fbb1),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffaccd87),
      onSecondaryContainer: Color(0xff050e00),
      tertiary: Color(0xffd8fbb1),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffaccd88),
      onTertiaryContainer: Color(0xff040e00),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff17130b),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xfffbeedc),
      outlineVariant: Color(0xffccc1b0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffebe1d4),
      inversePrimary: Color(0xff225227),
      primaryFixed: Color(0xffbaf0b6),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff9fd49c),
      onPrimaryFixedVariant: Color(0xff001603),
      secondaryFixed: Color(0xffcbeda5),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb0d18b),
      onSecondaryFixedVariant: Color(0xff081400),
      tertiaryFixed: Color(0xffcbeea5),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffb0d18b),
      onTertiaryFixedVariant: Color(0xff071400),
      surfaceDim: Color(0xff17130b),
      surfaceBright: Color(0xff554f45),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff231f17),
      surfaceContainer: Color(0xff353027),
      surfaceContainerHigh: Color(0xff403b31),
      surfaceContainerHighest: Color(0xff4c463c),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
  );
}

class AppColors {
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color black87 = Colors.black87;
  static const Color black54 = Colors.black54;
}
