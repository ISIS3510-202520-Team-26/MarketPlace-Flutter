/// Modelo de Sugerencia de Precio (PriceSuggestion)
/// 
/// Representa una sugerencia de precio generada para un listing.
/// Basado en el schema del backend PostgreSQL.
class PriceSuggestion {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del listing para el que se generó la sugerencia
  final String listingId;
  
  /// Precio sugerido en centavos
  final int suggestedPriceCents;
  
  /// Algoritmo usado para generar la sugerencia (máx 40 caracteres)
  /// Ejemplos: "p50" (mediana), "p75" (percentil 75), "ml_model", "avg"
  final String algorithm;
  
  /// Fecha de creación de la sugerencia
  final DateTime createdAt;

  const PriceSuggestion({
    required this.id,
    required this.listingId,
    required this.suggestedPriceCents,
    required this.algorithm,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory PriceSuggestion.fromJson(Map<String, dynamic> json) {
    return PriceSuggestion(
      id: (json['id'] ?? json['uuid']).toString(),
      listingId: (json['listing_id'] ?? json['listingId']).toString(),
      suggestedPriceCents: (json['suggested_price_cents'] ?? json['suggestedPriceCents']) as int,
      algorithm: (json['algorithm'] as String?) ?? 'p50',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para crear una sugerencia
  /// 
  /// Usa snake_case según el schema PriceSuggestionCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'suggested_price_cents': suggestedPriceCents,
      'algorithm': algorithm,
    };
  }

  /// Precio sugerido en unidades monetarias (divide cents por 100)
  double get suggestedPrice => suggestedPriceCents / 100.0;

  /// Copia la instancia con campos modificados
  PriceSuggestion copyWith({
    String? id,
    String? listingId,
    int? suggestedPriceCents,
    String? algorithm,
    DateTime? createdAt,
  }) {
    return PriceSuggestion(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      suggestedPriceCents: suggestedPriceCents ?? this.suggestedPriceCents,
      algorithm: algorithm ?? this.algorithm,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'PriceSuggestion(id: $id, listingId: $listingId, suggestedPrice: \$$suggestedPrice, algorithm: $algorithm)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceSuggestion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          listingId == other.listingId &&
          suggestedPriceCents == other.suggestedPriceCents &&
          algorithm == other.algorithm &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, listingId, suggestedPriceCents, algorithm, createdAt);
}

/// Request para solicitar sugerencia de precio
/// 
/// Según el schema SuggestQuery del backend
class PriceSuggestionRequest {
  final String? categoryId;
  final String? brandId;

  const PriceSuggestionRequest({
    this.categoryId,
    this.brandId,
  });

  factory PriceSuggestionRequest.fromJson(Map<String, dynamic> json) {
    return PriceSuggestionRequest(
      categoryId: (json['category_id'] ?? json['categoryId'])?.toString(),
      brandId: (json['brand_id'] ?? json['brandId'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
    };
  }
}

/// Request para computar sugerencia de precio
/// 
/// Según el schema ComputeIn del backend
class ComputePriceRequest {
  final String? categoryId;
  final String? brandId;

  const ComputePriceRequest({
    this.categoryId,
    this.brandId,
  });

  factory ComputePriceRequest.fromJson(Map<String, dynamic> json) {
    return ComputePriceRequest(
      categoryId: (json['category_id'] ?? json['categoryId'])?.toString(),
      brandId: (json['brand_id'] ?? json['brandId'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
    };
  }
}

/// Algoritmos de sugerencia de precio comunes
class PriceSuggestionAlgorithm {
  static const String p50 = 'p50'; // Mediana (percentil 50)
  static const String p75 = 'p75'; // Percentil 75
  static const String avg = 'avg'; // Promedio
  static const String mlModel = 'ml_model'; // Modelo de ML
  
  /// Lista de algoritmos disponibles
  static const List<String> all = [p50, p75, avg, mlModel];
}
