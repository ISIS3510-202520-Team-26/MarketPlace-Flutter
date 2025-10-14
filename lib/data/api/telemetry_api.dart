// lib/data/api/telemetry_api.dart
import '../../core/net/dio_client.dart';
import '../../core/security/session_id.dart';

class TelemetryApi {
  final _dio = DioClient.instance.dio;

  Future<void> sendBatch(List<Map<String, dynamic>> events) async {
    final sid = await SessionId.instance.ensure();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = {
      'events': events.map((e) {
        final m = Map<String, dynamic>.from(e);
        m['session_id'] ??= sid;
        // opcional para el backend; útil para colas locales
        m['occurred_at'] ??= nowIso;
        return m;
      }).toList(),
    };

    // Ojo: usa '/v1/events' solo si tu DioClient no ya tiene el prefijo /v1
    await _dio.post('/events', data: payload);
  }
}
