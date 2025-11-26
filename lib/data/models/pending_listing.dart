import 'dart:convert';

/// Se usa cuando el usuario crea un post sin conexión.
/// Los datos se guardan localmente y se intentan subir cuando hay internet.
class PendingListing {
  final String id; 
  final String title;
  final String? description;
  final String categoryId;
  final String? brandId;
  final int priceCents;
  final String currency;
  final String condition;
  final int quantity;
  final double? latitude;
  final double? longitude;
  final bool priceSuggestionUsed;
  
  // Datos de la imagen
  final String? imageBase64; // Imagen comprimida en base64
  final String? imageName;
  final String? imageContentType;
  
  // Metadata de la cola
  final DateTime createdAt;
  final DateTime lastAttemptAt;
  final int attemptCount;
  final String status;
  final String? errorMessage;

  const PendingListing({
    required this.id,
    required this.title,
    this.description,
    required this.categoryId,
    this.brandId,
    required this.priceCents,
    required this.currency,
    required this.condition,
    required this.quantity,
    this.latitude,
    this.longitude,
    required this.priceSuggestionUsed,
    this.imageBase64,
    this.imageName,
    this.imageContentType,
    required this.createdAt,
    required this.lastAttemptAt,
    required this.attemptCount,
    required this.status,
    this.errorMessage,
  });

  /// Crea una copia con campos modificados
  PendingListing copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    String? brandId,
    int? priceCents,
    String? currency,
    String? condition,
    int? quantity,
    double? latitude,
    double? longitude,
    bool? priceSuggestionUsed,
    String? imageBase64,
    String? imageName,
    String? imageContentType,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? attemptCount,
    String? status,
    String? errorMessage,
  }) {
    return PendingListing(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      priceCents: priceCents ?? this.priceCents,
      currency: currency ?? this.currency,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      priceSuggestionUsed: priceSuggestionUsed ?? this.priceSuggestionUsed,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageName: imageName ?? this.imageName,
      imageContentType: imageContentType ?? this.imageContentType,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convierte a JSON para almacenamiento local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'brand_id': brandId,
      'price_cents': priceCents,
      'currency': currency,
      'condition': condition,
      'quantity': quantity,
      'latitude': latitude,
      'longitude': longitude,
      'price_suggestion_used': priceSuggestionUsed,
      'image_base64': imageBase64,
      'image_name': imageName,
      'image_content_type': imageContentType,
      'created_at': createdAt.toIso8601String(),
      'last_attempt_at': lastAttemptAt.toIso8601String(),
      'attempt_count': attemptCount,
      'status': status,
      'error_message': errorMessage,
    };
  }

  /// Crea desde JSON
  factory PendingListing.fromJson(Map<String, dynamic> json) {
    return PendingListing(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String,
      brandId: json['brand_id'] as String?,
      priceCents: json['price_cents'] as int,
      currency: json['currency'] as String? ?? 'COP',
      condition: json['condition'] as String,
      quantity: json['quantity'] as int? ?? 1,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      priceSuggestionUsed: json['price_suggestion_used'] as bool? ?? false,
      imageBase64: json['image_base64'] as String?,
      imageName: json['image_name'] as String?,
      imageContentType: json['image_content_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastAttemptAt: DateTime.parse(json['last_attempt_at'] as String),
      attemptCount: json['attempt_count'] as int,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
    );
  }

  /// Convierte la imagen base64 a bytes
  List<int>? getImageBytes() {
    if (imageBase64 == null) return null;
    try {
      return base64Decode(imageBase64!);
    } catch (e) {
      print('[PendingListing] Error al decodificar imagen: $e');
      return null;
    }
  }

  bool get shouldRetry => attemptCount < 5 && status != 'completed';

  bool get isUploading => status == 'uploading';

  bool get isFailed => status == 'failed';

  bool get isCompleted => status == 'completed';

  @override
  String toString() {
    return 'PendingListing(id: $id, title: $title, status: $status, attempts: $attemptCount)';
  }
}

