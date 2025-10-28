import 'dart:async';
import 'package:dio/dio.dart';


class RetryOnNetworkErrorInterceptor extends Interceptor {
RetryOnNetworkErrorInterceptor(this._dio, {this.retries = 2});
final Dio _dio;
final int retries;
static const _kAttempts = '__retry_attempts';


@override
void onError(DioException err, ErrorInterceptorHandler handler) async {
final req = err.requestOptions;
final attempt = (req.extra[_kAttempts] as int? ?? 0);


// Consideramos errores transitorios de red/timeout
final transient = err.type == DioExceptionType.connectionTimeout ||
err.type == DioExceptionType.receiveTimeout ||
err.type == DioExceptionType.sendTimeout ||
err.type == DioExceptionType.connectionError;


// Si ya cancelaron la request, no reintentar
final cancelled = req.cancelToken?.isCancelled == true;

// Log para debugging
print('[RetryInterceptor] ${req.method} ${req.uri}');
print('  Error: ${err.type}, intento: ${attempt + 1}/$retries');
print('  Transitorio: $transient, Cancelado: $cancelled');


if (!transient || cancelled || attempt >= retries) {
return handler.next(err);
}


// Incrementa contador y calcula backoff exponencial simple: 200ms, 400ms, 800ms...
req.extra[_kAttempts] = attempt + 1;
final delay = Duration(milliseconds: 200 << attempt);
await Future.delayed(delay);


try {
// Reintenta usando el MISMO Dio (con baseUrl/interceptores)
final Response res = await _dio.fetch(req);
return handler.resolve(res);
} catch (_) {
return handler.next(err);
}
}
}