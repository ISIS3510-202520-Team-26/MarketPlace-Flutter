import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';
import '../../core/security/token_storage.dart';

class AuthApi {
  final _dio = DioClient.instance.dio;

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? campus,
  }) async {
    try {
      await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        if (campus != null && campus.trim().isNotEmpty) 'campus': campus,
      });
    } on DioException catch (e) {
      // Propagamos el mensaje del backend si viene 422 u otros
      final msg = _extractErrMsg(e) ?? 'Registro falló (${e.response?.statusCode ?? ''})';
      throw msg;
    } catch (e) {
      throw 'Registro falló: $e';
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final map = res.data as Map;
      await TokenStorage.instance.saveTokens(
        map['access_token'],
        map['refresh_token'],
      );
    } on DioException catch (e) {
      final msg = _extractErrMsg(e) ?? 'Login falló (${e.response?.statusCode ?? ''})';
      throw msg;
    } catch (e) {
      throw 'Login falló: $e';
    }
  }

  // Utilidad para sacar mensajes legibles de errores de validación
  String? _extractErrMsg(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      if (data['detail'] is List) {
        try {
          final parts = (data['detail'] as List)
              .map((it) => it is Map && it['msg'] != null ? it['msg'].toString() : it.toString())
              .toList();
          if (parts.isNotEmpty) return 'Datos inválidos:\n${parts.join('\n')}';
        } catch (_) {}
      }
      if (data['message'] is String) return data['message'] as String;
    }
    return null;
  }
}
