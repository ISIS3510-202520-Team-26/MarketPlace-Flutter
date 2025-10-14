import '../../core/net/dio_client.dart';

class CatalogApi {
  final _dio = DioClient.instance.dio;

  // Normaliza {items:[...]} o [...] a List<Map<String,dynamic>>
  List<Map<String, dynamic>> _normalizeList(dynamic data) {
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return <Map<String, dynamic>>[];
  }

  // Helpers
  String _slugify(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  // ---- Catálogo ----
  Future<List<Map<String, dynamic>>> categories() async {
    final res = await _dio.get('/categories');
    return _normalizeList(res.data);
  }

  Future<List<Map<String, dynamic>>> brands({String? categoryId}) async {
    final q = <String, dynamic>{};
    if (categoryId != null) q['category_id'] = categoryId; // si el back filtra, lo usará
    final res = await _dio.get('/brands', queryParameters: q);
    return _normalizeList(res.data);
  }

  Future<Map<String, dynamic>> createCategory({required String name}) async {
    final data = {'name': name, 'slug': _slugify(name)};
    final res = await _dio.post('/categories', data: data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  // 👇 Requiere categoryId: la marca se crea asociada a una categoría.
  Future<Map<String, dynamic>> createBrand({
    required String name,
    required String categoryId,
  }) async {
    final data = {
      'name': name,
      'slug': _slugify(name),
      'category_id': categoryId,
    };
    final res = await _dio.post('/brands', data: data);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
