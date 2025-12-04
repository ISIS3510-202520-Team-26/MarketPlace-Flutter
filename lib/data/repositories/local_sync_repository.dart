// ============================================================================
// SP4 DB: LOCAL SYNC REPOSITORY - SINCRONIZACION BD LOCAL CON BACKEND
// ============================================================================
// Este archivo implementa la capa de sincronizacion entre la base de datos
// local SQLite y el Backend remoto. Permite:
// - Sincronizar datos desde el Backend a la BD local (cache offline)
// - Consultar datos desde la BD local (lectura rapida sin red)
// - Combinar operaciones locales con llamadas al Backend
//
// ESTRATEGIA DE SINCRONIZACION:
// 1. Intenta obtener datos del Backend
// 2. Si tiene exito, actualiza la BD local
// 3. Si falla (sin red), usa datos cacheados en BD local
// 4. Logs con marcadores "SP4 DB SYNC:" para visibilidad
// ============================================================================

import 'package:dio/dio.dart';
import '../database/database_helper.dart';

// ============================================================================
// SP4 DB SYNC: CLASE PRINCIPAL - REPOSITORIO DE SINCRONIZACION
// ============================================================================
class LocalSyncRepository {
  final Dio _dio;
  final DatabaseHelper _dbHelper;
  
  // SP4 DB SYNC: Constructor con dependencias
  LocalSyncRepository({
    required String baseUrl,
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )),
        _dbHelper = DatabaseHelper() {
    print('SP4 DB SYNC: Repositorio de sincronizacion inicializado');
    print('SP4 DB SYNC: Base URL: $baseUrl');
  }

  // ============================================================================
  // SP4 DB SYNC: SINCRONIZACION DE USERS
  // ============================================================================

  // SP4 DB SYNC: Sincronizar usuario desde Backend a BD local
  Future<Map<String, dynamic>?> syncUserFromBackend(String userId) async {
    print('SP4 DB SYNC: Sincronizando usuario desde Backend: $userId');
    
    try {
      // SP4 DB SYNC: Intenta obtener del Backend
      final response = await _dio.get('/users/$userId');
      
      if (response.statusCode == 200) {
        print('SP4 DB SYNC: Usuario obtenido del Backend exitosamente');
        final userData = response.data as Map<String, dynamic>;
        
        // SP4 DB SYNC: Guarda en BD local
        await _dbHelper.upsertUser({
          'id': userData['id'],
          'name': userData['name'],
          'email': userData['email'],
          'campus': userData['campus'],
          'created_at': userData['created_at'],
        });
        
        print('SP4 DB SYNC: Usuario sincronizado a BD local');
        return userData;
      }
    } catch (e) {
      print('SP4 DB SYNC: Error al sincronizar usuario desde Backend: $e');
      print('SP4 DB SYNC: Intentando obtener desde BD local...');
    }
    
    // SP4 DB SYNC: Si falla, intenta obtener de BD local
    final localUser = await _dbHelper.getUserById(userId);
    if (localUser != null) {
      print('SP4 DB SYNC: Usuario encontrado en BD local (cache)');
    } else {
      print('SP4 DB SYNC: Usuario no encontrado en BD local');
    }
    
    return localUser;
  }

  // ============================================================================
  // SP4 DB SYNC: SINCRONIZACION DE LISTINGS
  // ============================================================================

  // SP4 DB SYNC: Sincronizar listings activos desde Backend a BD local
  Future<List<Map<String, dynamic>>> syncListingsFromBackend({int limit = 20}) async {
    print('SP4 DB SYNC: Sincronizando listings desde Backend (limit: $limit)...');
    
    try {
      // SP4 DB SYNC: Intenta obtener del Backend
      final response = await _dio.get('/listings', queryParameters: {
        'page': 1,
        'page_size': limit,
      });
      
      if (response.statusCode == 200) {
        print('SP4 DB SYNC: Listings obtenidos del Backend exitosamente');
        final data = response.data;
        final items = data['items'] as List<dynamic>;
        
        print('SP4 DB SYNC: ${items.length} listings recibidos');
        
        // SP4 DB SYNC: Guarda cada listing en BD local
        for (final item in items) {
          final listingData = item as Map<String, dynamic>;
          
          await _dbHelper.upsertListing({
            'id': listingData['id'],
            'seller_id': listingData['seller_id'],
            'title': listingData['title'],
            'description': listingData['description'],
            'category_id': listingData['category_id'],
            'brand_id': listingData['brand_id'],
            'price_cents': listingData['price_cents'],
            'currency': listingData['currency'] ?? 'COP',
            'condition': listingData['condition'],
            'quantity': listingData['quantity'] ?? 1,
            'is_active': listingData['is_active'] == true ? 1 : 0,
            'latitude': listingData['latitude'],
            'longitude': listingData['longitude'],
            'price_suggestion_used': listingData['price_suggestion_used'] == true ? 1 : 0,
            'quick_view_enabled': listingData['quick_view_enabled'] == true ? 1 : 0,
            'created_at': listingData['created_at'],
            'updated_at': listingData['updated_at'],
          });
        }
        
        print('SP4 DB SYNC: Listings sincronizados a BD local');
        return items.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('SP4 DB SYNC: Error al sincronizar listings desde Backend: $e');
      print('SP4 DB SYNC: Intentando obtener desde BD local...');
    }
    
    // SP4 DB SYNC: Si falla, obtiene de BD local
    final localListings = await _dbHelper.getActiveListings(limit: limit);
    print('SP4 DB SYNC: ${localListings.length} listings encontrados en BD local (cache)');
    
    return localListings;
  }

  // SP4 DB SYNC: Obtener todos los listings locales (para HomePage)
  Future<List<Map<String, dynamic>>> getLocalListings({int limit = 200}) async {
    print('SP4 DB SYNC: Obteniendo listings locales (limit: $limit)...');
    
    final listings = await _dbHelper.getActiveListings(limit: limit);
    
    print('SP4 DB SYNC: ${listings.length} listings encontrados en BD local');
    return listings;
  }

  // SP4 DB SYNC: Obtener listings de un seller (local primero, luego Backend)
  Future<List<Map<String, dynamic>>> getSellerListings(String sellerId) async {
    print('SP4 DB SYNC: Obteniendo listings del seller: $sellerId');
    
    // SP4 DB SYNC: Consulta local primero (rapido)
    final localListings = await _dbHelper.getListingsBySeller(sellerId);
    print('SP4 DB SYNC: ${localListings.length} listings encontrados localmente');
    
    // SP4 DB SYNC: Intenta actualizar desde Backend en background
    try {
      final response = await _dio.get('/listings', queryParameters: {
        'seller_id': sellerId,
      });
      
      if (response.statusCode == 200) {
        print('SP4 DB SYNC: Actualizando listings del seller desde Backend...');
        final data = response.data;
        final items = data['items'] as List<dynamic>;
        
        for (final item in items) {
          final listingData = item as Map<String, dynamic>;
          await _dbHelper.upsertListing({
            'id': listingData['id'],
            'seller_id': listingData['seller_id'],
            'title': listingData['title'],
            'description': listingData['description'],
            'category_id': listingData['category_id'],
            'brand_id': listingData['brand_id'],
            'price_cents': listingData['price_cents'],
            'currency': listingData['currency'] ?? 'COP',
            'condition': listingData['condition'],
            'quantity': listingData['quantity'] ?? 1,
            'is_active': listingData['is_active'] == true ? 1 : 0,
            'latitude': listingData['latitude'],
            'longitude': listingData['longitude'],
            'price_suggestion_used': listingData['price_suggestion_used'] == true ? 1 : 0,
            'quick_view_enabled': listingData['quick_view_enabled'] == true ? 1 : 0,
            'created_at': listingData['created_at'],
            'updated_at': listingData['updated_at'],
          });
        }
        
        print('SP4 DB SYNC: Listings del seller actualizados');
      }
    } catch (e) {
      print('SP4 DB SYNC: No se pudo actualizar desde Backend (usando cache): $e');
    }
    
    return localListings;
  }

  // ============================================================================
  // SP4 DB SYNC: SINCRONIZACION DE ORDERS
  // ============================================================================

  // SP4 DB SYNC: Sincronizar ordenes de un usuario desde Backend a BD local
  Future<List<Map<String, dynamic>>> syncUserOrdersFromBackend(String userId) async {
    print('SP4 DB SYNC: Sincronizando ordenes del usuario desde Backend: $userId');
    
    try {
      // SP4 DB SYNC: Intenta obtener del Backend
      final response = await _dio.get('/orders/user/$userId');
      
      if (response.statusCode == 200) {
        print('SP4 DB SYNC: Ordenes obtenidas del Backend exitosamente');
        final orders = response.data as List<dynamic>;
        
        print('SP4 DB SYNC: ${orders.length} ordenes recibidas');
        
        // SP4 DB SYNC: Guarda cada orden en BD local
        for (final item in orders) {
          final orderData = item as Map<String, dynamic>;
          
          await _dbHelper.upsertOrder({
            'id': orderData['id'],
            'buyer_id': orderData['buyer_id'],
            'seller_id': orderData['seller_id'],
            'listing_id': orderData['listing_id'],
            'total_cents': orderData['total_cents'],
            'currency': orderData['currency'] ?? 'COP',
            'status': orderData['status'],
            'created_at': orderData['created_at'],
            'updated_at': orderData['updated_at'],
          });
        }
        
        print('SP4 DB SYNC: Ordenes sincronizadas a BD local');
        return orders.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('SP4 DB SYNC: Error al sincronizar ordenes desde Backend: $e');
      print('SP4 DB SYNC: Intentando obtener desde BD local...');
    }
    
    // SP4 DB SYNC: Si falla, obtiene de BD local (como buyer o seller)
    final buyerOrders = await _dbHelper.getOrdersByBuyer(userId);
    final sellerOrders = await _dbHelper.getOrdersBySeller(userId);
    
    final allOrders = [...buyerOrders, ...sellerOrders];
    print('SP4 DB SYNC: ${allOrders.length} ordenes encontradas en BD local (cache)');
    
    return allOrders;
  }

  // SP4 DB SYNC: Obtener orden con detalles (local con JOIN)
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    print('SP4 DB SYNC: Obteniendo detalles de orden: $orderId');
    
    // SP4 DB SYNC: Consulta local con JOIN (rapido y eficiente)
    final orderDetails = await _dbHelper.getOrderWithDetails(orderId);
    
    if (orderDetails != null) {
      print('SP4 DB SYNC: Detalles de orden encontrados en BD local');
      return orderDetails;
    }
    
    print('SP4 DB SYNC: Orden no encontrada en BD local');
    return null;
  }

  // SP4 DB SYNC: Obtener todas las ordenes locales
  Future<List<Map<String, dynamic>>> getLocalOrders() async {
    print('SP4 DB SYNC: Obteniendo todas las órdenes desde BD local...');
    
    // SP4 DB SYNC: Consulta todas las ordenes (sin filtro)
    final db = await _dbHelper.database;
    final result = await db.query('orders', orderBy: 'created_at DESC');
    
    print('SP4 DB SYNC: ${result.length} órdenes encontradas en BD local');
    return result;
  }

  // SP4 DB SYNC: Guardar orden en BD local
  Future<void> saveOrderToLocal(Map<String, dynamic> order) async {
    print('SP4 DB SYNC: Guardando orden ${order['id']} en BD local...');
    
    await _dbHelper.upsertOrder(order);
    
    print('SP4 DB SYNC: Orden guardada exitosamente');
  }

  // SP4 DB SYNC: Obtener reviews locales del usuario
  Future<List<Map<String, dynamic>>> getLocalReviews(String userId) async {
    print('SP4 DB SYNC: Obteniendo reviews locales del usuario: $userId');
    
    // SP4 DB SYNC: Consulta reviews donde el usuario es el rater (quien califica)
    final reviews = await _dbHelper.getReviewsByRater(userId);
    
    print('SP4 DB SYNC: ${reviews.length} reviews encontradas en BD local');
    return reviews;
  }

  // SP4 DB SYNC: Guardar review en BD local
  Future<void> saveReviewToLocal(Map<String, dynamic> review) async {
    print('SP4 DB SYNC: Guardando review ${review['id']} en BD local...');
    
    await _dbHelper.upsertReview(review);
    
    print('SP4 DB SYNC: Review guardada exitosamente');
  }

  // SP4 DB SYNC: Sincronizar ordenes desde Backend (sin user_id)
  Future<void> syncOrdersFromBackend({int limit = 50}) async {
    print('SP4 DB SYNC: Sincronizando órdenes desde Backend (limit: $limit)...');
    
    try {
      // SP4 DB SYNC: Obtiene ordenes del Backend (endpoint genérico)
      final response = await _dio.get('/orders', queryParameters: {
        'page': 1,
        'page_size': limit,
      });
      
      if (response.statusCode == 200) {
        final data = response.data;
        final orders = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        print('SP4 DB SYNC: ${orders.length} órdenes obtenidas del Backend');
        
        // SP4 DB SYNC: Guarda cada orden en BD local
        for (final order in orders) {
          await _dbHelper.upsertOrder({
            'id': order['id'],
            'buyer_id': order['buyer_id'],
            'seller_id': order['seller_id'],
            'listing_id': order['listing_id'],
            'total_cents': order['total_cents'],
            'currency': order['currency'] ?? 'COP',
            'status': order['status'],
            'created_at': order['created_at'],
            'updated_at': order['updated_at'],
          });
        }
        
        print('SP4 DB SYNC: Órdenes sincronizadas a BD local exitosamente');
      }
    } catch (e) {
      print('SP4 DB SYNC: Error al sincronizar órdenes: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SP4 DB SYNC: SINCRONIZACION DE REVIEWS
  // ============================================================================

  // SP4 DB SYNC: Sincronizar reviews de un usuario desde Backend a BD local
  Future<List<Map<String, dynamic>>> syncUserReviewsFromBackend(String userId) async {
    print('SP4 DB SYNC: Sincronizando reviews del usuario desde Backend: $userId');
    
    try {
      // SP4 DB SYNC: Intenta obtener del Backend
      final response = await _dio.get('/reviews/users/$userId');
      
      if (response.statusCode == 200) {
        print('SP4 DB SYNC: Reviews obtenidas del Backend exitosamente');
        final reviews = response.data as List<dynamic>;
        
        print('SP4 DB SYNC: ${reviews.length} reviews recibidas');
        
        // SP4 DB SYNC: Guarda cada review en BD local
        for (final item in reviews) {
          final reviewData = item as Map<String, dynamic>;
          
          await _dbHelper.upsertReview({
            'id': reviewData['id'],
            'order_id': reviewData['order_id'],
            'rater_id': reviewData['rater_id'],
            'ratee_id': reviewData['ratee_id'],
            'rating': reviewData['rating'],
            'comment': reviewData['comment'],
            'created_at': reviewData['created_at'],
          });
        }
        
        print('SP4 DB SYNC: Reviews sincronizadas a BD local');
        return reviews.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('SP4 DB SYNC: Error al sincronizar reviews desde Backend: $e');
      print('SP4 DB SYNC: Intentando obtener desde BD local...');
    }
    
    // SP4 DB SYNC: Si falla, obtiene de BD local
    final localReviews = await _dbHelper.getReviewsByRater(userId);
    print('SP4 DB SYNC: ${localReviews.length} reviews encontradas en BD local (cache)');
    
    return localReviews;
  }

  // SP4 DB SYNC: Calcular rating promedio de un usuario (local)
  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    print('SP4 DB SYNC: Calculando estadisticas de rating para usuario: $userId');
    
    // SP4 DB SYNC: Calcula desde BD local (rapido)
    final avgRating = await _dbHelper.calculateAverageRating(userId);
    final reviews = await _dbHelper.getReviewsByRatee(userId);
    
    final stats = {
      'user_id': userId,
      'average_rating': avgRating,
      'total_reviews': reviews.length,
      'source': 'local_database',
    };
    
    print('SP4 DB SYNC: Estadisticas calculadas: rating=${avgRating.toStringAsFixed(2)}, total=${reviews.length}');
    
    return stats;
  }

  // ============================================================================
  // SP4 DB SYNC: OPERACIONES COMBINADAS (BACKEND + LOCAL)
  // ============================================================================

  // SP4 DB SYNC: Crear orden en Backend y guardar en BD local
  Future<Map<String, dynamic>?> createOrderWithSync({
    required String listingId,
    required int totalCents,
    String currency = 'COP',
  }) async {
    print('SP4 DB SYNC: Creando orden en Backend...');
    
    try {
      // SP4 DB SYNC: Crea en Backend
      final response = await _dio.post('/orders', data: {
        'listing_id': listingId,
        'total_cents': totalCents,
        'currency': currency,
      });
      
      if (response.statusCode == 201) {
        print('SP4 DB SYNC: Orden creada en Backend exitosamente');
        final orderData = response.data as Map<String, dynamic>;
        
        // SP4 DB SYNC: Sincroniza a BD local
        await _dbHelper.upsertOrder({
          'id': orderData['id'],
          'buyer_id': orderData['buyer_id'],
          'seller_id': orderData['seller_id'],
          'listing_id': orderData['listing_id'],
          'total_cents': orderData['total_cents'],
          'currency': orderData['currency'] ?? 'COP',
          'status': orderData['status'],
          'created_at': orderData['created_at'],
          'updated_at': orderData['updated_at'],
        });
        
        print('SP4 DB SYNC: Orden sincronizada a BD local');
        return orderData;
      }
    } catch (e) {
      print('SP4 DB SYNC: Error al crear orden: $e');
    }
    
    return null;
  }

  // SP4 DB SYNC: Obtener estadisticas de seller desde BD local
  Future<Map<String, dynamic>> getSellerStatistics(String sellerId) async {
    print('SP4 DB SYNC: Obteniendo estadisticas del seller desde BD local: $sellerId');
    
    // SP4 DB SYNC: Calcula desde BD local (agregaciones SQL)
    final stats = await _dbHelper.getSellerStats(sellerId);
    
    print('SP4 DB SYNC: Estadisticas del seller calculadas');
    print('SP4 DB SYNC: Listings: ${stats['total_listings']}, Ordenes: ${stats['total_orders']}');
    
    return stats;
  }

  // ============================================================================
  // SP4 DB SYNC: SINCRONIZACION COMPLETA
  // ============================================================================

  // SP4 DB SYNC: Sincronizar todos los datos de un usuario
  Future<Map<String, dynamic>> syncAllUserData(String userId) async {
    print('SP4 DB SYNC: Iniciando sincronizacion completa para usuario: $userId');
    
    final results = {
      'user_synced': false,
      'listings_synced': 0,
      'orders_synced': 0,
      'reviews_synced': 0,
      'errors': <String>[],
    };
    
    try {
      // SP4 DB SYNC: Sincroniza usuario
      final user = await syncUserFromBackend(userId);
      results['user_synced'] = user != null;
      
      // SP4 DB SYNC: Sincroniza listings del usuario
      final listings = await getSellerListings(userId);
      results['listings_synced'] = listings.length;
      
      // SP4 DB SYNC: Sincroniza ordenes del usuario
      final orders = await syncUserOrdersFromBackend(userId);
      results['orders_synced'] = orders.length;
      
      // SP4 DB SYNC: Sincroniza reviews del usuario
      final reviews = await syncUserReviewsFromBackend(userId);
      results['reviews_synced'] = reviews.length;
      
      print('SP4 DB SYNC: Sincronizacion completa finalizada');
      print('SP4 DB SYNC: User=${results['user_synced']}, Listings=${results['listings_synced']}, Orders=${results['orders_synced']}, Reviews=${results['reviews_synced']}');
      
    } catch (e) {
      print('SP4 DB SYNC: Error durante sincronizacion completa: $e');
      results['errors'] = [e.toString()];
    }
    
    return results;
  }

  // ============================================================================
  // SP4 DB SYNC: UTILIDADES
  // ============================================================================

  // SP4 DB SYNC: Obtener conteo de registros en BD local
  Future<Map<String, int>> getLocalDatabaseStats() async {
    print('SP4 DB SYNC: Obteniendo estadisticas de BD local...');
    
    final counts = await _dbHelper.countAllRecords();
    
    print('SP4 DB SYNC: Estadisticas de BD local:');
    print('SP4 DB SYNC: Users: ${counts['users']}, Listings: ${counts['listings']}, Orders: ${counts['orders']}, Reviews: ${counts['reviews']}');
    
    return counts;
  }

  // SP4 DB SYNC: Limpiar cache local
  Future<void> clearLocalCache() async {
    print('SP4 DB SYNC: Limpiando cache local...');
    
    await _dbHelper.clearDatabase();
    
    print('SP4 DB SYNC: Cache local limpiado');
  }
}
