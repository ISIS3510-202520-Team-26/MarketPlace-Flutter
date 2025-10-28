/// Modelo de Escrow (Custodia de Pago)
/// 
/// Representa un proceso de custodia de pago para una orden.
/// Cada orden puede tener un único escrow (relación 1:1).
/// Basado en el schema del backend PostgreSQL.
class Escrow {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID de la orden asociada (único, una orden solo puede tener un escrow)
  final String orderId;
  
  /// Proveedor del servicio de escrow (máx 40 caracteres)
  final String provider;
  
  /// Estado del escrow: "initiated", "funded", "released", "refunded", "cancelled"
  final String status;
  
  /// Fecha de creación del escrow
  final DateTime createdAt;
  
  /// Fecha de última actualización
  final DateTime updatedAt;
  
  /// Eventos del escrow (opcional, solo en respuestas detalladas)
  final List<EscrowEvent>? events;

  const Escrow({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.events,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Escrow.fromJson(Map<String, dynamic> json) {
    return Escrow(
      id: (json['id'] ?? json['uuid']).toString(),
      orderId: (json['order_id'] ?? json['orderId']).toString(),
      provider: json['provider'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      events: (json['events'] as List<dynamic>?)
          ?.map((e) => EscrowEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convierte a JSON para crear un escrow
  /// 
  /// Usa snake_case según el schema EscrowCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'provider': provider,
    };
  }

  /// Convierte a JSON para ejecutar una acción
  /// 
  /// Usa el schema EscrowAction del backend
  Map<String, dynamic> toActionJson(String action) {
    return {
      'action': action,
    };
  }

  /// Verifica si el escrow está iniciado
  bool get isInitiated => status.toLowerCase() == 'initiated';
  
  /// Verifica si el escrow está fondeado (pagado)
  bool get isFunded => status.toLowerCase() == 'funded';
  
  /// Verifica si el pago fue liberado al vendedor
  bool get isReleased => status.toLowerCase() == 'released';
  
  /// Verifica si el pago fue reembolsado al comprador
  bool get isRefunded => status.toLowerCase() == 'refunded';
  
  /// Verifica si el escrow fue cancelado
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  
  /// Verifica si el escrow está en un estado final (no puede cambiar)
  bool get isFinal => isReleased || isRefunded || isCancelled;
  
  /// Verifica si el escrow está activo (puede cambiar de estado)
  bool get isActive => !isFinal;

  /// Copia la instancia con campos modificados
  Escrow copyWith({
    String? id,
    String? orderId,
    String? provider,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<EscrowEvent>? events,
  }) {
    return Escrow(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      provider: provider ?? this.provider,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      events: events ?? this.events,
    );
  }

  @override
  String toString() => 'Escrow(id: $id, orderId: $orderId, provider: $provider, status: $status, events: ${events?.length ?? 0})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Escrow &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          provider == other.provider &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, orderId, provider, status, createdAt, updatedAt);
}

/// Modelo de Evento de Escrow
/// 
/// Representa un paso o evento en el proceso de escrow.
/// Usado para tracking del flujo de la transacción.
class EscrowEvent {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del escrow al que pertenece este evento
  final String escrowId;
  
  /// Paso del proceso: "listing_viewed", "chat_initiated", "payment_made", etc.
  final String step;
  
  /// Resultado del paso: "success", "cancelled", etc. (opcional)
  final String? result;
  
  /// Fecha en que ocurrió el evento
  final DateTime createdAt;

  const EscrowEvent({
    required this.id,
    required this.escrowId,
    required this.step,
    this.result,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  factory EscrowEvent.fromJson(Map<String, dynamic> json) {
    return EscrowEvent(
      id: (json['id'] ?? json['uuid']).toString(),
      escrowId: (json['escrow_id'] ?? json['escrowId']).toString(),
      step: json['step'] as String,
      result: json['result']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para crear un evento
  /// 
  /// Usa snake_case según el schema EscrowStepIn del backend
  Map<String, dynamic> toJson() {
    return {
      'escrow_id': escrowId,
      'step': step,
      'result': result ?? 'success',
    };
  }

  /// Verifica si el evento fue exitoso
  bool get isSuccess => result?.toLowerCase() == 'success';
  
  /// Verifica si el evento fue cancelado
  bool get isCancelled => result?.toLowerCase() == 'cancelled';

  /// Copia la instancia con campos modificados
  EscrowEvent copyWith({
    String? id,
    String? escrowId,
    String? step,
    String? result,
    DateTime? createdAt,
  }) {
    return EscrowEvent(
      id: id ?? this.id,
      escrowId: escrowId ?? this.escrowId,
      step: step ?? this.step,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'EscrowEvent(id: $id, escrowId: $escrowId, step: $step, result: $result, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EscrowEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          escrowId == other.escrowId &&
          step == other.step &&
          result == other.result &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, escrowId, step, result, createdAt);
}
