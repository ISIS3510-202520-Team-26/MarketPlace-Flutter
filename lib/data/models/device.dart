/// Modelo de Dispositivo (Device)
/// 
/// Representa un dispositivo móvil registrado para un usuario.
/// Usado para push notifications y analytics.
/// Basado en el schema del backend PostgreSQL.
class Device {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// ID del usuario propietario del dispositivo
  final String userId;
  
  /// Plataforma del dispositivo: "android" o "ios"
  final String platform;
  
  /// Token para push notifications (opcional)
  final String? pushToken;
  
  /// Versión de la app instalada (opcional, máx 40 caracteres)
  final String? appVersion;
  
  /// Fecha de registro del dispositivo
  final DateTime createdAt;

  const Device({
    required this.id,
    required this.userId,
    required this.platform,
    this.pushToken,
    this.appVersion,
    required this.createdAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: (json['id'] ?? json['uuid']).toString(),
      userId: (json['user_id'] ?? json['userId']).toString(),
      platform: json['platform'] as String,
      pushToken: json['push_token']?.toString(),
      appVersion: json['app_version']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte a JSON para enviar al backend
  /// 
  /// Usa snake_case según el schema DeviceCreate del backend
  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      if (pushToken != null) 'push_token': pushToken,
      if (appVersion != null) 'app_version': appVersion,
    };
  }

  /// Verifica si el dispositivo es Android
  bool get isAndroid => platform.toLowerCase() == 'android';
  
  /// Verifica si el dispositivo es iOS
  bool get isIOS => platform.toLowerCase() == 'ios';
  
  /// Verifica si tiene token de push configurado
  bool get hasPushToken => pushToken != null && pushToken!.isNotEmpty;

  /// Copia la instancia con campos modificados
  Device copyWith({
    String? id,
    String? userId,
    String? platform,
    String? pushToken,
    String? appVersion,
    DateTime? createdAt,
  }) {
    return Device(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      pushToken: pushToken ?? this.pushToken,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Device(id: $id, userId: $userId, platform: $platform, appVersion: $appVersion, hasPushToken: $hasPushToken)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          platform == other.platform &&
          pushToken == other.pushToken &&
          appVersion == other.appVersion &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, userId, platform, pushToken, appVersion, createdAt);
}
