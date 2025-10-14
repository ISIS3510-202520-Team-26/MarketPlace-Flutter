import '../../core/net/dio_client.dart';


class MessagesApi {
final _dio = DioClient.instance.dio;
Future<Map> send({required String chatId, required String content}) async {
final res = await _dio.post('/messages', data: {
'chat_id': chatId,
'message_type': 'text',
'content': content,
});
return res.data as Map;
}
}