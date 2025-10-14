import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';
import '../../core/security/token_storage.dart';


class AuthApi {
final _dio = DioClient.instance.dio;
Future<void> register({required String name, required String email, required String password, String? campus}) async {
await _dio.post('/auth/register', data: {
'name': name, 'email': email, 'password': password, 'campus': campus,
});
}
Future<void> login({required String email, required String password}) async {
final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
final map = res.data as Map;
await TokenStorage.instance.saveTokens(map['access_token'], map['refresh_token']);
}
Future<Map> me() async {
final res = await _dio.get('/auth/me');
return res.data as Map;
}
}