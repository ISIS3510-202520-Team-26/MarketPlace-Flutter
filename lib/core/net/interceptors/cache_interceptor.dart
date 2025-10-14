import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';


class CacheingInterceptor extends Interceptor {
CacheingInterceptor(this.options);
final CacheOptions options;
@override
void onRequest(RequestOptions opts, RequestInterceptorHandler h) {
if (opts.method.toUpperCase() == 'GET') {
opts.extra.addAll(options.toExtra());
}
h.next(opts);
}
}