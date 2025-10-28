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
final path = err.requestOptions.path;
final isAuthEndpoint = path.contains('/auth/');

// NO intentar refresh en endpoints de auth (login, register, refresh)
if (is401 && isAuthEndpoint) {
print('[AuthInterceptor] 401 en endpoint de auth ($path), limpiando sesión');
await _storage.clear();
return handler.next(err);
}

// Solo hacer refresh si:
// 1. Es 401
// 2. NO es un endpoint de auth
// 3. NO estamos ya refrescando
// 4. Hay un refresh token guardado
if (is401 && !isAuthEndpoint && !_refreshing) {
final refresh = await _storage.readRefreshToken();
if (refresh == null) {
print('[AuthInterceptor] 401 pero sin refresh token, limpiando sesión');
await _storage.clear();
return handler.next(err);
}

try {
_refreshing = true;
print('[AuthInterceptor] Token expirado en $path, intentando refresh...');

final res = await _dio.post('/auth/refresh', data: { 'refresh_token': refresh });
final data = res.data as Map;

print('[AuthInterceptor] Nuevos tokens recibidos, guardando...');
await _storage.saveTokens(data['access_token'], data['refresh_token']);

// Reintenta la request original con nuevo token
print('[AuthInterceptor] Reintentando request original con nuevo token...');
final cloned = await _dio.fetch(
err.requestOptions..headers['Authorization'] = 'Bearer ${data['access_token']}'
);

print('[AuthInterceptor] Request exitosa tras refresh');
return handler.resolve(cloned);
} catch (refreshErr) {
print('[AuthInterceptor] Error en refresh: $refreshErr');
await _storage.clear();
return handler.next(err);
} finally {
_refreshing = false;
}
}

handler.next(err);
}
}