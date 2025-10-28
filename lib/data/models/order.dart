/// Modelo de Orden (Order)
/// 
/// Representa una orden de compra entre un comprador y un vendedor.
/// Basado en el schema del backend PostgreSQL.
class Order {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del comprador
  final String buyerId;
  
  /// ID del vendedor
  final String sellerId;
  
  /// ID del listing que se está comprando
  final String listingId;
  
  /// Precio total en centavos (para evitar problemas con decimales)
  final int totalCents;
  
  /// Moneda (código ISO 4217, 3 caracteres)
  final String currency;
  
  /// Estado de la orden: "created", "paid", "shipped", "completed", "cancelled"
  final String status;
  
  /// Fecha de creación de la orden
  final DateTime createdAt;
  
  /// Fecha de última actualización
  final DateTime updatedAt;
  
  /// Historial de cambios de estado (opcional, solo en respuestas detalladas)
  final List<OrderStatusHistory>? statusHistory;

  const Order({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.listingId,
    required this.totalCents,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.statusHistory,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: (json['id'] ?? json['uuid']).toString(),
      buyerId: (json['buyer_id'] ?? json['buyerId']).toString(),
      sellerId: (json['seller_id'] ?? json['sellerId']).toString(),
      listingId: (json['listing_id'] ?? json['listingId']).toString(),
      totalCents: (json['total_cents'] ?? json['totalCents']) as int,
      currency: (json['currency'] as String?) ?? 'COP',
      status: (json['status'] as String?) ?? 'created',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      statusHistory: (json['status_history'] as List<dynamic>?)
          ?.map((h) => OrderStatusHistory.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convierte a JSON para crear una orden
  /// 
  /// Usa snake_case según el schema OrderCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'total_cents': totalCents,
      'currency': currency,
    };
  }

  /// Convierte a JSON para actualizar el estado de la orden
  /// 
  /// Usa el schema OrderUpdateStatus del backend
  Map<String, dynamic> toUpdateStatusJson({String? reason}) {
    return {
      'to_status': status,
      if (reason != null) 'reason': reason,
    };
  }

  /// Precio total en unidades monetarias (divide cents por 100)
  double get total => totalCents / 100.0;
  
  /// Verifica si la orden fue creada
  bool get isCreated => status.toLowerCase() == 'created';
  
  /// Verifica si la orden fue pagada
  bool get isPaid => status.toLowerCase() == 'paid';
  
  /// Verifica si la orden fue enviada
  bool get isShipped => status.toLowerCase() == 'shipped';
  
  /// Verifica si la orden fue completada
  bool get isCompleted => status.toLowerCase() == 'completed';
  
  /// Verifica si la orden fue cancelada
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  
  /// Verifica si la orden está en un estado final (no puede cambiar)
  bool get isFinal => isCompleted || isCancelled;
  
  /// Verifica si la orden está activa (puede cambiar de estado)
  bool get isActive => !isFinal;
  
  /// Verifica si tiene historial de estado
  bool get hasStatusHistory => statusHistory != null && statusHistory!.isNotEmpty;

  /// Copia la instancia con campos modificados
  Order copyWith({
    String? id,
    String? buyerId,
    String? sellerId,
    String? listingId,
    int? totalCents,
    String? currency,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderStatusHistory>? statusHistory,
  }) {
    return Order(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      listingId: listingId ?? this.listingId,
      totalCents: totalCents ?? this.totalCents,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }

  @override
  String toString() => 'Order(id: $id, buyerId: $buyerId, sellerId: $sellerId, total: \$$total $currency, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          buyerId == other.buyerId &&
          sellerId == other.sellerId &&
          listingId == other.listingId &&
          totalCents == other.totalCents &&
          currency == other.currency &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        buyerId,
        sellerId,
        listingId,
        totalCents,
        currency,
        status,
        createdAt,
        updatedAt,
      );
}

/// Modelo de Historial de Estado de Orden (OrderStatusHistory)
/// 
/// Representa un cambio de estado en una orden.
/// Usado para auditoría y tracking del flujo de la orden.
class OrderStatusHistory {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID de la orden
  final String orderId;
  
  /// Estado anterior (opcional, null si es el primer estado)
  final String? fromStatus;
  
  /// Estado nuevo
  final String toStatus;
  
  /// Razón del cambio de estado (opcional)
  final String? reason;
  
  /// Fecha del cambio de estado
  final DateTime createdAt;

  const OrderStatusHistory({
    required this.id,
    required this.orderId,
    this.fromStatus,
    required this.toStatus,
    this.reason,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      id: (json['id'] ?? json['uuid']).toString(),
      orderId: (json['order_id'] ?? json['orderId']).toString(),
      fromStatus: json['from_status']?.toString(),
      toStatus: json['to_status'] as String,
      reason: json['reason']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      if (fromStatus != null) 'from_status': fromStatus,
      'to_status': toStatus,
      if (reason != null) 'reason': reason,
    };
  }

  /// Verifica si es el primer cambio de estado (fromStatus es null)
  bool get isInitialStatus => fromStatus == null;
  
  /// Verifica si tiene razón documentada
  bool get hasReason => reason != null && reason!.isNotEmpty;

  /// Copia la instancia con campos modificados
  OrderStatusHistory copyWith({
    String? id,
    String? orderId,
    String? fromStatus,
    String? toStatus,
    String? reason,
    DateTime? createdAt,
  }) {
    return OrderStatusHistory(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'OrderStatusHistory(id: $id, orderId: $orderId, fromStatus: $fromStatus, toStatus: $toStatus, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderStatusHistory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          fromStatus == other.fromStatus &&
          toStatus == other.toStatus &&
          reason == other.reason &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, orderId, fromStatus, toStatus, reason, createdAt);
}

/// Estados de orden disponibles
class OrderStatus {
  static const String created = 'created';
  static const String paid = 'paid';
  static const String shipped = 'shipped';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  
  /// Lista de todos los estados válidos
  static const List<String> all = [created, paid, shipped, completed, cancelled];
  
  /// Estados activos (pueden cambiar)
  static const List<String> active = [created, paid, shipped];
  
  /// Estados finales (no pueden cambiar)
  static const List<String> final_ = [completed, cancelled];
  
  /// Verifica si un estado es válido
  static bool isValid(String status) => all.contains(status.toLowerCase());
  
  /// Verifica si un estado es final
  static bool isFinal(String status) => final_.contains(status.toLowerCase());
  
  /// Verifica si un estado es activo
  static bool isActive(String status) => active.contains(status.toLowerCase());
}
