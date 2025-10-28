/// Modelo de Marca (Brand)
/// 
/// Representa una marca de producto asociada opcionalmente a una categoría.
/// Basado en el schema del backend PostgreSQL.
class Brand {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// Nombre de la marca (máx 100 caracteres)
  final String name;
  
  /// Slug único para URLs amigables (máx 100 caracteres)
  final String slug;
  
  /// ID de la categoría asociada (opcional)
  final String? categoryId;

  const Brand({
    required this.id,
    required this.name,
    required this.slug,
    this.categoryId,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: (json['id'] ?? json['uuid']).toString(),
      name: json['name'] as String,
      slug: json['slug'] as String,
      categoryId: (json['category_id'] ?? json['categoryId'])?.toString(),
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema BrandCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      if (categoryId != null) 'category_id': categoryId,
    };
  }

  /// Copia la instancia con campos modificados
  Brand copyWith({
    String? id,
    String? name,
    String? slug,
    String? categoryId,
  }) {
    return Brand(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  @override
  String toString() => 'Brand(id: $id, name: $name, slug: $slug, categoryId: $categoryId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Brand &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          slug == other.slug &&
          categoryId == other.categoryId;

  @override
  int get hashCode => Object.hash(id, name, slug, categoryId);
}