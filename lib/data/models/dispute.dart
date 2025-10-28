/// Modelo de Disputa (Dispute)
/// 
/// Representa una disputa levantada sobre una orden.
/// Una orden solo puede tener una disputa (relación 1:1).
/// Basado en el schema del backend PostgreSQL.
class Dispute {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID de la orden en disputa (único, una orden solo puede tener una disputa)
  final String orderId;
  
  /// Quién levantó la disputa: "buyer" o "seller"
  final String raisedBy;
  
  /// Razón de la disputa (opcional)
  final String? reason;
  
  /// Estado de la disputa: "open", "resolved", o "rejected"
  final String status;
  
  /// Fecha en que se creó la disputa
  final DateTime createdAt;
  
  /// Fecha en que se resolvió la disputa (opcional)
  final DateTime? resolvedAt;

  const Dispute({
    required this.id,
    required this.orderId,
    required this.raisedBy,
    this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: (json['id'] ?? json['uuid']).toString(),
      orderId: (json['order_id'] ?? json['orderId']).toString(),
      raisedBy: json['raised_by'] as String,
      reason: json['reason']?.toString(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null 
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  /// Convierte a JSON para crear una disputa
  /// 
  /// Usa snake_case según el schema DisputeCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'raised_by': raisedBy,
      if (reason != null) 'reason': reason,
    };
  }

  /// Convierte a JSON para actualizar el estado de una disputa
  /// 
  /// Usa snake_case según el schema DisputeUpdate del backend
  Map<String, dynamic> toUpdateJson({String? comment}) {
    return {
      'status': status,
      if (comment != null) 'comment': comment,
    };
  }

  /// Verifica si la disputa fue levantada por el comprador
  bool get isRaisedByBuyer => raisedBy.toLowerCase() == 'buyer';
  
  /// Verifica si la disputa fue levantada por el vendedor
  bool get isRaisedBySeller => raisedBy.toLowerCase() == 'seller';
  
  /// Verifica si la disputa está abierta
  bool get isOpen => status.toLowerCase() == 'open';
  
  /// Verifica si la disputa fue resuelta
  bool get isResolved => status.toLowerCase() == 'resolved';
  
  /// Verifica si la disputa fue rechazada
  bool get isRejected => status.toLowerCase() == 'rejected';
  
  /// Verifica si la disputa está cerrada (resuelta o rechazada)
  bool get isClosed => isResolved || isRejected;

  /// Copia la instancia con campos modificados
  Dispute copyWith({
    String? id,
    String? orderId,
    String? raisedBy,
    String? reason,
    String? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return Dispute(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      raisedBy: raisedBy ?? this.raisedBy,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  String toString() => 'Dispute(id: $id, orderId: $orderId, raisedBy: $raisedBy, status: $status, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dispute &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          raisedBy == other.raisedBy &&
          reason == other.reason &&
          status == other.status &&
          createdAt == other.createdAt &&
          resolvedAt == other.resolvedAt;

  @override
  int get hashCode => Object.hash(id, orderId, raisedBy, reason, status, createdAt, resolvedAt);
}
