import '../../core/net/dio_client.dart';


class ListingsApi {
final _dio = DioClient.instance.dio;
Future<List<Map>> list({double? lat, double? lon, double? radiusKm}) async {
final q = <String, dynamic>{};
if (lat != null && lon != null) { q['near_lat'] = lat; q['near_lon'] = lon; }
if (radiusKm != null) q['radius_km'] = radiusKm;
final res = await _dio.get('/listings', queryParameters: q);
return (res.data['items'] as List).cast<Map>();
}
Future<Map> create(Map payload) async {
final res = await _dio.post('/listings', data: payload);
return res.data as Map;
}
}