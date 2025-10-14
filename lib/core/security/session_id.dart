// lib/core/security/session_id.dart
import 'dart:math';
import 'dart:convert';

class SessionId {
  SessionId._();
  static final SessionId instance = SessionId._();

  String? _value;

  /// Asegura que exista un session_id y lo devuelve.
  Future<String> ensure() async => _value ??= _randomId();

  /// Devuelve el session_id actual (asegúrate de llamar a ensure() antes).
  String get value => _value ??= _randomId();

  String _randomId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', ''); // corto y URL-safe
  }

  /// Permite “resetear” en casos especiales (tests, debugging).
  void reset() => _value = null;
}
