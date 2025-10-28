/// Modelo de Categoría (Category)
/// 
/// Representa una categoría de productos.
/// Las categorías pueden tener múltiples brands y listings asociados.
/// Basado en el schema del backend PostgreSQL.
class Category {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// Slug único para URLs amigables (máx 60 caracteres)
  final String slug;
  
  /// Nombre de la categoría (máx 80 caracteres)
  final String name;

  const Category({
    required this.id,
    required this.slug,
    required this.name,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['id'] ?? json['uuid']).toString(),
      slug: json['slug'] as String,
      name: json['name'] as String,
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema CategoryCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'name': name,
    };
  }

  /// Copia la instancia con campos modificados
  Category copyWith({
    String? id,
    String? slug,
    String? name,
  }) {
    return Category(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'Category(id: $id, slug: $slug, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          slug == other.slug &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, slug, name);
}
