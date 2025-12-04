import 'package:dio/dio.dart';
import '../models/review.dart';
import '../../core/net/dio_client.dart';

/// Repository para el dominio de Reseñas (Reviews)
/// 
/// ============================================================
/// SP4: IMPLEMENTACIÓN DE FUTURE CON HANDLERS + ASYNC/AWAIT
/// ============================================================
/// 
/// Este repositorio demuestra:
/// - Future con .then() y .catchError() handlers
/// - Async/await con try-catch
/// - Manejo robusto de errores
/// - Integración con Backend endpoints: POST /reviews, GET /reviews/users/{id}, GET /reviews/orders/{id}
/// 
/// Métodos implementados según Backend capabilities:
/// - createReviewWithHandlers(): Usa .then()/.catchError() 
/// - loadUserReviewsAsync(): Usa async/await
/// - loadOrderReviewAsync(): Usa async/await con error handling
/// - calculateUserRatingAsync(): Procesa datos async con agregaciones
/// ============================================================
class ReviewRepository {
  final Dio _dio = DioClient.instance.dio;

  // ============================================================================
  // SP4: FUTURE CON HANDLERS (.then() / .catchError())
  // ============================================================================
  
  /// Crea una reseña usando FUTURE HANDLERS (sin async/await)
  /// 
  /// POST /reviews
  /// 
  /// IMPLEMENTACIÓN SP4: Demuestra el uso de .then() y .catchError()
  /// 
  /// Patrón:
  /// ```dart
  /// Future<Review> createReviewWithHandlers(...)
  ///   .then((review) => ...) 
  ///   .catchError((error) => ...);
  /// ```
  /// 
  /// Este método NO usa async/await, sino el estilo de handlers encadenados.
  /// Útil para operaciones donde se necesita transformar el resultado sin bloquear.
  Future<Review> createReviewWithHandlers({
    required String orderId,
    required String rateeId,
    required int rating,
    String? comment,
  }) {
    // SP4: Construcción del request body
    final data = {
      'order_id': orderId,
      'ratee_id': rateeId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    };
    
    // SP4: Future que retorna el POST, encadenado con .then() handler
    return _dio.post('/reviews', data: data).then((response) {
      // SP4: Handler de éxito - transforma Response a Review
      print('SP4: Reseña creada exitosamente: ${response.data}');
      return Review.fromJson(response.data as Map<String, dynamic>);
    }).catchError((error) {
      // SP4: Handler de error - procesa DioException
      print('SP4: Error al crear reseña: $error');
      
      if (error is DioException) {
        final message = _extractErrorMessage(error, 'Error al crear reseña');
        throw Exception(message);
      }
      
      throw Exception('Error inesperado al crear reseña: $error');
    });
  }

  // ============================================================================
  // SP4: ASYNC/AWAIT CON TRY-CATCH
  // ============================================================================
  
  /// Obtiene las reseñas de un usuario usando ASYNC/AWAIT
  /// 
  /// GET /reviews/users/{user_id}
  /// 
  /// IMPLEMENTACIÓN SP4: Demuestra async/await con try-catch
  /// 
  /// Patrón:
  /// ```dart
  /// Future<List<Review>> loadUserReviewsAsync(...) async {
  ///   try {
  ///     final response = await _dio.get(...);
  ///     return ...;
  ///   } catch (e) {
  ///     throw ...;
  ///   }
  /// }
  /// ```
  Future<List<Review>> loadUserReviewsAsync(String userId, {int limit = 50}) async {
    try {
      // SP4: await suspende hasta que el GET retorne
      print('SP4: Cargando reseñas del usuario $userId...');
      
      final response = await _dio.get(
        '/reviews/users/$userId',
        queryParameters: {'limit': limit},
      );
      
      // SP4: Procesa la respuesta del backend
      final data = response.data;
      final List items;
      
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        items = [];
      }
      
      // SP4: Transforma JSON a modelos Review
      final reviews = items
          .map((json) => Review.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('SP4: ${reviews.length} reseñas cargadas exitosamente');
      
      return reviews;
    } on DioException catch (e) {
      // SP4: Manejo específico de errores de red
      print('SP4: Error de red al cargar reseñas: ${e.message}');
      throw Exception(_extractErrorMessage(e, 'Error al obtener reseñas del usuario'));
    } catch (e) {
      // SP4: Manejo de otros errores
      print('SP4: Error inesperado: $e');
      throw Exception('Error inesperado al obtener reseñas: $e');
    }
  }

  // ============================================================================
  // SP4: ASYNC/AWAIT CON MANEJO DE NULL SAFETY
  // ============================================================================
  
  /// Obtiene la reseña de una orden específica usando ASYNC/AWAIT
  /// 
  /// GET /reviews/orders/{order_id}
  /// 
  /// IMPLEMENTACIÓN SP4: async/await con retorno nullable y manejo de 404
  /// 
  /// Demuestra:
  /// - await con verificación de null
  /// - Manejo de status code 404 (no encontrado)
  /// - Retorno Future<Review?> (nullable)
  Future<Review?> loadOrderReviewAsync(String orderId) async {
    try {
      // SP4: await GET con posible 404
      print('SP4: Buscando reseña de la orden $orderId...');
      
      final response = await _dio.get('/reviews/orders/$orderId');
      
      // SP4: Verifica si hay datos
      if (response.data == null) {
        print('SP4: No hay reseña para esta orden');
        return null;
      }
      
      // SP4: Parsea y retorna la reseña
      final review = Review.fromJson(response.data as Map<String, dynamic>);
      print('SP4: Reseña encontrada: ${review.rating} estrellas');
      
      return review;
    } on DioException catch (e) {
      // SP4: Manejo especial para 404 (no es un error)
      if (e.response?.statusCode == 404) {
        print('SP4: Orden sin reseña (404)');
        return null;
      }
      
      // SP4: Otros errores sí se propagan
      print('SP4: Error al buscar reseña: ${e.message}');
      throw Exception(_extractErrorMessage(e, 'Error al obtener reseña'));
    } catch (e) {
      print('SP4: Error inesperado: $e');
      throw Exception('Error inesperado al obtener reseña: $e');
    }
  }

  // ============================================================================
  // SP4: ASYNC/AWAIT CON PROCESAMIENTO DE DATOS
  // ============================================================================
  
  /// Calcula el rating agregado de un usuario usando ASYNC/AWAIT
  /// 
  /// IMPLEMENTACIÓN SP4: Demuestra async/await con procesamiento de datos
  /// 
  /// Flujo:
  /// 1. await para cargar reviews (operación async)
  /// 2. Procesamiento síncrono de la lista (fold, map)
  /// 3. Construcción del resultado agregado
  /// 
  /// Demuestra cómo combinar operaciones async con lógica de negocio síncrona.
  Future<UserRating> calculateUserRatingAsync(String userId) async {
    try {
      // SP4: await llama a otro método async
      print('SP4: Calculando rating del usuario $userId...');
      
      final reviews = await loadUserReviewsAsync(userId, limit: 100);
      
      // SP4: Caso base - sin reseñas
      if (reviews.isEmpty) {
        print('SP4: Usuario sin reseñas');
        return UserRating(
          averageRating: 0.0,
          totalReviews: 0,
          ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        );
      }
      
      // SP4: Cálculo de promedio usando fold
      final sum = reviews.fold<int>(0, (sum, r) => sum + r.rating);
      final average = sum / reviews.length;
      
      // SP4: Distribución de ratings
      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final review in reviews) {
        distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
      }
      
      // SP4: Resultado agregado
      print('SP4: Rating calculado: ${average.toStringAsFixed(2)} estrellas (${reviews.length} reseñas)');
      
      return UserRating(
        averageRating: average,
        totalReviews: reviews.length,
        ratingDistribution: distribution,
      );
    } catch (e) {
      // SP4: Error en cálculo
      print('SP4: Error al calcular rating: $e');
      throw Exception('Error al calcular rating del usuario: $e');
    }
  }

  // ============================================================================
  // SP4: FUTURE CON MÚLTIPLES HANDLERS ENCADENADOS
  // ============================================================================
  
  /// Verifica si un usuario puede dejar una reseña para una orden
  /// 
  /// IMPLEMENTACIÓN SP4: Future con encadenamiento complejo
  /// 
  /// Demuestra:
  /// - Encadenamiento de .then() handlers
  /// - Transformación de datos entre handlers
  /// - Lógica de negocio en handlers
  Future<bool> canUserReviewOrderWithHandlers(String orderId) {
    // SP4: Primera llamada - verifica si ya existe reseña
    return loadOrderReviewAsync(orderId)
        .then((existingReview) {
          // SP4: Handler 1 - evalúa si ya existe
          if (existingReview != null) {
            print('SP4: Orden ya tiene reseña');
            return false; // Ya tiene reseña
          }
          
          print('SP4: Orden puede ser reseñada');
          return true; // Puede crear reseña
        })
        .catchError((error) {
          // SP4: Handler de error
          print('SP4: Error al verificar reseña: $error');
          return false; // En caso de error, no permitir
        });
  }

  // ============================================================================
  // SP4: ASYNC/AWAIT CON OPERACIONES PARALELAS
  // ============================================================================
  
  /// Obtiene estadísticas completas de reviews de múltiples usuarios
  /// 
  /// IMPLEMENTACIÓN SP4: Future.wait para operaciones paralelas
  /// 
  /// Demuestra:
  /// - Future.wait() para ejecutar múltiples futures en paralelo
  /// - async/await con await Future.wait()
  /// - Procesamiento de resultados agregados
  Future<Map<String, UserRating>> getBulkUserRatingsAsync(List<String> userIds) async {
    try {
      print('SP4: Cargando ratings de ${userIds.length} usuarios en paralelo...');
      
      // SP4: Crea una lista de Futures
      final futures = userIds.map((id) => calculateUserRatingAsync(id)).toList();
      
      // SP4: await Future.wait ejecuta todos en paralelo
      final ratings = await Future.wait(futures);
      
      // SP4: Mapea resultados a un diccionario
      final result = <String, UserRating>{};
      for (var i = 0; i < userIds.length; i++) {
        result[userIds[i]] = ratings[i];
      }
      
      print('SP4: Ratings cargados para ${result.length} usuarios');
      
      return result;
    } catch (e) {
      print('SP4: Error en carga paralela: $e');
      throw Exception('Error al cargar ratings múltiples: $e');
    }
  }

  // ============================================================================
  // SP4: HELPERS
  // ============================================================================
  
  /// Extrae mensaje de error de DioException
  /// 
  /// SP4: Helper para manejo consistente de errores
  String _extractErrorMessage(DioException e, String defaultMessage) {
    if (e.response != null) {
      final data = e.response!.data;
      
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

// ============================================================================
// SP4: MODELO DE RATING AGREGADO
// ============================================================================

/// Modelo para rating agregado de un usuario
/// 
/// SP4: Usado por calculateUserRatingAsync()
class UserRating {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;

  const UserRating({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  /// Obtiene el rating en formato de estrellas (0-5)
  double get stars => averageRating;
  
  /// Obtiene el rating como porcentaje (0-100)
  int get percentage => (averageRating * 20).round();
  
  /// Verifica si tiene reseñas
  bool get hasReviews => totalReviews > 0;
  
  /// Calcula el porcentaje de reviews positivas (4-5 estrellas)
  double get positivePercentage {
    if (totalReviews == 0) return 0.0;
    final positive = (ratingDistribution[4] ?? 0) + (ratingDistribution[5] ?? 0);
    return (positive / totalReviews) * 100;
  }
  
  /// Representación en string
  @override
  String toString() {
    return 'UserRating(${averageRating.toStringAsFixed(2)} estrellas, $totalReviews reviews)';
  }
}
