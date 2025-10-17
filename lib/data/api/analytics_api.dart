// lib/data/api/analytics_api.dart
import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';

class AnalyticsApi {
  final Dio _dio = DioClient.instance.dio;

  Map<String, String> _rangeTodayUtc() {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    String iso(DateTime d) => d.toIso8601String().replaceFirst(RegExp(r'\.\d+'), '') + 'Z';
    return {'start': iso(start), 'end': iso(end)};
  }

  Future<List<Map<String, dynamic>>> bq21EventsByTypeToday() async {
    final q = _rangeTodayUtc();
    final r = await _dio.get('/analytics/bq/2_1', queryParameters: q);
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> bq22ClicksByButtonToday() async {
    final q = _rangeTodayUtc();
    final r = await _dio.get('/analytics/bq/2_2', queryParameters: q);
    return (r.data as List).cast<Map<String, dynamic>>();
  }

    Future<List<Map<String, dynamic>>> bq24DwellByScreenToday() async {
    final q = _rangeTodayUtc();
    final r = await _dio.get('/analytics/bq/2_4', queryParameters: q);
    return (r.data as List).cast<Map<String, dynamic>>();
  }
}
