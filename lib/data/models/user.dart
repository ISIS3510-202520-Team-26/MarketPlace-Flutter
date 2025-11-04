/// Modelo de Usuario (User)
/// 
/// Representa un usuario registrado en la plataforma.
/// Basado en el schema del backend PostgreSQL.
class User {
  /// ID único (UUID generado por el servidor)
  final String id;
  
  /// Nombre del usuario (máx 120 caracteres)
  final String name;
  
  /// Email del usuario (único, máx 320 caracteres)
  final String email;
  
  /// Campus/universidad del usuario (opcional, máx 120 caracteres)
  final String? campus;
  
  /// Fecha de creación de la cuenta
  final DateTime createdAt;
  
  /// Fecha del último login (opcional)
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.campus,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Crea una instancia desde JSON del backend
  /// 
  /// Maneja tanto snake_case (backend) como camelCase (legacy)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['uuid']).toString(),
      name: json['name'] as String,
      email: json['email'] as String,
      campus: json['campus']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  /// Convierte a JSON para actualizar el usuario
  /// 
  /// Usa snake_case según el schema UserUpdate del backend
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (campus != null) 'campus': campus,
    };
  }

  /// Convierte a JSON completo (para cache/storage)
  /// 
  /// Incluye todos los campos del usuario
  Map<String, dynamic> toFullJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (campus != null) 'campus': campus,
      'created_at': createdAt.toIso8601String(),
      if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toIso8601String(),
    };
  }

  /// Verifica si tiene campus configurado
  bool get hasCampus => campus != null && campus!.isNotEmpty;
  
  /// Verifica si ha iniciado sesión alguna vez
  bool get hasLoggedIn => lastLoginAt != null;
  
  /// Obtiene las iniciales del nombre (máximo 2 caracteres)
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  
  /// Obtiene el primer nombre
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts[0] : name;
  }

  /// Copia la instancia con campos modificados
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? campus,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      campus: campus ?? this.campus,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  String toString() => 'User(id: $id, name: $name, email: $email, campus: $campus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          campus == other.campus &&
          createdAt == other.createdAt &&
          lastLoginAt == other.lastLoginAt;

  @override
  int get hashCode => Object.hash(id, name, email, campus, createdAt, lastLoginAt);
}

/// Request para crear un usuario (registro)
/// 
/// Según el schema UserCreate/RegisterIn del backend
class UserRegisterRequest {
  final String name;
  final String email;
  final String password;
  final String? campus;

  const UserRegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    this.campus,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      if (campus != null && campus!.isNotEmpty) 'campus': campus,
    };
  }
}

/// Request para iniciar sesión
/// 
/// Según el schema LoginIn del backend
class UserLoginRequest {
  final String email;
  final String password;

  const UserLoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

/// Response con tokens de autenticación
/// 
/// Según el schema TokenPair del backend
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
    };
  }
}

/// Request para refrescar el token de acceso
/// 
/// Según el schema RefreshIn del backend
class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() {
    return {
      'refresh_token': refreshToken,
    };
  }
}

/// Request para match de contactos
/// 
/// Según el schema ContactsMatchIn del backend
class ContactsMatchRequest {
  /// Lista de hashes SHA-256 de emails (64 caracteres hexadecimales)
  final List<String> emailHashes;

  const ContactsMatchRequest({required this.emailHashes});

  factory ContactsMatchRequest.fromJson(Map<String, dynamic> json) {
    return ContactsMatchRequest(
      emailHashes: List<String>.from(json['email_hashes'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email_hashes': emailHashes,
    };
  }
}

/// Response de un contacto que hizo match
/// 
/// Según el schema ContactMatchOut del backend
class ContactMatch {
  final String userId;
  final String name;
  final String email;

  const ContactMatch({
    required this.userId,
    required this.name,
    required this.email,
  });

  factory ContactMatch.fromJson(Map<String, dynamic> json) {
    return ContactMatch(
      userId: (json['user_id'] ?? json['userId']).toString(),
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
    };
  }
}
