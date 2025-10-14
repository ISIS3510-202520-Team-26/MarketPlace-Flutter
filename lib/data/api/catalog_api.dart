import '../../core/net/dio_client.dart';


class CatalogApi {
final _dio = DioClient.instance.dio;
Future<List<Map>> categories() async {
final res = await _dio.get('/categories');
return (res.data as List).cast<Map>();
}
Future<List<Map>> brands({String? categoryId}) async {
final res = await _dio.get('/brands', queryParameters: {'category_id': categoryId});
return (res.data as List).cast<Map>();
}
}