// lib/data/api/images_api.dart
import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';

class ImagesApi {
  final _dio = DioClient.instance.dio;

  /// Pide una URL presignada para subir una foto de un listing.
  /// Devuelve (uploadUrl, objectKey).
  Future<(String uploadUrl, String objectKey)> presign({
    required String listingId,
    required String filename,
    required String contentType,
  }) async {
    final res = await _dio.post('/images/presign', data: {
      'listing_id': listingId,
      'filename': filename,
      'content_type': contentType,
    });

    final map = res.data as Map;
    var url = map['upload_url'] as String;
    final key = map['object_key'] as String;

    // En Android (emulador), si el backend firma contra 'http://minio:9000'
    // esa URL no es accesible desde el emulador. Reescribimos el host a 10.0.2.2.
    // ⚠️ Lo ideal es que el backend firme usando un "endpoint público" alcanzable
    // (p.ej. http://10.0.2.2:9000) para evitar desajustes de firma.
    if (Platform.isAndroid) {
      url = _fixPresignedUrlForAndroid(url);
    }

    return (url, key);
  }

  /// Sube los bytes a la URL presignada con PUT.
  /// Acepta 200/204 como válidos.
  Future<void> putToPresigned(
    String url,
    List<int> bytes, {
    required String contentType,
  }) async {
    // Usamos un Dio temporal sin interceptores para evitar cabeceras de auth, etc.
    final dio = Dio(BaseOptions(
      headers: {'Content-Type': contentType},
      followRedirects: true,
      // Opcional: aumenta tiempo de subida para archivos grandes
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(minutes: 2),
    ));

    final resp = await dio.put(
      url,
      data: bytes,
      options: Options(
        // Algunas presign devuelven 200 OK, otras 204 No Content
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    // Si quieres log/validación extra:
    // if (resp.statusCode == 204 || resp.statusCode == 200) { ... }
  }

  /// Confirma la subida en el backend para que guarde metadata y relacione la foto al listing.
  /// Devuelve una 'preview_url' (string) para mostrar la imagen.
  Future<String> confirm({
    required String listingId,
    required String objectKey,
  }) async {
    final res = await _dio.post('/images/confirm', data: {
      'listing_id': listingId,
      'object_key': objectKey,
    });
    return (res.data as Map)['preview_url'] as String;
  }

  /// Reescribe host de MinIO interno a 10.0.2.2 para el emulador Android.
  /// Conserva esquema y puerto; no toca el path ni la query (firma).
  String _fixPresignedUrlForAndroid(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Hosts internos típicos usados en docker-compose/k8s
      const internalHosts = {
        'minio',
        'minio.local',
        'minio-svc',
        'minio.default.svc.cluster.local',
      };

      if (internalHosts.contains(host)) {
        // Reemplaza solo el host; mantiene esquema/puerto/path/query/fragments
        final fixed = uri.replace(host: '10.0.2.2');
        return fixed.toString();
      }
      return url;
    } catch (_) {
      // Si por alguna razón no se pudo parsear, deja la URL intacta.
      return url;
    }
  }

    Future<String> preview(String objectKey) async {
    final res = await _dio.get('/images/preview', queryParameters: {
      'object_key': objectKey,
    });
    return (res.data as Map)['preview_url'] as String;
  }
}
