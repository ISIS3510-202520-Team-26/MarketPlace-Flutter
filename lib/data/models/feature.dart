/// Modelo de Feature (Característica)
/// 
/// Representa una característica de la aplicación con feature flags.
/// Usado para activar/desactivar funcionalidades y A/B testing.
/// Basado en el schema del backend PostgreSQL.
class Feature {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// Clave única de la feature (máx 80 caracteres)
  /// Ejemplo: "new_checkout", "dark_mode", "chat_v2"
  final String key;
  
  /// Nombre descriptivo de la feature (máx 120 caracteres)
  final String name;
  
  /// Fecha de despliegue de la feature (opcional)
  final DateTime? deployedAt;
  
  /// Feature flags asociados (opcional, solo en respuestas detalladas)
  final List<FeatureFlag>? flags;

  const Feature({
    required this.id,
    required this.key,
    required this.name,
    this.deployedAt,
    this.flags,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      id: (json['id'] ?? json['uuid']).toString(),
      key: json['key'] as String,
      name: json['name'] as String,
      deployedAt: json['deployed_at'] != null
          ? DateTime.parse(json['deployed_at'] as String)
          : null,
      flags: (json['flags'] as List<dynamic>?)
          ?.map((f) => FeatureFlag.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema FeatureCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
    };
  }

  /// Verifica si la feature está desplegada
  bool get isDeployed => deployedAt != null;
  
  /// Verifica si algún flag está habilitado
  bool get hasEnabledFlags => flags?.any((f) => f.enabled) ?? false;

  /// Copia la instancia con campos modificados
  Feature copyWith({
    String? id,
    String? key,
    String? name,
    DateTime? deployedAt,
    List<FeatureFlag>? flags,
  }) {
    return Feature(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      deployedAt: deployedAt ?? this.deployedAt,
      flags: flags ?? this.flags,
    );
  }

  @override
  String toString() => 'Feature(id: $id, key: $key, name: $name, isDeployed: $isDeployed, flags: ${flags?.length ?? 0})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Feature &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          key == other.key &&
          name == other.name &&
          deployedAt == other.deployedAt;

  @override
  int get hashCode => Object.hash(id, key, name, deployedAt);
}

/// Modelo de Feature Flag
/// 
/// Representa un flag para activar/desactivar una feature según el scope.
/// Scopes: "global" (todos), "user" (por usuario), "segment" (por segmento).
class FeatureFlag {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID de la feature asociada
  final String featureId;
  
  /// Alcance del flag: "global", "user", o "segment"
  final String scope;
  
  /// Si el flag está habilitado o no
  final bool enabled;
  
  /// Fecha de creación del flag
  final DateTime createdAt;

  const FeatureFlag({
    required this.id,
    required this.featureId,
    required this.scope,
    required this.enabled,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      id: (json['id'] ?? json['uuid']).toString(),
      featureId: (json['feature_id'] ?? json['featureId']).toString(),
      scope: json['scope'] as String,
      enabled: json['enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema FeatureFlagCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'feature_id': featureId,
      'scope': scope,
      'enabled': enabled,
    };
  }

  /// Verifica si el scope es global
  bool get isGlobal => scope.toLowerCase() == 'global';
  
  /// Verifica si el scope es por usuario
  bool get isUser => scope.toLowerCase() == 'user';
  
  /// Verifica si el scope es por segmento
  bool get isSegment => scope.toLowerCase() == 'segment';

  /// Copia la instancia con campos modificados
  FeatureFlag copyWith({
    String? id,
    String? featureId,
    String? scope,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return FeatureFlag(
      id: id ?? this.id,
      featureId: featureId ?? this.featureId,
      scope: scope ?? this.scope,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'FeatureFlag(id: $id, featureId: $featureId, scope: $scope, enabled: $enabled, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlag &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          featureId == other.featureId &&
          scope == other.scope &&
          enabled == other.enabled &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, featureId, scope, enabled, createdAt);
}

/// Request para verificar si una feature está habilitada
/// 
/// Según el schema FeatureUseIn del backend
class FeatureUseRequest {
  final String featureKey;

  const FeatureUseRequest({required this.featureKey});

  Map<String, dynamic> toJson() {
    return {
      'feature_key': featureKey,
    };
  }
}
