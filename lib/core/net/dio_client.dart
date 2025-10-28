import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import '../../env/env.dart';
import '../security/token_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/logging_interceptor.dart';


class DioClient {
DioClient._();
static final DioClient instance = DioClient._();
late Dio dio;


Future<void> init({required String cachePath}) async {
final options = BaseOptions(
baseUrl: Env.baseUrl,
connectTimeout: const Duration(seconds: 30), // Aumentado para AWS
receiveTimeout: const Duration(seconds: 30),
headers: {'Accept': 'application/json'},
validateStatus: (status) => status != null && status < 500, // Aceptar errores 4xx
);


dio = Dio(options);


final cacheStore = HiveCacheStore(cachePath);
final cacheOptions = CacheOptions(
store: cacheStore,
policy: CachePolicy.request,
hitCacheOnErrorExcept: [401, 403],
priority: CachePriority.normal,
maxStale: const Duration(days: 7),
keyBuilder: CacheOptions.defaultCacheKeyBuilder,
);


dio.interceptors.addAll([
AuthInterceptor(dio, TokenStorage.instance),
RetryOnNetworkErrorInterceptor(dio, retries: 2),
CacheingInterceptor(cacheOptions),
if (Env.enableLogs) LoggingInterceptor(),
]);
}
}