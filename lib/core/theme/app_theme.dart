import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extension de tema para colores personalizados
/// 
/// Permite acceder a colores custom desde cualquier widget usando:
/// Theme.of(context).extension<AppColors>()!.cardBg
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color cardBg;
  final Color scaffoldBg;
  final Color textGray;
  final Color textDark;
  
  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.cardBg,
    required this.scaffoldBg,
    required this.textGray,
    required this.textDark,
  });
  
  // Colores para tema claro
  static const light = AppColors(
    primary: Color(0xFF0F6E5D),
    primaryLight: Color(0xFF1A8A75),
    primaryDark: Color(0xFF0A5246),
    cardBg: Color(0xFFF7F8FA),
    scaffoldBg: Color(0xFFFAFBFC),
    textGray: Color(0xFF6B7280),
    textDark: Color(0xFF1F2937),
  );
  
  // Colores para tema oscuro
  static const dark = AppColors(
    primary: Color(0xFF1A8A75),
    primaryLight: Color(0xFF22A88F),
    primaryDark: Color(0xFF0F6E5D),
    cardBg: Color(0xFF1E1E1E),
    scaffoldBg: Color(0xFF121212),
    textGray: Color(0xFFB0B0B0),
    textDark: Color(0xFFE0E0E0),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? cardBg,
    Color? scaffoldBg,
    Color? textGray,
    Color? textDark,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      cardBg: cardBg ?? this.cardBg,
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      textGray: textGray ?? this.textGray,
      textDark: textDark ?? this.textDark,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      textGray: Color.lerp(textGray, other.textGray, t)!,
      textDark: Color.lerp(textDark, other.textDark, t)!,
    );
  }
}

/// Tema y estilos mejorados de la aplicación
class AppTheme {
  // Colores principales (manteniendo por compatibilidad - usar ThemeExtension en nuevo código)
  static const primary = Color(0xFF0F6E5D);
  static const primaryLight = Color(0xFF1A8A75);
  static const primaryDark = Color(0xFF0A5246);
  
  static const cardBg = Color(0xFFF7F8FA);
  static const scaffoldBg = Color(0xFFFAFBFC);
  static const textGray = Color(0xFF6B7280);
  static const textDark = Color(0xFF1F2937);
  
  // Gradientes modernos
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF0F6E5D), Color(0xFF1A8A75)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const cardGradient = LinearGradient(
    colors: [Color(0xFFFAFBFC), Color(0xFFF7F8FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Sombras mejoradas
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: primary.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  // Border radius consistente
  static const radiusSmall = 8.0;
  static const radiusMedium = 12.0;
  static const radiusLarge = 16.0;
  static const radiusXLarge = 24.0;

  /// Tema principal de la app con soporte para fontSize dinámico
  static ThemeData light({double fontScale = 1.0, bool isDark = false}) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final colors = isDark ? AppColors.dark : AppColors.light;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
        primary: colors.primary,
        secondary: colors.primaryLight,
        surface: colors.cardBg,
        onSurface: colors.textDark,
      ),
      scaffoldBackgroundColor: colors.scaffoldBg,
      
      // Agregar colores custom como extension
      extensions: [colors],
      
      // Tipografía con Google Fonts y escala dinámica
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32 * fontScale,
          fontWeight: FontWeight.w800,
          color: colors.textDark,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28 * fontScale,
          fontWeight: FontWeight.w700,
          color: colors.textDark,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24 * fontScale,
          fontWeight: FontWeight.w700,
          color: colors.textDark,
          letterSpacing: -0.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w600,
          color: colors.textDark,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18 * fontScale,
          fontWeight: FontWeight.w600,
          color: colors.textDark,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16 * fontScale,
          fontWeight: FontWeight.w600,
          color: colors.textDark,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16 * fontScale,
          fontWeight: FontWeight.w400,
          color: colors.textDark,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.w400,
          color: colors.textDark,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.w600,
          color: colors.textDark,
        ),
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: colors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 24 * fontScale,
          fontWeight: FontWeight.w800,
          color: colors.primary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: colors.primary),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        color: colors.cardBg,
        shadowColor: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
      ),
      
      // ElevatedButton theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15 * fontScale,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(
          color: colors.textGray,
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.w400,
        ),
      ),
      
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: colors.cardBg,
        selectedColor: colors.primary.withOpacity(0.1),
        labelStyle: GoogleFonts.inter(
          fontSize: 13 * fontScale,
          fontWeight: FontWeight.w500,
          color: colors.textDark,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
    );
  }
}

/// Widgets reutilizables con mejor estética
class StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool elevated;

  const StyledCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: elevated ? AppTheme.elevatedShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Botón circular mejorado para iconos
class StyledIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? badge;

  const StyledIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.cardBg,
            shape: BoxShape.circle,
            boxShadow: AppTheme.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                color: color ?? colors.primary,
                size: 22,
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -4,
            top: -4,
            child: badge!,
          ),
      ],
    );
  }
}

/// Badge para notificaciones
class NotificationBadge extends StatelessWidget {
  final int count;

  const NotificationBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}