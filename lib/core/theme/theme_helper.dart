import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Helper para acceder fácilmente a los colores del tema desde cualquier widget
/// 
/// Uso:
/// ```dart
/// final theme = ThemeHelper.of(context);
/// Container(color: theme.primary)
/// Text('Hola', style: TextStyle(color: theme.textDark))
/// ```
class ThemeHelper {
  final BuildContext context;
  
  ThemeHelper.of(this.context);
  
  // Acceso rápido a AppColors
  AppColors get colors => Theme.of(context).extension<AppColors>()!;
  
  // Acceso rápido a colores individuales
  Color get primary => colors.primary;
  Color get primaryLight => colors.primaryLight;
  Color get primaryDark => colors.primaryDark;
  Color get cardBg => colors.cardBg;
  Color get scaffoldBg => colors.scaffoldBg;
  Color get textGray => colors.textGray;
  Color get textDark => colors.textDark;
  
  // Acceso al TextTheme
  TextTheme get textTheme => Theme.of(context).textTheme;
  
  // Verificar si está en modo oscuro
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  
  // Acceso a tamaños de texto específicos (considerando fontScale)
  TextStyle get displayLarge => textTheme.displayLarge!;
  TextStyle get displayMedium => textTheme.displayMedium!;
  TextStyle get displaySmall => textTheme.displaySmall!;
  TextStyle get headlineMedium => textTheme.headlineMedium!;
  TextStyle get titleLarge => textTheme.titleLarge!;
  TextStyle get titleMedium => textTheme.titleMedium!;
  TextStyle get bodyLarge => textTheme.bodyLarge!;
  TextStyle get bodyMedium => textTheme.bodyMedium!;
  TextStyle get labelLarge => textTheme.labelLarge!;
}

/// Extension para acceder más fácilmente al ThemeHelper
extension ThemeContextExtension on BuildContext {
  /// Acceso rápido a ThemeHelper
  /// 
  /// Ejemplo: `context.theme.primary`
  ThemeHelper get theme => ThemeHelper.of(this);
  
  /// Acceso directo a AppColors
  /// 
  /// Ejemplo: `context.colors.cardBg`
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
