import 'package:dio/dio.dart';


class LoggingInterceptor extends Interceptor {
@override
void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
// Minimal para no saturar
// print('[REQ] ${options.method} ${options.uri}');
handler.next(options);
}
@override
void onResponse(Response response, ResponseInterceptorHandler handler) {
// print('[RES] ${response.statusCode} ${response.requestOptions.uri}');
handler.next(response);
}
}