import 'package:flutter/material.dart';

class AppTheme {
  /// Color sage por defecto (coincide con AppSettings.defaultColor).
  static const defaultSeed = Color(0xFF5A7D5A);
  static const _beige = Color(0xFFF7F3EF);

  static ThemeData light({Color? seed}) {
    final seedColor = seed ?? defaultSeed;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final onPrimary =
        ThemeData.estimateBrightnessForColor(seedColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1E2A22);
    final primaryContainer = Color.alphaBlend(
      seedColor.withValues(alpha: 0.20),
      _beige,
    );
    final cs = baseScheme.copyWith(
      primary: seedColor,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: const Color(0xFF1E2A22),
    );

    const playfair = 'PlayfairDisplay';
    const inter = 'Inter';
    const mono = 'JetBrainsMono';

    final textTheme = TextTheme(
      // ── Playfair Display → display, headlines y título de card ───────────
      displayLarge: TextStyle(
        fontFamily: playfair,
        fontSize: 57,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontFamily: playfair,
        fontSize: 45,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        fontFamily: playfair,
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: TextStyle(
        fontFamily: playfair,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        fontFamily: playfair,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        fontFamily: playfair,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: playfair,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      // ── Inter → cuerpo y títulos secundarios ─────────────────────────────
      titleMedium: TextStyle(
        fontFamily: inter,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontFamily: inter,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(fontFamily: inter, fontSize: 16, letterSpacing: 0.5),
      bodyMedium: TextStyle(
        fontFamily: inter,
        fontSize: 15,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(fontFamily: inter, fontSize: 14, letterSpacing: 0.3),
      // ── JetBrains Mono → etiquetas de datos (día X/Y, rachas, %) ─────────
      labelLarge: TextStyle(
        fontFamily: mono,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontFamily: mono,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontFamily: mono,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.35,
      ),
    );
    final readableTextTheme = textTheme.apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );

    final scaffoldTone = Color.alphaBlend(
      seedColor.withValues(alpha: 0.08),
      _beige,
    );
    final cardColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.85),
      scaffoldTone,
    );
    final inputFill = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.76),
      scaffoldTone,
    );
    final appBarColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.64),
      scaffoldTone,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: readableTextTheme,
      scaffoldBackgroundColor: scaffoldTone,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: appBarColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: playfair,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
        iconTheme: IconThemeData(color: cs.primary),
        actionsIconTheme: IconThemeData(color: cs.primary),
      ),
      // ── Cards: 24 px de radio, sin borde, sin sombra ──────────────────────
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        color: cardColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      // ── Botones rellenos: 16 px de radio ──────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: inter,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          elevation: 0,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: cs.primary,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: inter,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: inter,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide.none,
          backgroundColor: cs.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      // ── Inputs: 16 px de radio, sin borde visible ─────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: TextStyle(fontFamily: inter, color: cs.onSurfaceVariant),
        hintStyle: TextStyle(fontFamily: inter, color: cs.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.surface,
        contentTextStyle: readableTextTheme.bodyMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // ── Chips ──────────────────────────────────────────────────────────────
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        textStyle: readableTextTheme.bodyMedium?.copyWith(color: cs.onSurface),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: readableTextTheme.bodyLarge?.copyWith(color: cs.onSurface),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        titleTextStyle: readableTextTheme.titleLarge?.copyWith(
          color: cs.onSurface,
        ),
        contentTextStyle: readableTextTheme.bodyMedium?.copyWith(
          color: cs.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _beige,
        modalBackgroundColor: _beige,
        surfaceTintColor: Colors.transparent,
      ),
      // ── NavigationBar ──────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.primary,
        elevation: 0,
        shadowColor: Colors.transparent,
        indicatorColor: cs.onPrimary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontFamily: inter,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onPrimary,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: readableTextTheme.bodyLarge,
        subtitleTextStyle: readableTextTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
        ),
        iconColor: cs.onSurfaceVariant,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
    );
  }
}
