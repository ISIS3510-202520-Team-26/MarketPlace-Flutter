import '../../core/net/dio_client.dart';
import '../../core/security/session_id.dart';


class TelemetryApi {
final _dio = DioClient.instance.dio;
Future<void> sendBatch(List<Map<String, dynamic>> events) async {
for (final e in events) { e['session_id'] ??= SessionId.instance.value; }
await _dio.post('/events', data: {'events': events});
}
}