/// Modelo de Sugerencia de Precio (PriceSuggestion)
/// 
/// Representa una sugerencia de precio generada para un listing.
/// Soporta múltiples estrategias: local_median, prior_only, prior+local_mix,
/// msrp_heuristic, hardcoded_fallback
class PriceSuggestion {
  /// ID único (UUID generado por el servidor) - opcional en respuestas GET
  final String? id;
  
  /// ID del listing para el que se generó la sugerencia - opcional
  final String? listingId;
  
  /// Precio sugerido en centavos (valor redondeado final)
  final int suggestedPriceCents;
  
  /// Algoritmo/estrategia usado para generar la sugerencia
  /// Valores: local_median, prior_only, prior+local_mix, msrp_heuristic, hardcoded_fallback
  final String algorithm;
  
  /// Fecha de creación de la sugerencia - opcional
  final DateTime? createdAt;

  // Metadatos adicionales del análisis (solo en GET/POST, no se guardan en DB)
  final int? p25;  // Percentil 25
  final int? p50;  // Percentil 50 (mediana)
  final int? p75;  // Percentil 75
  final int? n;    // Tamaño de muestra usado
  final String? source; // Fuente de datos (normalmente igual a algorithm)

  const PriceSuggestion({
    this.id,
    this.listingId,
    required this.suggestedPriceCents,
    required this.algorithm,
    this.createdAt,
    this.p25,
    this.p50,
    this.p75,
    this.n,
    this.source,
  });

  /// Crea una instancia desde JSON del backend
  factory PriceSuggestion.fromJson(Map<String, dynamic> json) {
    return PriceSuggestion(
      id: json['id']?.toString(),
      listingId: json['listing_id']?.toString(),
      suggestedPriceCents: json['suggested_price_cents'] as int,
      algorithm: json['algorithm'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      p25: json['p25'] as int?,
      p50: json['p50'] as int?,
      p75: json['p75'] as int?,
      n: json['n'] as int?,
      source: json['source'] as String?,
    );
  }

  /// Convierte a JSON para crear una sugerencia
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (listingId != null) 'listing_id': listingId,
      'suggested_price_cents': suggestedPriceCents,
      'algorithm': algorithm,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (p25 != null) 'p25': p25,
      if (p50 != null) 'p50': p50,
      if (p75 != null) 'p75': p75,
      if (n != null) 'n': n,
      if (source != null) 'source': source,
    };
  }

  /// Precio sugerido en unidades monetarias
  double get suggestedPrice => suggestedPriceCents / 100.0;

  /// Verifica si hay rango de precios disponible (p25-p75)
  bool get hasPriceRange => p25 != null && p75 != null;

  /// Descripción legible del algoritmo usado
  String get algorithmDescription {
    switch (algorithm) {
      case 'local_median':
        return 'Basado en listings similares recientes';
      case 'prior_only':
        return 'Basado en históricos de categoría/marca';
      case 'prior+local_mix':
        return 'Mezcla de históricos + mercado actual';
      case 'msrp_heuristic':
        return 'Estimado desde precio sugerido (MSRP)';
      case 'hardcoded_fallback':
        return 'Estimación por defecto';
      default:
        return algorithm;
    }
  }

  /// Nivel de confianza basado en tamaño de muestra
  String get confidenceLevel {
    if (n == null || n == 0) return 'Baja';
    if (n! < 5) return 'Baja';
    if (n! < 15) return 'Media';
    return 'Alta';
  }

  @override
  String toString() => 'PriceSuggestion(suggested: \$$suggestedPrice, algorithm: $algorithm, n: $n)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceSuggestion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          suggestedPriceCents == other.suggestedPriceCents &&
          algorithm == other.algorithm;

  @override
  int get hashCode => Object.hash(id, suggestedPriceCents, algorithm);
}

/// Request para solicitar sugerencia de precio
/// 
/// Soporta parámetros opcionales para condición, MSRP y depreciación
class PriceSuggestionRequest {
  final String categoryId;
  final String? brandId;
  final String? condition; // new, like_new, good, fair, poor
  final int? msrpCents;
  final int? monthsSinceRelease;
  final int? roundingQuantum; // default 100

  const PriceSuggestionRequest({
    required this.categoryId,
    this.brandId,
    this.condition,
    this.msrpCents,
    this.monthsSinceRelease,
    this.roundingQuantum,
  });

  Map<String, dynamic> toQueryParams() {
    return {
      'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      if (condition != null) 'condition': condition,
      if (msrpCents != null) 'msrp_cents': msrpCents,
      if (monthsSinceRelease != null) 'months_since_release': monthsSinceRelease,
      if (roundingQuantum != null) 'rounding_quantum': roundingQuantum,
    };
  }
}

/// Request para computar y guardar sugerencia de precio
class ComputePriceRequest {
  final String categoryId;
  final String? brandId;
  final String? condition;
  final int? msrpCents;
  final int? monthsSinceRelease;
  final int? roundingQuantum;

  const ComputePriceRequest({
    required this.categoryId,
    this.brandId,
    this.condition,
    this.msrpCents,
    this.monthsSinceRelease,
    this.roundingQuantum,
  });

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      if (condition != null) 'condition': condition,
      if (msrpCents != null) 'msrp_cents': msrpCents,
      if (monthsSinceRelease != null) 'months_since_release': monthsSinceRelease,
      if (roundingQuantum != null) 'rounding_quantum': roundingQuantum,
    };
  }
}

/// Algoritmos de sugerencia de precio
class PriceSuggestionAlgorithm {
  static const String localMedian = 'local_median';
  static const String priorOnly = 'prior_only';
  static const String priorLocalMix = 'prior+local_mix';
  static const String msrpHeuristic = 'msrp_heuristic';
  static const String hardcodedFallback = 'hardcoded_fallback';
  
  /// Lista de algoritmos disponibles
  static const List<String> all = [
    localMedian,
    priorOnly,
    priorLocalMix,
    msrpHeuristic,
    hardcodedFallback,
  ];
}

/// Condiciones soportadas para productos
class ProductCondition {
  static const String newCondition = 'new';
  static const String likeNew = 'like_new';
  static const String good = 'good';
  static const String fair = 'fair';
  static const String poor = 'poor';
  
  static const List<String> all = [newCondition, likeNew, good, fair, poor];
  
  static String getLabel(String condition) {
    switch (condition) {
      case newCondition: return 'Nuevo';
      case likeNew: return 'Como nuevo';
      case good: return 'Bueno';
      case fair: return 'Aceptable';
      case poor: return 'Malo';
      default: return condition;
    }
  }
}

