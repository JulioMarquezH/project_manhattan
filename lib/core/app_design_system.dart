import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño global de la app.
/// Centraliza colores, tipografía, tema y guía de voz.
/// Importar desde cualquier pantalla:
///   import 'package:project_manhattan/core/app_design_system.dart';

// ============================================================
// COLORES
// ============================================================

class AppColors {
  AppColors._();

  // Principales
  static const Color azulControl = Color(0xFF1E3A8A);
  static const Color naranjaAccion = Color(0xFFF97316);
  static const Color verdeExito = Color(0xFF10B981);
  static const Color rojoAlerta = Color(0xFFEF4444);

  // Fondo
  static const Color fondoOscuro = Color(0xFF0F172A);

  // Texto claro (sobre fondo oscuro)
  static const Color textoClaroAlto = Color(0xFFF8FAFC);
  static const Color textoClaroMedio = Color(0xFFCBD5F5);

  /// Texto secundario, pistas y elementos desactivados. Contraste ≥ 5,7:1
  /// sobre [superficie] y ≥ 6,9:1 sobre [fondoOscuro] (WCAG AA).
  static const Color textoTenue = Color(0xFF94A3B8);

  /// Azul legible sobre fondo oscuro (texto, iconos). [azulControl] es
  /// para rellenos: como texto sobre el fondo no se lee (1,9:1).
  static const Color azulTexto = Color(0xFF93C5FD);

  // Superficies y bordes
  static const Color superficie = Color(0xFF1E293B);
  static const Color superficieAlta = Color(0xFF273449);
  static const Color borde = Color(0xFF334155);

  /// Borde de campos y controles: ≥ 3:1 contra el fondo (WCAG 1.4.11).
  static const Color bordeControl = Color(0xFF64748B);

  // Rellenos de botón con texto blanco (contraste ≥ 4,5:1).
  // naranjaAccion/verdeExito/rojoAlerta se siguen usando para texto e iconos
  // sobre el fondo oscuro, donde sí se leen bien.
  static const Color naranjaBoton = Color(0xFFC2410C);
  static const Color verdeBoton = Color(0xFF047857);
  static const Color rojoBoton = Color(0xFFB91C1C);

  // Texto oscuro (sobre fondo claro)
  static const Color textoOscuroAlto = Color(0xFF020617);
  static const Color textoOscuroMedio = Color(0xFF334155);
}

// ============================================================
// TIPOGRAFÍA
// ============================================================

class AppTypography {
  AppTypography._();

  /// Fuente principal — UI general, operación.
  static TextStyle inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Fuente alternativa — títulos, dashboard del dueño.
  static TextStyle plusJakarta({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Estilos predefinidos (sobre fondo oscuro)
  static TextStyle get displayLarge => plusJakarta(
        size: 32,
        weight: FontWeight.w700,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get headlineLarge => plusJakarta(
        size: 24,
        weight: FontWeight.w700,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get titleLarge => inter(
        size: 18,
        weight: FontWeight.w600,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get titleMedium => inter(
        size: 16,
        weight: FontWeight.w600,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get bodyLarge => inter(
        size: 16,
        weight: FontWeight.w400,
        color: AppColors.textoClaroAlto,
      );

  static TextStyle get bodyMedium => inter(
        size: 14,
        weight: FontWeight.w400,
        color: AppColors.textoClaroMedio,
      );

  static TextStyle get labelLarge => inter(
        size: 14,
        weight: FontWeight.w600,
        color: AppColors.textoClaroAlto,
        letterSpacing: 0.2,
      );

  static TextStyle get caption => inter(
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textoClaroMedio,
      );
}

// ============================================================
// TEMA
// ============================================================

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.fondoOscuro,
      colorScheme: const ColorScheme.dark(
        // Azul claro: los controles de Material (interruptores, chips
        // elegidos, botones de texto, cargadores) se ven sobre el fondo.
        primary: Color(0xFF60A5FA),
        onPrimary: AppColors.fondoOscuro,
        secondary: AppColors.naranjaAccion,
        onSecondary: AppColors.fondoOscuro,
        tertiary: AppColors.verdeExito,
        error: AppColors.rojoAlerta,
        onError: AppColors.fondoOscuro,
        surface: AppColors.fondoOscuro,
        onSurface: AppColors.textoClaroAlto,
        onSurfaceVariant: AppColors.textoClaroMedio,
        outline: AppColors.bordeControl,
        outlineVariant: AppColors.borde,
        surfaceContainerHighest: AppColors.superficieAlta,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge,
        headlineLarge: AppTypography.headlineLarge,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelLarge: AppTypography.labelLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.naranjaBoton,
          foregroundColor: AppColors.textoClaroAlto,
          disabledBackgroundColor: AppColors.superficieAlta,
          disabledForegroundColor: AppColors.textoTenue,
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.azulTexto),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textoClaroAlto,
          side: const BorderSide(color: AppColors.bordeControl),
          minimumSize: const Size(64, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textoTenue),
        labelStyle: AppTypography.bodyMedium,
        helperStyle: AppTypography.caption,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.superficie,
        selectedColor: AppColors.azulControl,
        side: const BorderSide(color: AppColors.bordeControl),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textoClaroAlto),
        secondaryLabelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textoClaroAlto),
        checkmarkColor: AppColors.textoClaroAlto,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.superficieAlta,
        contentTextStyle: TextStyle(color: AppColors.textoClaroAlto),
        actionTextColor: AppColors.azulTexto,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borde),
    );
  }
}

// ============================================================
// VOZ — SISTEMA DE COMUNICACIÓN
// ============================================================

/// Guía de tono y voz para textos de UI.
///
/// La app tiene DOS audiencias con estilos distintos:
///
/// 1. OPERACIÓN (mesero, cocina, cajero)
///    - Tono: cercano, directo
///    - Formato: corto, tipo comando
///    - Ejemplos válidos:
///        "Nueva orden"
///        "Enviar a cocina"
///        "Cobrar"
///        "Lista"
///        "Mesa 4"
///    - Evitar: frases largas, jerga técnica, gerundios pasivos.
///
/// 2. ANÁLISIS (gerente / dueño)
///    - Tono: profesional, analítico
///    - Formato: claro, sin tecnicismos pesados
///    - Ejemplos válidos:
///        "Ventas del día"
///        "Ganancia estimada"
///        "Inventario bajo"
///        "Diferencia en caja"
///    - Evitar: lenguaje infantil, abreviaturas, slang.
///
/// Regla general: si el usuario está EJECUTANDO una acción, usa OPERACIÓN.
/// Si está REVISANDO información, usa ANÁLISIS.
class AppVoice {
  AppVoice._();

  /// Marcadores opcionales para clasificar textos por audiencia.
  static const String operacion = 'operacion';
  static const String analisis = 'analisis';
}
