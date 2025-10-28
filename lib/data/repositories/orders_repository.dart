import 'package:dio/dio.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/review.dart';
import '../../core/net/dio_client.dart';

/// Repository para el dominio de Órdenes
/// 
/// Agrupa operaciones relacionadas con órdenes, pagos y reseñas.
/// Basado en los repositories y endpoints del backend.
class OrdersRepository {
  final Dio _dio = DioClient.instance.dio;

  // ==================== ORDERS CRUD ====================

  /// Crea una nueva orden
  /// 
  /// POST /orders
  Future<Order> createOrder({
    required String listingId,
    int quantity = 1,
    int? totalCents,
    String? currency,
  }) async {
    try {
      final data = <String, dynamic>{
        'listing_id': listingId,
        'quantity': quantity,
      };
      
      if (totalCents != null) data['total_cents'] = totalCents;
      if (currency != null) data['currency'] = currency;
      
      final response = await _dio.post('/orders', data: data);
      return Order.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al crear orden');
    }
  }

  /// Obtiene una orden por ID
  /// 
  /// GET /orders/{id}
  Future<Order> getOrderById(String orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId');
      return Order.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener orden');
    }
  }

  /// Obtiene una orden con relaciones (payments, escrow, status_history)
  /// 
  /// Similar a OrderRepository.get_with_relations del backend
  Future<OrderDetails> getOrderWithDetails(String orderId) async {
    try {
      final response = await _dio.get(
        '/orders/$orderId',
        queryParameters: {'include': 'payments,escrow,status_history'},
      );
      
      return OrderDetails.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener detalles de orden');
    }
  }

  /// Lista órdenes del usuario actual
  /// 
  /// GET /orders?user_id=me (asumiendo filtro por usuario)
  Future<List<Order>> getMyOrders({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      
      if (status != null) queryParams['status'] = status;
      
      final response = await _dio.get(
        '/orders',
        queryParameters: queryParams,
      );
      
      final data = response.data;
      final List items;
      
      if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      
      return items
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener órdenes');
    }
  }

  // ==================== ORDER STATUS TRANSITIONS ====================

  /// Paga una orden
  /// 
  /// POST /orders/{id}/pay
  /// 
  /// Transición: created -> paid
  /// - Autoriza el pago
  /// - Captura el pago
  /// - Crea escrow y lo marca como funded
  Future<Order> payOrder(String orderId) async {
    try {
      final response = await _dio.post('/orders/$orderId/pay');
      return Order.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al pagar orden');
    }
  }

  /// Completa una orden
  /// 
  /// POST /orders/{id}/complete
  /// 
  /// Transición: shipped -> completed
  Future<Order> completeOrder(String orderId) async {
    try {
      final response = await _dio.post('/orders/$orderId/complete');
      return Order.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al completar orden');
    }
  }

  /// Cancela una orden
  /// 
  /// POST /orders/{id}/cancel
  /// 
  /// Transición: * -> cancelled
  /// - Reembolsa el pago si fue capturado
  Future<Order> cancelOrder(String orderId, {String? reason}) async {
    try {
      final data = <String, dynamic>{};
      if (reason != null) data['reason'] = reason;
      
      final response = await _dio.post(
        '/orders/$orderId/cancel',
        data: data.isNotEmpty ? data : null,
      );
      
      return Order.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al cancelar orden');
    }
  }

  /// Marca orden como enviada
  /// 
  /// POST /orders/{id}/ship (asumiendo que existe)
  Future<Order> shipOrder(String orderId, {String? trackingNumber}) async {
    try {
      final data = <String, dynamic>{};
      if (trackingNumber != null) data['tracking_number'] = trackingNumber;
      
      final response = await _dio.post(
        '/orders/$orderId/ship',
        data: data.isNotEmpty ? data : null,
      );
      
      return Order.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al marcar orden como enviada');
    }
  }

  // ==================== ORDER STATUS HISTORY ====================

  /// Obtiene el historial de cambios de estado de una orden
  /// 
  /// Basado en OrderStatusRepository.list_for_order
  Future<List<OrderStatusHistory>> getOrderStatusHistory(String orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId/status-history');
      
      final data = response.data;
      final List items;
      
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        items = [];
      }
      
      return items
          .map((json) => OrderStatusHistory.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener historial de estados');
    }
  }

  // ==================== PAYMENTS ====================

  /// Obtiene los pagos de una orden
  /// 
  /// Basado en PaymentRepository.get_by_order
  Future<List<Payment>> getOrderPayments(String orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId/payments');
      
      final data = response.data;
      final List items;
      
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        items = [];
      }
      
      return items
          .map((json) => Payment.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener pagos de la orden');
    }
  }

  /// Captura un pago (usado por webhooks/callbacks de payment providers)
  /// 
  /// POST /payments/capture
  Future<bool> capturePayment({
    required String orderId,
    required String providerRef,
  }) async {
    try {
      final callback = PaymentCallback(
        orderId: orderId,
        providerRef: providerRef,
      );
      
      final response = await _dio.post(
        '/payments/capture',
        data: callback.toJson(),
      );
      
      return response.data['captured'] == true;
    } on DioException catch (e) {
      throw _handleError(e, 'Error al capturar pago');
    }
  }

  /// Reembolsa un pago
  /// 
  /// POST /payments/refund
  Future<bool> refundPayment({
    required String orderId,
    required String providerRef,
  }) async {
    try {
      final callback = PaymentCallback(
        orderId: orderId,
        providerRef: providerRef,
      );
      
      final response = await _dio.post(
        '/payments/refund',
        data: callback.toJson(),
      );
      
      return response.data['refunded'] == true;
    } on DioException catch (e) {
      throw _handleError(e, 'Error al reembolsar pago');
    }
  }

  // ==================== REVIEWS ====================

  /// Crea una reseña para una orden
  /// 
  /// POST /reviews
  Future<Review> createReview({
    required String orderId,
    required String rateeId,
    required int rating,
    String? comment,
  }) async {
    try {
      final data = {
        'order_id': orderId,
        'ratee_id': rateeId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      };
      
      final response = await _dio.post('/reviews', data: data);
      return Review.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al crear reseña');
    }
  }

  /// Obtiene la reseña de una orden
  /// 
  /// GET /reviews/orders/{order_id}
  Future<Review?> getReviewByOrder(String orderId) async {
    try {
      final response = await _dio.get('/reviews/orders/$orderId');
      
      if (response.data == null) {
        return null;
      }
      
      return Review.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _handleError(e, 'Error al obtener reseña');
    }
  }

  /// Obtiene las reseñas recibidas por un usuario
  /// 
  /// GET /reviews/users/{user_id}
  Future<List<Review>> getUserReviews(String userId, {int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/reviews/users/$userId',
        queryParameters: {'limit': limit},
      );
      
      final data = response.data;
      final List items;
      
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        items = [];
      }
      
      return items
          .map((json) => Review.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener reseñas del usuario');
    }
  }

  /// Calcula el rating promedio de un usuario
  /// 
  /// Helper local basado en las reseñas
  Future<UserRating> getUserRating(String userId) async {
    try {
      final reviews = await getUserReviews(userId, limit: 100);
      
      if (reviews.isEmpty) {
        return UserRating(
          averageRating: 0.0,
          totalReviews: 0,
          ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        );
      }
      
      final sum = reviews.fold<int>(0, (sum, r) => sum + r.rating);
      final average = sum / reviews.length;
      
      // Distribución de ratings
      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final review in reviews) {
        distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
      }
      
      return UserRating(
        averageRating: average,
        totalReviews: reviews.length,
        ratingDistribution: distribution,
      );
    } catch (e) {
      throw 'Error al calcular rating del usuario: $e';
    }
  }

  // ==================== HELPERS ====================

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

/// Modelo para orden con detalles completos
/// 
/// Incluye payments, escrow y status_history
class OrderDetails {
  final Order order;
  final List<Payment> payments;
  final List<OrderStatusHistory> statusHistory;

  const OrderDetails({
    required this.order,
    required this.payments,
    required this.statusHistory,
  });

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    final order = Order.fromJson(json);
    
    final payments = (json['payments'] as List<dynamic>?)
        ?.map((p) => Payment.fromJson(p as Map<String, dynamic>))
        .toList() ?? [];
    
    final statusHistory = (json['status_history'] as List<dynamic>?)
        ?.map((h) => OrderStatusHistory.fromJson(h as Map<String, dynamic>))
        .toList() ?? [];
    
    return OrderDetails(
      order: order,
      payments: payments,
      statusHistory: statusHistory,
    );
  }

  /// Obtiene el pago más reciente
  Payment? get latestPayment => payments.isNotEmpty ? payments.first : null;
  
  /// Verifica si tiene pagos
  bool get hasPayments => payments.isNotEmpty;
  
  /// Calcula el total pagado
  int get totalPaid {
    return payments
        .where((p) => p.isCompleted)
        .fold<int>(0, (sum, p) => sum + p.amountCents);
  }
}

/// Modelo para rating agregado de un usuario
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
}
