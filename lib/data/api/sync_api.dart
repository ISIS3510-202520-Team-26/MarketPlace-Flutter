import '../../core/net/dio_client.dart';


class SyncApi {
final _dio = DioClient.instance.dio;
Future<Map> delta(String? sinceIso) async {
final res = await _dio.get('/sync/delta', queryParameters: {'since': sinceIso});
return res.data as Map;
}
}