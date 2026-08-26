import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema do app SECAMI — identidade institucional Casa Militar (Goias).
///
/// Decisoes (SPEC §7 + referencia-visual.md — referência de app
/// institucional de saúde do estado de Goiás trazida pelo usuário):
/// - Poppins: display + body (geométrica arredondada, amigável — troca do
///   Inter original pra casar com a referência visual)
/// - JetBrains Mono: numeros (cargas, reps, timer) - alinhamento de digitos
/// - Verde institucional vivo #00783C: dominante. Dourado #E0B920: acento.
///   Verde-limão #C3E436: destaque em cards de acesso rápido (Academia).
/// - Border radius 20px + botoes em pill (referência: "cantos muito
///   arredondados", era 12px/reto)
/// - Elevacao leve + border 1px sutil
/// - Contraste WCAG AA em texto e icones
class AppTheme {
  const AppTheme._();

  // === Tokens Casa Militar ===
  static const _primary = Color(0xFF00783C); // verde institucional vivo
  static const _surfaceDark = Color(0xFF121714); // verde-quase-preto

  /// Verde-limão de destaque (cards de acesso rápido — referência visual).
  static const limeAccent = Color(0xFFC3E436);

  /// Texto/ícone sobre [limeAccent] (contraste AA).
  static const onLimeAccent = Color(0xFF114023);
  static const _surfaceContainerDark = Color(0xFF1A211D);
  static const _surfaceContainerHighDark = Color(0xFF232B26);
  static const _borderDark = Color(0xFF2A322C);

  static const _surfaceLight = Color(0xFFF7F8F7);
  static const _surfaceContainerLight = Color(0xFFEEF1EE);
  static const _borderLight = Color(0xFFDCE3DD);

  /// Borda verde dos inputs (referência: "borda fina verde escura"), mais
  /// suave que o brand-primary puro pra não pesar em formulários longos.
  static const _inputBorderLight = Color(0xFF73B594);
  static const _inputBorderDark = Color(0xFF3C9064);

  static const _radius = 20.0;

  /// Botões em pill (referência visual: primário formato pill).
  static const _pillRadius = 999.0;

  // === Espaçamento (design-system.md §4 — grid de 4px) ===
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  // === Movimento (design-system.md §8 — curto e funcional, sem bounce) ===
  static const motionFast = Duration(milliseconds: 120);
  static const motionBase = Duration(milliseconds: 200);
  static const motionSlow = Duration(milliseconds: 320);
  static const easingStandard = Cubic(0.2, 0, 0, 1);

  // === Raio de borda (design-system.md §5) ===
  static const radiusSm = 8.0; // badges, chips pequenos
  static const radiusMd = 12.0; // cards, inputs custom, linhas de lista
  static const radiusLg = _radius; // 20 — cards de destaque (CardTheme)
  static const radiusPill = _pillRadius; // botões primários, busca, avatar

  /// Sombra "resting" (nível 1, design-system.md §6) — pra Containers que
  /// representam card fora do `CardTheme` padrão (linhas de lista custom,
  /// caixas informativas). Suave, nunca pesada.
  static List<BoxShadow> cardShadow(ColorScheme scheme) => [
    BoxShadow(
      blurRadius: 16,
      offset: const Offset(0, 4),
      color: scheme.shadow.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.3 : 0.06,
      ),
    ),
  ];

  // === Tipografia ===
  static TextStyle _display(
    double size, {
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.01 * size, // leve aperto em titulos
      height: 1.1,
    );
  }

  static TextStyle _body(double size, {FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0,
      height: 1.45,
    );
  }

  /// Mono pra numeros. Usar em cargas, reps, timer.
  static TextStyle mono(double size, {FontWeight weight = FontWeight.w500}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0,
      height: 1.0,
    );
  }

  /// Label tipo CAPS-LOCK com letter-spacing aberto (editorial).
  static TextStyle label(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.06,
      height: 1.2,
      color: color,
    );
  }

  // === Color schemes ===
  static ColorScheme _darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF4FCB8B), // verde vivo clareado p/ contraste no escuro
      onPrimary: Color(0xFF06140D),
      primaryContainer: Color(0xFF1E3A2D),
      onPrimaryContainer: Color(0xFFB6E3CC),
      secondary: Color(0xFFE6C34C), // dourado vivo (escuro)
      onSecondary: Color(0xFF2A2004),
      secondaryContainer: Color(0xFF3A3212),
      onSecondaryContainer: Color(0xFFF7F2E2),
      tertiary: Color(0xFF78B3CF), // azul informativo
      onTertiary: _surfaceDark,
      error: Color(0xFFE8483F), // vermelho vivo (referência visual)
      onError: _surfaceDark,
      surface: _surfaceDark,
      onSurface: Color(0xFFE6ECE8),
      onSurfaceVariant: Color(0xFFA9B3AD),
      surfaceContainerLowest: _surfaceDark,
      surfaceContainerLow: _surfaceContainerDark,
      surfaceContainer: _surfaceContainerDark,
      surfaceContainerHigh: _surfaceContainerHighDark,
      surfaceContainerHighest: _surfaceContainerHighDark,
      outline: _borderDark,
      outlineVariant: _borderDark,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE6ECE8),
      onInverseSurface: _surfaceDark,
      inversePrimary: _primary,
    );
  }

  static ColorScheme _lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: _primary, // verde institucional vivo #00783C
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0F3E7),
      onPrimaryContainer: Color(0xFF14382A), // verde escuro
      secondary: Color(0xFFE0B920), // dourado vivo
      onSecondary: Color(0xFF3A2E08),
      secondaryContainer: Color(0xFFFBF1D0),
      onSecondaryContainer: Color(0xFF5A4A12),
      tertiary: Color(0xFF3B7A9E), // azul informativo
      onTertiary: Colors.white,
      error: Color(0xFFD6362D), // vermelho vivo (referência visual)
      onError: Colors.white,
      surface: _surfaceLight,
      onSurface: Color(0xFF1A211C),
      onSurfaceVariant: Color(0xFF5A625C),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: _surfaceContainerLight,
      surfaceContainer: _surfaceContainerLight,
      surfaceContainerHigh: Color(0xFFE7ECE7),
      surfaceContainerHighest: Color(0xFFE7ECE7),
      outline: _borderLight,
      outlineVariant: _borderLight,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF1A211C),
      onInverseSurface: Colors.white,
      inversePrimary: _primary,
    );
  }

  static ThemeData light() => _build(_lightScheme());
  static ThemeData dark() => _build(_darkScheme());

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // === Tipografia base ===
      textTheme: TextTheme(
        displayLarge: _display(56, weight: FontWeight.w800),
        displayMedium: _display(44, weight: FontWeight.w800),
        displaySmall: _display(34, weight: FontWeight.w700),
        headlineLarge: _display(28, weight: FontWeight.w700),
        headlineMedium: _display(22, weight: FontWeight.w700),
        headlineSmall: _display(18, weight: FontWeight.w700),
        titleLarge: _display(20, weight: FontWeight.w600),
        titleMedium: _display(16, weight: FontWeight.w600),
        titleSmall: _body(14, weight: FontWeight.w600),
        bodyLarge: _body(16),
        bodyMedium: _body(14),
        bodySmall: _body(12),
        labelLarge: label(13),
        labelMedium: label(12),
        labelSmall: label(11),
      ),

      // === App bar editorial: sem elevacao, titulo grande grotesco ===
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _display(
          20,
          weight: FontWeight.w700,
        ).copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),

      // === Card: borda 1px + elevação 1 (design-system.md §6) ===
      // Sombra suave (nunca pesada) + borda sutil — sem tint de cor no
      // elevation do M3 (senão todo card ganha um verde de fundo indesejado).
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 1,
        shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.4 : 0.08),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: scheme.outline, width: 1),
        ),
      ),

      // === ListTile compacto ===
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),

      // === Botoes (pill — referência visual) ===
      // Primário em lima + texto verde-escuro (referência visual: "fundo
      // verde-lima, texto verde-escuro bold" — não o verde institucional
      // solido, que fica reservado pra navegacao/selecao).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: limeAccent,
          foregroundColor: onLimeAccent,
          textStyle: _display(16, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pillRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline, width: 1),
          textStyle: _display(15, weight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pillRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: _body(14, weight: FontWeight.w600),
        ),
      ),

      // === Inputs com borda verde (referência visual) ===
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(
            color: isDark ? _inputBorderDark : _inputBorderLight,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(
            color: isDark ? _inputBorderDark : _inputBorderLight,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: _body(
          14,
          weight: FontWeight.w500,
        ).copyWith(color: scheme.onSurfaceVariant),
        hintStyle: _body(
          14,
        ).copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
      ),

      // === Chips ===
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        labelStyle: _body(
          13,
          weight: FontWeight.w500,
        ).copyWith(color: scheme.onSurface),
        secondaryLabelStyle: _body(
          13,
          weight: FontWeight.w600,
        ).copyWith(color: scheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // === Dividers sutis ===
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),

      // === Snack bar ===
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? Colors.white : Colors.black,
        contentTextStyle: _body(
          14,
          weight: FontWeight.w500,
        ).copyWith(color: isDark ? Colors.black : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),

      // === Bottom nav editorial ===
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return label(11, color: scheme.primary);
          }
          return label(11, color: scheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 22);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 22);
        }),
      ),

      // === FAB com borda visual ===
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: _display(15, weight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: Colors.transparent, width: 1),
        ),
      ),

      // === SegmentedButton ===
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(
            _body(13, weight: FontWeight.w600),
          ),
        ),
      ),

      // === Page transitions: fade-forwards no Android (Material 3 moderno) ===
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Atalhos para uso em widgets sem precisar reimportar GoogleFonts.
extension TypographyShortcuts on BuildContext {
  TextStyle monoFigure(double size, {FontWeight weight = FontWeight.w500}) =>
      AppTheme.mono(size, weight: weight);

  TextStyle uppercaseLabel(double size, {Color? color}) =>
      AppTheme.label(size, color: color);
}
