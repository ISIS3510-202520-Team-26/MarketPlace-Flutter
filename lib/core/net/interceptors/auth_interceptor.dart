import 'package:dio/dio.dart';
import '../../security/token_storage.dart';


class AuthInterceptor extends Interceptor {
AuthInterceptor(this._dio, this._storage);
final Dio _dio;
final TokenStorage _storage;
bool _refreshing = false;


@override
void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
final access = await _storage.readAccessToken();
if (access != null && options.headers['Authorization'] == null) {
options.headers['Authorization'] = 'Bearer $access';
}
handler.next(options);
}


@override
void onError(DioException err, ErrorInterceptorHandler handler) async {
final is401 = err.response?.statusCode == 401;
final isRefresh = err.requestOptions.path.endsWith('/auth/refresh');
if (is401 && !isRefresh && !_refreshing) {
try {
_refreshing = true;
final refresh = await _storage.readRefreshToken();
if (refresh == null) return handler.next(err);
final res = await _dio.post('/auth/refresh', data: { 'refresh_token': refresh });
final data = res.data as Map;
await _storage.saveTokens(data['access_token'], data['refresh_token']);
// Reintenta la request original con nuevo token
final cloned = await _dio.fetch(err.requestOptions..headers['Authorization'] = 'Bearer ${data['access_token']}');
return handler.resolve(cloned);
} catch (_) {
await _storage.clear();
return handler.next(err);
} finally {
_refreshing = false;
}
}
handler.next(err);
}
}