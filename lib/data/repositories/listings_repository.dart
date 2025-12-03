import 'package:dio/dio.dart';
import '../models/listing.dart';
import '../models/listing_photo.dart';
import '../models/price_suggestion.dart';
import '../../core/net/dio_client.dart';
import 'auth_repository.dart';

/// Repository para el dominio de Listings
/// 
/// Agrupa operaciones relacionadas con publicaciones (listings) y sus fotos.
/// Incluye búsqueda, filtros, geolocalización y manejo de imágenes.
/// Basado en los repositories y endpoints del backend.
class ListingsRepository {
  final Dio _dio = DioClient.instance.dio;

  // ==================== LISTINGS CRUD ====================

  /// Crea un nuevo listing
  /// 
  /// POST /listings
  Future<Listing> createListing(Listing listing) async {
    try {
      final response = await _dio.post('/listings', data: listing.toJson());
      return Listing.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al crear listing');
    }
  }

  /// Obtiene un listing por ID
  /// 
  /// GET /listings/{id}
  Future<Listing> getListingById(String id) async {
    try {
      final response = await _dio.get('/listings/$id');
      return Listing.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener listing');
    }
  }

  /// Actualiza un listing
  /// 
  /// PATCH /listings/{id}
  Future<Listing> updateListing(String id, Listing listing) async {
    try {
      final response = await _dio.patch(
        '/listings/$id',
        data: listing.toUpdateJson(),
      );
      return Listing.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al actualizar listing');
    }
  }

  /// Elimina un listing
  /// 
  /// DELETE /listings/{id}
  Future<void> deleteListing(String id) async {
    try {
      await _dio.delete('/listings/$id');
    } on DioException catch (e) {
      throw _handleError(e, 'Error al eliminar listing');
    }
  }

  // ==================== SEARCH & FILTERS ====================

  /// Busca listings con filtros y paginación
  /// 
  /// GET /listings?q=...&category_id=...&page=...
  /// 
  /// Soporta:
  /// - Búsqueda por texto (q)
  /// - Filtro por categoría
  /// - Filtro por marca
  /// - Filtro por vendedor (seller_id)
  /// - Rango de precios
  /// - Búsqueda geográfica (near_lat, near_lon, radius_km)
  /// - Paginación
  Future<ListingsPage> searchListings({
    String? q,
    String? categoryId,
    String? brandId,
    String? sellerId,
    int? minPrice,
    int? maxPrice,
    double? nearLat,
    double? nearLon,
    double? radiusKm,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      
      if (q != null && q.isNotEmpty) queryParams['q'] = q;
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (brandId != null) queryParams['brand_id'] = brandId;
      if (sellerId != null) queryParams['seller_id'] = sellerId;
      if (minPrice != null) queryParams['min_price'] = minPrice;
      if (maxPrice != null) queryParams['max_price'] = maxPrice;
      if (nearLat != null) queryParams['near_lat'] = nearLat;
      if (nearLon != null) queryParams['near_lon'] = nearLon;
      if (radiusKm != null) queryParams['radius_km'] = radiusKm;
      
      final response = await _dio.get(
        '/listings',
        queryParameters: queryParams,
      );
      
      return ListingsPage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al buscar listings');
    }
  }

  /// Obtiene listings cercanos a una ubicación
  /// 
  /// Usa el endpoint de búsqueda con filtros geográficos
  Future<List<Listing>> getListingsNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int limit = 50,
  }) async {
    try {
      final result = await searchListings(
        nearLat: latitude,
        nearLon: longitude,
        radiusKm: radiusKm,
        pageSize: limit,
      );
      
      return result.items;
    } catch (e) {
      throw 'Error al obtener listings cercanos: $e';
    }
  }

  // ==================== USER STATISTICS ====================

  /// Obtiene las estadísticas del usuario actual (sus listings)
  /// 
  /// Retorna información sobre:
  /// - Lista completa de listings del usuario
  /// - Conteo de listings activos
  /// - Conteo de listings vendidos (orders completadas)
  /// - Valor total de listings
  /// - Vistas totales (simulado por ahora)
  Future<UserStatsData> getUserStats() async {
    try {
      print('[ListingsRepo] 📊 Obteniendo estadísticas del usuario...');
      
      // Obtener todos los listings del usuario actual
      // Usa getMyListings que filtra automáticamente por seller_id
      final result = await getMyListings(
        page: 1,
        pageSize: 100, // Obtener hasta 100 listings
      );
      
      print('[ListingsRepo] Se obtuvieron ${result.items.length} listings del usuario');
      
      // Filtrar listings activos
      final activeListings = result.items.where((l) => l.isActive).toList();
      
      // Por ahora, simular "vendidos" como listings inactivos
      // En el futuro, esto vendría de una consulta a órdenes completadas
      final soldListings = result.items.where((l) => !l.isActive).toList();
      
      // Calcular valor total (suma de precios de todos los listings)
      final totalValue = result.items.fold<int>(
        0,
        (sum, listing) => sum + listing.priceCents,
      );
      
      // Simular vistas por ahora (en producción vendría de analytics)
      final viewsCount = result.items.length * 15 + DateTime.now().millisecond % 50;
      
      print('[ListingsRepo] 📈 Estadísticas:');
      print('  Total: ${result.items.length}');
      print('  Activos: ${activeListings.length}');
      print('  Vendidos: ${soldListings.length}');
      print('  Valor total: \$${(totalValue / 100).toStringAsFixed(0)}');
      print('  Vistas: $viewsCount');
      
      return UserStatsData(
        myListings: result.items,
        activeCount: activeListings.length,
        soldCount: soldListings.length,
        totalValue: totalValue,
        viewsCount: viewsCount,
      );
    } on DioException catch (e) {
      print('[ListingsRepo] Error al obtener estadísticas: ${e.message}');
      throw _handleError(e, 'Error al obtener estadísticas del usuario');
    }
  }

  /// Obtiene todos los listings del usuario actual
  /// 
  /// GET /listings?seller_id={current_user_id}
  /// 
  /// Filtra las publicaciones por el seller_id del usuario autenticado
  Future<ListingsPage> getMyListings({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      print('[ListingsRepo] Obteniendo mis publicaciones (página $page)...');
      
      // Obtener el ID del usuario autenticado
      final authRepo = AuthRepository();
      final currentUser = await authRepo.getCurrentUser();
      
      print('[ListingsRepo] Usuario actual: ${currentUser.id} (${currentUser.name})');
      
      // Buscar listings filtrando por seller_id del usuario actual
      final result = await searchListings(
        sellerId: currentUser.id,
        page: page,
        pageSize: pageSize,
      );
      
      print('[ListingsRepo] Se obtuvieron ${result.items.length} publicaciones del usuario');
      
      // Verificación adicional: filtrar localmente por si el backend no soporta seller_id
      final myListings = result.items.where((listing) {
        return listing.sellerId == currentUser.id;
      }).toList();
      
      if (myListings.length != result.items.length) {
        print('[ListingsRepo] Filtrado local: ${result.items.length} -> ${myListings.length} publicaciones');
      }
      
      return ListingsPage(
        items: myListings,
        total: myListings.length,
        page: result.page,
        pageSize: result.pageSize,
        hasNext: myListings.length >= pageSize,
      );
    } on DioException catch (e) {
      print('[ListingsRepo] Error al obtener mis publicaciones: ${e.message}');
      throw _handleError(e, 'Error al obtener mis publicaciones');
    }
  }

  // ==================== PRICE SUGGESTIONS ====================

  /// Obtiene sugerencia de precio para un listing
  /// 
  /// Soporta múltiples estrategias:
  /// - local_median: mediana de listings similares (últimos 90 días)
  /// - prior_only: priors basados en categoría/marca
  /// - prior+local_mix: mezcla ponderada de priors + datos locales
  /// - msrp_heuristic: depreciación desde MSRP
  /// - hardcoded_fallback: valor por defecto
  /// 
  /// Retorna PriceSuggestion con precio sugerido + metadatos (p25/p50/p75/n/source)
  Future<PriceSuggestion?> suggestPrice({
    required String categoryId,
    String? brandId,
    String? condition,
    int? msrpCents,
    int? monthsSinceRelease,
    int? roundingQuantum,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'category_id': categoryId,
      };
      if (brandId != null) queryParams['brand_id'] = brandId;
      if (condition != null) queryParams['condition'] = condition;
      if (msrpCents != null) queryParams['msrp_cents'] = msrpCents;
      if (monthsSinceRelease != null) queryParams['months_since_release'] = monthsSinceRelease;
      if (roundingQuantum != null) queryParams['rounding_quantum'] = roundingQuantum;
      
      print('[ListingsRepo] Solicitando sugerencia de precio:');
      print('  category_id: $categoryId, brand_id: $brandId');
      
      final response = await _dio.get(
        '/price-suggestions/suggest',
        queryParameters: queryParams,
      );
      
      if (response.data is Map) {
        final suggestion = PriceSuggestion.fromJson(response.data as Map<String, dynamic>);
        print('[ListingsRepo] Sugerencia: \$${suggestion.suggestedPrice} (${suggestion.algorithm}, n=${suggestion.n})');
        return suggestion;
      }
      
      return null;
    } on DioException catch (e) {
      print('[ListingsRepo] Error: ${e.response?.statusCode} - ${e.response?.data}');
      
      // Si no hay datos suficientes, el backend retorna 404
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _handleError(e, 'Error al obtener sugerencia de precio');
    }
  }

  // ==================== IMAGE UPLOAD ====================

  /// Obtiene URL presigned para subir una imagen
  /// 
  /// POST /images/presign
  Future<PresignResponse> getPresignedUploadUrl({
    required String listingId,
    required String filename,
    required String contentType,
  }) async {
    try {
      final request = PresignRequest(
        listingId: listingId,
        filename: filename,
        contentType: contentType,
      );
      
      final response = await _dio.post(
        '/images/presign',
        data: request.toJson(),
      );
      
      return PresignResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener URL de subida');
    }
  }

  /// Sube una imagen directamente a la URL presigned
  /// 
  /// PUT {presigned_url}
  Future<void> uploadImageToPresignedUrl({
    required String uploadUrl,
    required List<int> imageBytes,
    required String contentType,
  }) async {
    try {
      // Reescribir URL si es necesario para emulador Android
      final fixedUrl = _fixUrlForAndroidEmulator(uploadUrl);
      
      print('[ListingsRepo] Subiendo imagen:');
      print('  URL original: $uploadUrl');
      print('  URL corregida: $fixedUrl');
      print('  Tamaño: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)');
      
      // Crear un cliente Dio separado sin interceptores para la subida directa
      final uploadDio = Dio(BaseOptions(
        headers: {'Content-Type': contentType},
        validateStatus: (status) => status != null && status >= 200 && status < 300,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(seconds: 30),
      ));
      
      await uploadDio.put(
        fixedUrl,
        data: imageBytes,
        options: Options(
          contentType: contentType,
          followRedirects: true,
        ),
      );
      
      print('[ListingsRepo] Imagen subida exitosamente');
    } on DioException catch (e) {
      print('[ListingsRepo] Error al subir imagen: ${e.type}');
      print('[ListingsRepo] Mensaje: ${e.message}');
      print('[ListingsRepo] Response: ${e.response?.data}');
      throw _handleError(e, 'Error al subir imagen');
    }
  }

  /// Confirma la subida de una imagen
  /// 
  /// POST /images/confirm
  Future<String> confirmImageUpload({
    required String listingId,
    required String objectKey,
  }) async {
    try {
      final request = ConfirmUploadRequest(
        listingId: listingId,
        objectKey: objectKey,
      );
      
      final response = await _dio.post(
        '/images/confirm',
        data: request.toJson(),
      );
      
      final confirmResponse = ConfirmUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      
      return confirmResponse.previewUrl;
    } on DioException catch (e) {
      throw _handleError(e, 'Error al confirmar subida de imagen');
    }
  }

  /// Obtiene URL de preview de una imagen
  /// 
  /// GET /images/preview?object_key={key}
  Future<String> getImagePreviewUrl(String objectKey) async {
    try {
      final response = await _dio.get(
        '/images/preview',
        queryParameters: {'object_key': objectKey},
      );
      
      if (response.data is Map && response.data['preview_url'] != null) {
        return response.data['preview_url'] as String;
      }
      
      throw 'No se pudo obtener URL de preview';
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener URL de preview');
    }
  }

  /// Flujo completo de subida de imagen
  /// 
  /// Combina: presign -> upload -> confirm
  Future<String> uploadListingImage({
    required String listingId,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      // 1. Obtener URL presigned
      final presign = await getPresignedUploadUrl(
        listingId: listingId,
        filename: filename,
        contentType: contentType,
      );
      
      // 2. Subir imagen
      await uploadImageToPresignedUrl(
        uploadUrl: presign.uploadUrl,
        imageBytes: imageBytes,
        contentType: contentType,
      );
      
      // 3. Confirmar y obtener URL de preview
      final previewUrl = await confirmImageUpload(
        listingId: listingId,
        objectKey: presign.objectKey,
      );
      
      return previewUrl;
    } catch (e) {
      throw 'Error en el flujo de subida de imagen: $e';
    }
  }

  // ==================== HELPERS ====================

  /// Reescribe URLs internas de MinIO para que funcionen en emulador Android
  String _fixUrlForAndroidEmulator(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      
      // Hosts internos comunes en docker-compose/k8s
      const internalHosts = {
        'minio',
        'minio.local',
        'minio-svc',
        'minio.default.svc.cluster.local',
        'localhost',
      };
      
      if (internalHosts.contains(host)) {
        // IP pública de AWS para producción
        final fixed = uri.replace(host: '3.19.208.242');
        return fixed.toString();
      }
      
      return url;
    } catch (e) {
      print('[ListingsRepo] Error al reescribir URL: $e');
      return url;
    }
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

/// Modelo para respuesta paginada de listings
/// 
/// Según el schema Page[ListingOut] del backend
class ListingsPage {
  final List<Listing> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasNext;

  const ListingsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  factory ListingsPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((l) => Listing.fromJson(l as Map<String, dynamic>))
        .toList();
    
    return ListingsPage(
      items: items,
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      hasNext: json['has_next'] as bool,
    );
  }

  /// Verifica si hay una página anterior
  bool get hasPrevious => page > 1;
  
  /// Calcula el número total de páginas
  int get totalPages => (total / pageSize).ceil();
  
  /// Verifica si hay resultados
  bool get isEmpty => items.isEmpty;
  
  /// Verifica si hay resultados
  bool get isNotEmpty => items.isNotEmpty;
}

/// Modelo para estadísticas del usuario
class UserStatsData {
  final List<Listing> myListings;
  final int activeCount;
  final int soldCount;
  final int totalValue;
  final int viewsCount;

  const UserStatsData({
    required this.myListings,
    required this.activeCount,
    required this.soldCount,
    required this.totalValue,
    required this.viewsCount,
  });
}
