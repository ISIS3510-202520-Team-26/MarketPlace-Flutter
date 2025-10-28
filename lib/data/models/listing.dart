import 'listing_photo.dart';

/// Modelo de Listing (Publicación)
/// 
/// Representa un producto o servicio publicado para venta.
/// Basado en el schema del backend PostgreSQL.
class Listing {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del vendedor
  final String sellerId;
  
  /// Título del listing (máx 140 caracteres)
  final String title;
  
  /// Descripción detallada (opcional)
  final String? description;
  
  /// ID de la categoría
  final String categoryId;
  
  /// ID de la marca (opcional)
  final String? brandId;
  
  /// Precio en centavos (para evitar problemas con decimales)
  final int priceCents;
  
  /// Moneda (código ISO 4217, 3 caracteres)
  final String currency;
  
  /// Condición del producto (opcional, máx 40 caracteres)
  /// Ejemplos: "new", "like_new", "used", "refurbished"
  final String? condition;
  
  /// Cantidad disponible
  final int quantity;
  
  /// Si el listing está activo
  final bool isActive;
  
  /// Latitud de ubicación (opcional)
  final double? latitude;
  
  /// Longitud de ubicación (opcional)
  final double? longitude;
  
  /// Si se usó sugerencia de precio
  final bool priceSuggestionUsed;
  
  /// Si está habilitada la vista rápida
  final bool quickViewEnabled;
  
  /// Fecha de creación
  final DateTime createdAt;
  
  /// Fecha de última actualización
  final DateTime updatedAt;
  
  /// Fotos del listing (opcional, solo en respuestas detalladas)
  final List<ListingPhoto>? photos;

  const Listing({
    required this.id,
    required this.sellerId,
    required this.title,
    this.description,
    required this.categoryId,
    this.brandId,
    required this.priceCents,
    required this.currency,
    this.condition,
    required this.quantity,
    required this.isActive,
    this.latitude,
    this.longitude,
    required this.priceSuggestionUsed,
    required this.quickViewEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.photos,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: (json['id'] ?? json['uuid']).toString(),
      sellerId: (json['seller_id'] ?? json['sellerId']).toString(),
      title: json['title'] as String,
      description: json['description']?.toString(),
      categoryId: (json['category_id'] ?? json['categoryId']).toString(),
      brandId: (json['brand_id'] ?? json['brandId'])?.toString(),
      priceCents: (json['price_cents'] ?? json['priceCents']) as int,
      currency: (json['currency'] as String?) ?? 'COP',
      condition: json['condition']?.toString(),
      quantity: (json['quantity'] as int?) ?? 1,
      isActive: (json['is_active'] ?? json['isActive'] ?? true) as bool,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      priceSuggestionUsed: (json['price_suggestion_used'] ?? json['priceSuggestionUsed'] ?? false) as bool,
      quickViewEnabled: (json['quick_view_enabled'] ?? json['quickViewEnabled'] ?? true) as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      photos: (json['photos'] as List<dynamic>?)
          ?.map((p) => ListingPhoto.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convierte a JSON para crear un listing
  /// 
  /// Usa snake_case según el schema ListingCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      'price_cents': priceCents,
      'currency': currency,
      if (condition != null) 'condition': condition,
      'quantity': quantity,
      if (latitude != null && longitude != null) 'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'price_suggestion_used': priceSuggestionUsed,
      'quick_view_enabled': quickViewEnabled,
    };
  }

  /// Convierte a JSON para actualizar un listing
  /// 
  /// Usa snake_case según el schema ListingUpdate del backend
  /// Solo incluye campos que no son null
  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      'price_cents': priceCents,
      'currency': currency,
      if (condition != null) 'condition': condition,
      'quantity': quantity,
      if (latitude != null && longitude != null) 'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'price_suggestion_used': priceSuggestionUsed,
      'quick_view_enabled': quickViewEnabled,
      'is_active': isActive,
    };
  }

  /// Precio en unidades monetarias (divide cents por 100)
  double get price => priceCents / 100.0;
  
  /// Verifica si tiene ubicación
  bool get hasLocation => latitude != null && longitude != null;
  
  /// Verifica si tiene fotos
  bool get hasPhotos => photos != null && photos!.isNotEmpty;
  
  /// Verifica si tiene descripción
  bool get hasDescription => description != null && description!.isNotEmpty;
  
  /// Verifica si está disponible (activo y con cantidad > 0)
  bool get isAvailable => isActive && quantity > 0;
  
  /// Obtiene la primera foto (foto principal)
  ListingPhoto? get mainPhoto => photos?.isNotEmpty == true ? photos!.first : null;

  /// Copia la instancia con campos modificados
  Listing copyWith({
    String? id,
    String? sellerId,
    String? title,
    String? description,
    String? categoryId,
    String? brandId,
    int? priceCents,
    String? currency,
    String? condition,
    int? quantity,
    bool? isActive,
    double? latitude,
    double? longitude,
    bool? priceSuggestionUsed,
    bool? quickViewEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ListingPhoto>? photos,
  }) {
    return Listing(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      priceCents: priceCents ?? this.priceCents,
      currency: currency ?? this.currency,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      priceSuggestionUsed: priceSuggestionUsed ?? this.priceSuggestionUsed,
      quickViewEnabled: quickViewEnabled ?? this.quickViewEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photos: photos ?? this.photos,
    );
  }

  @override
  String toString() => 'Listing(id: $id, title: $title, price: \$$price $currency, isActive: $isActive, photos: ${photos?.length ?? 0})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Listing &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sellerId == other.sellerId &&
          title == other.title &&
          description == other.description &&
          categoryId == other.categoryId &&
          brandId == other.brandId &&
          priceCents == other.priceCents &&
          currency == currency &&
          condition == other.condition &&
          quantity == other.quantity &&
          isActive == other.isActive &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          priceSuggestionUsed == other.priceSuggestionUsed &&
          quickViewEnabled == other.quickViewEnabled &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        sellerId,
        title,
        description,
        categoryId,
        brandId,
        priceCents,
        currency,
        condition,
        quantity,
        isActive,
        latitude,
        longitude,
        priceSuggestionUsed,
        quickViewEnabled,
        createdAt,
        updatedAt,
      );
}
