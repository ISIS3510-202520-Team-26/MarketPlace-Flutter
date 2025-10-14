import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';


class ImagesApi {
final _dio = DioClient.instance.dio;
Future<(String uploadUrl, String objectKey)> presign({required String listingId, required String filename, required String contentType}) async {
final res = await _dio.post('/images/presign', data: {
'listing_id': listingId,
'filename': filename,
'content_type': contentType,
});
final map = res.data as Map;
return (map['upload_url'] as String, map['object_key'] as String);
}
Future<void> putToPresigned(String url, List<int> bytes, {required String contentType}) async {
final dio = Dio(BaseOptions(headers: {'Content-Type': contentType}));
await dio.put(url, data: Stream.fromIterable([bytes]));
}
Future<String> confirm({required String listingId, required String objectKey}) async {
final res = await _dio.post('/images/confirm', data: {
'listing_id': listingId,
'object_key': objectKey,
});
return (res.data as Map)['preview_url'] as String;
}
}