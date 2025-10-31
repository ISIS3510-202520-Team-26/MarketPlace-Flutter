// lib/core/utils/input_formatters.dart
import 'package:flutter/services.dart';

/// Formatter que previene más de 3 caracteres especiales consecutivos
class NoConsecutiveSpecialCharsFormatter extends TextInputFormatter {
  final int maxConsecutive;

  NoConsecutiveSpecialCharsFormatter({this.maxConsecutive = 3});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Si el texto está vacío o es muy corto, permitir
    if (text.length <= maxConsecutive) {
      return newValue;
    }

    // Verificar si hay más de maxConsecutive caracteres especiales consecutivos
    if (_hasConsecutiveSpecialChars(text, maxConsecutive)) {
      // Rechazar el cambio, mantener el valor anterior
      return oldValue;
    }

    return newValue;
  }

  /// Verifica si hay más de [max] caracteres especiales consecutivos
  bool _hasConsecutiveSpecialChars(String text, int max) {
    int consecutiveCount = 0;
    
    for (int i = 0; i < text.length; i++) {
      if (_isSpecialChar(text[i])) {
        consecutiveCount++;
        if (consecutiveCount > max) {
          return true;
        }
      } else {
        consecutiveCount = 0;
      }
    }
    
    return false;
  }

  /// Define qué se considera un carácter especial
  /// Incluye símbolos comunes pero excluye letras, números y espacios
  bool _isSpecialChar(String char) {
    // Expresión regular que coincide con cualquier carácter que NO sea:
    // - Letra (a-z, A-Z, incluye acentos y ñ)
    // - Número (0-9)
    // - Espacio
    // - Arroba @ (común en emails)
    // - Punto . (común en emails y dominios)
    final specialChars = RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ0-9\s@.]');
    return specialChars.hasMatch(char);
  }
}
