/// Modelo de Pago (Payment)
/// 
/// Representa un pago realizado para una orden.
/// Una orden puede tener múltiples pagos (ej: intentos, reembolsos parciales).
/// Basado en el schema del backend PostgreSQL.
class Payment {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID de la orden asociada
  final String orderId;
  
  /// Proveedor de pago (máx 40 caracteres)
  /// Ejemplos: "stripe", "paypal", "wompi", "mercadopago"
  final String provider;
  
  /// Referencia del proveedor de pago (opcional, máx 120 caracteres)
  /// ID de transacción del proveedor externo
  final String? providerRef;
  
  /// Monto del pago en centavos
  final int amountCents;
  
  /// Estado del pago (máx 20 caracteres)
  /// Ejemplos: "pending", "completed", "failed", "refunded"
  final String status;
  
  /// Fecha de creación del pago
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.provider,
    this.providerRef,
    required this.amountCents,
    required this.status,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: (json['id'] ?? json['uuid']).toString(),
      orderId: (json['order_id'] ?? json['orderId']).toString(),
      provider: json['provider'] as String,
      providerRef: json['provider_ref']?.toString(),
      amountCents: (json['amount_cents'] ?? json['amountCents']) as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para crear un pago
  /// 
  /// Usa snake_case según el schema PaymentCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'provider': provider,
      'amount_cents': amountCents,
    };
  }

  /// Monto del pago en unidades monetarias (divide cents por 100)
  double get amount => amountCents / 100.0;
  
  /// Verifica si el pago está pendiente
  bool get isPending => status.toLowerCase() == 'pending';
  
  /// Verifica si el pago fue completado
  bool get isCompleted => status.toLowerCase() == 'completed';
  
  /// Verifica si el pago falló
  bool get isFailed => status.toLowerCase() == 'failed';
  
  /// Verifica si el pago fue reembolsado
  bool get isRefunded => status.toLowerCase() == 'refunded';
  
  /// Verifica si el pago está en un estado final
  bool get isFinal => isCompleted || isFailed || isRefunded;
  
  /// Verifica si tiene referencia del proveedor
  bool get hasProviderRef => providerRef != null && providerRef!.isNotEmpty;

  /// Copia la instancia con campos modificados
  Payment copyWith({
    String? id,
    String? orderId,
    String? provider,
    String? providerRef,
    int? amountCents,
    String? status,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      provider: provider ?? this.provider,
      providerRef: providerRef ?? this.providerRef,
      amountCents: amountCents ?? this.amountCents,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Payment(id: $id, orderId: $orderId, provider: $provider, amount: \$$amount, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          provider == other.provider &&
          providerRef == other.providerRef &&
          amountCents == other.amountCents &&
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, orderId, provider, providerRef, amountCents, status, createdAt);
}

/// Request para callback de pago desde el proveedor
/// 
/// Usado cuando el proveedor de pago notifica el resultado de una transacción.
/// Según el schema PaymentCallbackIn del backend.
class PaymentCallback {
  final String orderId;
  final String providerRef;

  const PaymentCallback({
    required this.orderId,
    required this.providerRef,
  });

  factory PaymentCallback.fromJson(Map<String, dynamic> json) {
    return PaymentCallback(
      orderId: (json['order_id'] ?? json['orderId']).toString(),
      providerRef: json['provider_ref'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'provider_ref': providerRef,
    };
  }
}

/// Estados de pago comunes
class PaymentStatus {
  static const String pending = 'pending';
  static const String completed = 'completed';
  static const String failed = 'failed';
  static const String refunded = 'refunded';
  static const String cancelled = 'cancelled';
  
  /// Lista de todos los estados comunes
  static const List<String> all = [pending, completed, failed, refunded, cancelled];
  
  /// Estados finales (no pueden cambiar)
  static const List<String> final_ = [completed, failed, refunded, cancelled];
  
  /// Verifica si un estado es final
  static bool isFinal(String status) => final_.contains(status.toLowerCase());
}
