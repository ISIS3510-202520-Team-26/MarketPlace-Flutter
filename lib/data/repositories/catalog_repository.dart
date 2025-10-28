import 'package:dio/dio.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/listing.dart';
import '../../core/net/dio_client.dart';

/// Repository para el dominio de Catálogo
/// 
/// Agrupa operaciones relacionadas con categorías, marcas y el catálogo completo.
/// Basado en los repositories y endpoints del backend.
class CatalogRepository {
  final Dio _dio = DioClient.instance.dio;

  // ==================== CATEGORIES ====================

  /// Obtiene todas las categorías
  /// 
  /// GET /categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      final data = response.data;
      
      // Normalizar respuesta (puede ser lista o {items: [...]}
      final List items;
      if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      
      return items
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener categorías');
    }
  }

  /// Crea una nueva categoría
  /// 
  /// POST /categories
  Future<Category> createCategory({
    required String name,
    String? slug,
  }) async {
    try {
      final payload = {
        'name': name,
        'slug': slug ?? _slugify(name),
      };
      
      final response = await _dio.post('/categories', data: payload);
      return Category.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al crear categoría');
    }
  }

  /// Obtiene una categoría por slug
  /// 
  /// GET /categories?slug={slug} (filtrado del lado cliente)
  Future<Category?> getCategoryBySlug(String slug) async {
    try {
      final categories = await getCategories();
      return categories.where((c) => c.slug == slug).firstOrNull;
    } catch (e) {
      throw 'Error al buscar categoría: $e';
    }
  }

  // ==================== BRANDS ====================

  /// Obtiene todas las marcas, opcionalmente filtradas por categoría
  /// 
  /// GET /brands?category_id={categoryId}
  Future<List<Brand>> getBrands({String? categoryId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }
      
      final response = await _dio.get('/brands', queryParameters: queryParams);
      final data = response.data;
      
      // Normalizar respuesta
      final List items;
      if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      
      return items
          .map((json) => Brand.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener marcas');
    }
  }

  /// Crea una nueva marca
  /// 
  /// POST /brands
  Future<Brand> createBrand({
    required String name,
    required String categoryId,
    String? slug,
  }) async {
    try {
      final payload = {
        'name': name,
        'slug': slug ?? _slugify(name),
        'category_id': categoryId,
      };
      
      final response = await _dio.post('/brands', data: payload);
      return Brand.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al crear marca');
    }
  }

  /// Obtiene una marca por slug
  /// 
  /// GET /brands?slug={slug} (filtrado del lado cliente)
  Future<Brand?> getBrandBySlug(String slug) async {
    try {
      final brands = await getBrands();
      return brands.where((b) => b.slug == slug).firstOrNull;
    } catch (e) {
      throw 'Error al buscar marca: $e';
    }
  }

  // ==================== CATALOG DELTA ====================

  /// Obtiene el catálogo completo con cambios incrementales
  /// 
  /// Este endpoint es útil para sincronización offline y cache.
  /// Retorna categorías, marcas y listings actualizados desde una fecha.
  /// 
  /// Headers opcionales:
  /// - If-None-Match: ETag para verificar si hay cambios
  /// 
  /// Query params:
  /// - since: ISO8601 timestamp para obtener solo cambios desde esa fecha
  /// - limit: Límite de listings a retornar (default: 200)
  Future<CatalogDelta> getCatalogDelta({
    DateTime? since,
    int? limit,
    String? etag,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null) {
        queryParams['since'] = since.toIso8601String();
      }
      if (limit != null) {
        queryParams['limit'] = limit;
      }
      
      final headers = <String, dynamic>{};
      if (etag != null) {
        headers['If-None-Match'] = etag;
      }
      
      final response = await _dio.get(
        '/catalog/delta',
        queryParameters: queryParams,
        options: Options(
          headers: headers,
          validateStatus: (status) {
            // 304 Not Modified es válido
            return status != null && (status == 200 || status == 304);
          },
        ),
      );
      
      // Si es 304, no hay cambios
      if (response.statusCode == 304) {
        return CatalogDelta.notModified(etag: etag);
      }
      
      final data = response.data as Map<String, dynamic>;
      final newEtag = response.headers.value('etag');
      final lastModified = response.headers.value('last-modified');
      
      return CatalogDelta.fromJson(
        data,
        etag: newEtag,
        lastModified: lastModified != null 
            ? DateTime.tryParse(lastModified) 
            : null,
      );
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener catálogo');
    }
  }

  // ==================== HELPERS ====================

  /// Convierte un string a slug (lowercase, guiones)
  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// Maneja errores de Dio y retorna un mensaje apropiado
  String _handleError(DioException e, String defaultMessage) {
    if (e.response != null) {
      final data = e.response!.data;
      
      // Intenta extraer mensaje de error del backend
      if (data is Map) {
        if (data['detail'] is String) {
          return data['detail'] as String;
        }
        if (data['message'] is String) {
          return data['message'] as String;
        }
      }
      
      return '$defaultMessage (${e.response!.statusCode})';
    }
    
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tiempo de espera agotado';
    }
    
    if (e.type == DioExceptionType.connectionError) {
      return 'Error de conexión';
    }
    
    return '$defaultMessage: ${e.message}';
  }
}

/// Modelo para la respuesta del endpoint /catalog/delta
/// 
/// Contiene categorías, marcas y listings actualizados.
class CatalogDelta {
  final List<Category> categories;
  final List<Brand> brands;
  final List<Listing> listings;
  final String? etag;
  final DateTime? lastModified;
  final bool isModified;

  const CatalogDelta({
    required this.categories,
    required this.brands,
    required this.listings,
    this.etag,
    this.lastModified,
    this.isModified = true,
  });

  /// Crea una respuesta 304 Not Modified
  factory CatalogDelta.notModified({String? etag}) {
    return CatalogDelta(
      categories: const [],
      brands: const [],
      listings: const [],
      etag: etag,
      isModified: false,
    );
  }

  /// Crea desde JSON del backend
  factory CatalogDelta.fromJson(
    Map<String, dynamic> json, {
    String? etag,
    DateTime? lastModified,
  }) {
    final categories = (json['categories'] as List<dynamic>?)
        ?.map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList() ?? [];
    
    final brands = (json['brands'] as List<dynamic>?)
        ?.map((b) => Brand.fromJson(b as Map<String, dynamic>))
        .toList() ?? [];
    
    final listings = (json['listings'] as List<dynamic>?)
        ?.map((l) => Listing.fromJson(l as Map<String, dynamic>))
        .toList() ?? [];
    
    return CatalogDelta(
      categories: categories,
      brands: brands,
      listings: listings,
      etag: etag,
      lastModified: lastModified,
      isModified: true,
    );
  }

  /// Verifica si el catálogo tiene datos
  bool get hasData => 
      categories.isNotEmpty || brands.isNotEmpty || listings.isNotEmpty;
  
  /// Obtiene el total de items
  int get totalItems => categories.length + brands.length + listings.length;
}
