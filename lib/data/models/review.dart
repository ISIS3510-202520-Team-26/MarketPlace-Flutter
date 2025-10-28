/// Modelo de Reseña (Review)
/// 
/// Representa una reseña/calificación de un usuario a otro después de una transacción.
/// Una orden solo puede tener una reseña (relación 1:1).
/// Basado en el schema del backend PostgreSQL.
class Review {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID de la orden sobre la que se hace la reseña (único)
  final String orderId;
  
  /// ID del usuario que califica
  final String raterId;
  
  /// ID del usuario que recibe la calificación
  final String rateeId;
  
  /// Calificación de 1 a 5 estrellas
  final int rating;
  
  /// Comentario de la reseña (opcional, máx 2000 caracteres)
  final String? comment;
  
  /// Fecha de creación de la reseña
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.orderId,
    required this.raterId,
    required this.rateeId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] ?? json['uuid']).toString(),
      orderId: (json['order_id'] ?? json['orderId']).toString(),
      raterId: (json['rater_id'] ?? json['raterId']).toString(),
      rateeId: (json['ratee_id'] ?? json['rateeId']).toString(),
      rating: json['rating'] as int,
      comment: json['comment']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para crear una reseña
  /// 
  /// Usa snake_case según el schema ReviewCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'ratee_id': rateeId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    };
  }

  /// Verifica si la calificación es positiva (4-5 estrellas)
  bool get isPositive => rating >= 4;
  
  /// Verifica si la calificación es neutral (3 estrellas)
  bool get isNeutral => rating == 3;
  
  /// Verifica si la calificación es negativa (1-2 estrellas)
  bool get isNegative => rating <= 2;
  
  /// Verifica si tiene comentario
  bool get hasComment => comment != null && comment!.isNotEmpty;
  
  /// Obtiene el rating como porcentaje (0.0 - 1.0)
  double get ratingNormalized => rating / 5.0;
  
  /// Obtiene el rating como porcentaje (0 - 100)
  int get ratingPercentage => (ratingNormalized * 100).round();

  /// Copia la instancia con campos modificados
  Review copyWith({
    String? id,
    String? orderId,
    String? raterId,
    String? rateeId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      raterId: raterId ?? this.raterId,
      rateeId: rateeId ?? this.rateeId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Review(id: $id, orderId: $orderId, rating: $rating, hasComment: $hasComment, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Review &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          raterId == other.raterId &&
          rateeId == other.rateeId &&
          rating == other.rating &&
          comment == other.comment &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, orderId, raterId, rateeId, rating, comment, createdAt);
}

/// Constantes de calificaciones
class ReviewRating {
  static const int min = 1;
  static const int max = 5;
  static const int neutral = 3;
  
  /// Verifica si una calificación es válida
  static bool isValid(int rating) => rating >= min && rating <= max;
  
  /// Clamp una calificación al rango válido
  static int clamp(int rating) => rating.clamp(min, max);
}
