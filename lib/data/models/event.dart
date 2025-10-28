/// Modelo de Evento de Telemetría (Event)
/// 
/// Representa un evento de telemetría/analytics capturado en la aplicación.
/// Usado para tracking de comportamiento de usuario, funnel analysis, etc.
/// Basado en el schema del backend PostgreSQL.
class Event {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// Tipo de evento (máx 80 caracteres)
  /// Ejemplos: "listing_viewed", "chat_initiated", "click", "page_view"
  final String eventType;
  
  /// ID del usuario (opcional, puede ser anónimo)
  final String? userId;
  
  /// ID de sesión para agrupar eventos del mismo usuario (máx 64 caracteres)
  final String sessionId;
  
  /// ID del listing relacionado (opcional)
  final String? listingId;
  
  /// ID de la orden relacionada (opcional)
  final String? orderId;
  
  /// ID del chat relacionado (opcional)
  final String? chatId;
  
  /// Paso en un flujo (opcional, máx 40 caracteres)
  /// Ejemplo: "step_1", "checkout", "confirmation"
  final String? step;
  
  /// Propiedades adicionales del evento (JSON)
  /// Ejemplo: {"button_name": "buy_now", "price": 1000}
  final Map<String, dynamic> properties;
  
  /// Fecha/hora en que ocurrió el evento
  final DateTime occurredAt;

  const Event({
    required this.id,
    required this.eventType,
    this.userId,
    required this.sessionId,
    this.listingId,
    this.orderId,
    this.chatId,
    this.step,
    required this.properties,
    required this.occurredAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: (json['id'] ?? json['uuid']).toString(),
      eventType: (json['event_type'] ?? json['eventType']) as String,
      userId: (json['user_id'] ?? json['userId'])?.toString(),
      sessionId: (json['session_id'] ?? json['sessionId']) as String,
      listingId: (json['listing_id'] ?? json['listingId'])?.toString(),
      orderId: (json['order_id'] ?? json['orderId'])?.toString(),
      chatId: (json['chat_id'] ?? json['chatId'])?.toString(),
      step: json['step']?.toString(),
      properties: Map<String, dynamic>.from(json['properties'] as Map? ?? {}),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema TelemetryEventIn del backend
  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      if (listingId != null) 'listing_id': listingId,
      if (orderId != null) 'order_id': orderId,
      if (chatId != null) 'chat_id': chatId,
      if (step != null) 'step': step,
      'properties': properties,
      'occurred_at': occurredAt.toIso8601String(),
    };
  }

  /// Copia la instancia con campos modificados
  Event copyWith({
    String? id,
    String? eventType,
    String? userId,
    String? sessionId,
    String? listingId,
    String? orderId,
    String? chatId,
    String? step,
    Map<String, dynamic>? properties,
    DateTime? occurredAt,
  }) {
    return Event(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      listingId: listingId ?? this.listingId,
      orderId: orderId ?? this.orderId,
      chatId: chatId ?? this.chatId,
      step: step ?? this.step,
      properties: properties ?? this.properties,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  String toString() => 'Event(id: $id, eventType: $eventType, sessionId: $sessionId, userId: $userId, occurredAt: $occurredAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          eventType == other.eventType &&
          userId == other.userId &&
          sessionId == other.sessionId &&
          listingId == other.listingId &&
          orderId == other.orderId &&
          chatId == other.chatId &&
          step == other.step &&
          occurredAt == other.occurredAt;

  @override
  int get hashCode => Object.hash(
        id,
        eventType,
        userId,
        sessionId,
        listingId,
        orderId,
        chatId,
        step,
        occurredAt,
      );
}

/// Batch de eventos para envío eficiente
/// 
/// Agrupa múltiples eventos para enviarlos en una sola request.
/// Según el schema TelemetryBatchIn del backend.
class EventBatch {
  final List<Event> events;

  const EventBatch({required this.events});

  /// Convierte a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'events': events.map((e) => e.toJson()).toList(),
    };
  }

  /// Crea un batch desde una lista de eventos
  factory EventBatch.fromEvents(List<Event> events) {
    return EventBatch(events: events);
  }
}
