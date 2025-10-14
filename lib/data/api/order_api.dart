import '../../core/net/dio_client.dart';


class OrdersApi {
final _dio = DioClient.instance.dio;
Future<Map> create({required String listingId, required int totalCents, String currency = 'COP'}) async {
final res = await _dio.post('/orders', data: {
'listing_id': listingId,
'total_cents': totalCents,
'currency': currency,
});
return res.data as Map;
}
Future<void> pay(String orderId) async { await _dio.post('/orders/$orderId/pay'); }
Future<void> capture() async { await _dio.post('/payments/capture'); }
Future<void> complete(String orderId) async { await _dio.post('/orders/$orderId/complete'); }
}