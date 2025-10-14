import '../../core/net/dio_client.dart';


class DevicesApi {
final _dio = DioClient.instance.dio;
Future<void> register({required String pushToken, required String platform, required String appVersion}) async {
await _dio.post('/devices', data: {
'platform': platform,
'push_token': pushToken,
'app_version': appVersion,
});
}
}