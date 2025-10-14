import '../../core/net/dio_client.dart';


class ChatsApi {
final _dio = DioClient.instance.dio;
Future<Map> create(String listingId) async {
final res = await _dio.post('/chats', data: {'listing_id': listingId});
return res.data as Map;
}
Future<Map> getById(String chatId) async {
final res = await _dio.get('/chats/$chatId');
return res.data as Map;
}
}