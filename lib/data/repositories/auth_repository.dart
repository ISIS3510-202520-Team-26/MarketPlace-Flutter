import 'package:dio/dio.dart';
import '../models/user.dart';
import '../../core/net/dio_client.dart';
import '../../core/security/token_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Repository para el dominio de Autenticación y Usuarios
/// 
/// Agrupa operaciones relacionadas con registro, login, tokens y gestión de usuarios.
/// Basado en los repositories y endpoints del backend.
class AuthRepository {
  final Dio _dio = DioClient.instance.dio;

  // ==================== AUTHENTICATION ====================

  /// Registra un nuevo usuario
  /// 
  /// POST /auth/register
  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? campus,
  }) async {
    try {
      final request = UserRegisterRequest(
        name: name,
        email: email,
        password: password,
        campus: campus,
      );
      
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
      );
      
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error en registro');
    }
  }

  /// Inicia sesión con email y contraseña
  /// 
  /// POST /auth/login
  /// 
  /// Guarda automáticamente los tokens en TokenStorage
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final request = UserLoginRequest(
        email: email,
        password: password,
      );
      
      final response = await _dio.post(
        '/auth/login',
        data: request.toJson(),
      );
      
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      
      // Guardar tokens automáticamente
      await TokenStorage.instance.saveTokens(
        tokens.accessToken,
        tokens.refreshToken,
      );
      
      return tokens;
    } on DioException catch (e) {
      throw _handleError(e, 'Error en login');
    }
  }

  /// Refresca el access token usando el refresh token
  /// 
  /// POST /auth/refresh
  /// 
  /// Guarda automáticamente los nuevos tokens
  Future<AuthTokens> refreshToken({String? refreshToken}) async {
    try {
      // Si no se proporciona, obtener del storage
      final token = refreshToken ?? await TokenStorage.instance.readRefreshToken();
      
      if (token == null) {
        throw 'No hay refresh token disponible';
      }
      
      final request = RefreshTokenRequest(refreshToken: token);
      
      final response = await _dio.post(
        '/auth/refresh',
        data: request.toJson(),
      );
      
      final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
      
      // Guardar nuevos tokens
      await TokenStorage.instance.saveTokens(
        tokens.accessToken,
        tokens.refreshToken,
      );
      
      return tokens;
    } on DioException catch (e) {
      // Si el refresh token es inválido, limpiar storage
      if (e.response?.statusCode == 401) {
        await TokenStorage.instance.clear();
      }
      throw _handleError(e, 'Error al refrescar token');
    }
  }

  /// Cierra sesión del usuario actual
  /// 
  /// Limpia los tokens del storage local
  Future<void> logout() async {
    try {
      await TokenStorage.instance.clear();
      
      // Opcional: Notificar al backend (si tienes endpoint de logout)
      // await _dio.post('/auth/logout');
    } catch (e) {
      throw 'Error al cerrar sesión: $e';
    }
  }

  /// Verifica si el usuario está autenticado
  /// 
  /// Comprueba si hay un access token válido
  Future<bool> isAuthenticated() async {
    try {
      final token = await TokenStorage.instance.readAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==================== CURRENT USER ====================

  /// Obtiene la información del usuario actual
  /// 
  /// GET /auth/me
  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Si el token es inválido, limpiar storage
      if (e.response?.statusCode == 401) {
        await TokenStorage.instance.clear();
      }
      throw _handleError(e, 'Error al obtener usuario actual');
    }
  }

  /// Actualiza la información del usuario actual
  /// 
  /// PATCH /users/me (asumiendo que existe este endpoint)
  Future<User> updateCurrentUser({
    String? name,
    String? campus,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (campus != null) data['campus'] = campus;
      
      final response = await _dio.patch('/users/me', data: data);
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al actualizar usuario');
    }
  }

  // ==================== USER OPERATIONS ====================

  /// Obtiene un usuario por ID
  /// 
  /// GET /users/{id}
  Future<User> getUserById(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Error al obtener usuario');
    }
  }

  /// Obtiene un usuario por email
  /// 
  /// Basado en el método get_by_email del UserRepository
  Future<User?> getUserByEmail(String email) async {
    try {
      final response = await _dio.get(
        '/users/by-email',
        queryParameters: {'email': email},
      );
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _handleError(e, 'Error al buscar usuario');
    }
  }

  // ==================== CONTACTS MATCHING ====================

  /// Encuentra contactos registrados usando hashes SHA-256 de emails
  /// 
  /// POST /contacts/match
  /// 
  /// Este endpoint permite hacer match de contactos sin exponer emails directamente.
  /// El cliente hashea los emails de su libreta de contactos y el backend
  /// los compara con los usuarios registrados.
  /// 
  /// Uso:
  /// ```dart
  /// // Hashear emails de contactos
  /// final hashes = contacts.map((c) => sha256Hash(c.email.toLowerCase())).toList();
  /// 
  /// // Buscar matches
  /// final matches = await repo.matchContacts(emailHashes: hashes);
  /// ```
  Future<List<ContactMatch>> matchContacts({
    required List<String> emailHashes,
  }) async {
    try {
      final request = ContactsMatchRequest(emailHashes: emailHashes);
      
      final response = await _dio.post(
        '/contacts/match',
        data: request.toJson(),
      );
      
      final data = response.data;
      final List items;
      
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        items = [];
      }
      
      return items
          .map((json) => ContactMatch.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Error al buscar contactos');
    }
  }

  /// Helper para generar hash SHA-256 de un email
  /// 
  /// El backend usa: sha256(email.strip().lower())
  String hashEmail(String email) {
    return _sha256Hash(email.trim().toLowerCase());
  }

  /// Encuentra contactos desde una lista de emails (sin pre-hashear)
  /// 
  /// Convenience method que hashea los emails automáticamente
  Future<List<ContactMatch>> matchContactsByEmails({
    required List<String> emails,
  }) async {
    final hashes = emails.map((e) => hashEmail(e)).toList();
    return matchContacts(emailHashes: hashes);
  }

  // ==================== TOKEN MANAGEMENT ====================

  /// Obtiene el access token actual del storage
  Future<String?> getAccessToken() async {
    return TokenStorage.instance.readAccessToken();
  }

  /// Obtiene el refresh token actual del storage
  Future<String?> getRefreshToken() async {
    return TokenStorage.instance.readRefreshToken();
  }

  /// Verifica si el access token ha expirado
  /// 
  /// Decodifica el JWT y verifica la fecha de expiración
  Future<bool> isAccessTokenExpired() async {
    try {
      final token = await TokenStorage.instance.readAccessToken();
      if (token == null) return true;
      
      // Decodificar JWT (sin verificar firma)
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      final payload = _decodeBase64(parts[1]);
      final json = _parseJson(payload);
      
      final exp = json['exp'] as int?;
      if (exp == null) return true;
      
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      return true;
    }
  }

  // ==================== HELPERS ====================

  /// Maneja errores de Dio y retorna un mensaje apropiado
  String _handleError(DioException e, String defaultMessage) {
    if (e.response != null) {
      final data = e.response!.data;
      
      // Intenta extraer mensaje de error del backend
      if (data is Map) {
        if (data['detail'] is String) {
          return data['detail'] as String;
        }
        if (data['detail'] is List) {
          // Errores de validación de Pydantic
          try {
            final errors = (data['detail'] as List)
                .map((e) => e is Map && e['msg'] != null ? e['msg'].toString() : e.toString())
                .toList();
            if (errors.isNotEmpty) {
              return 'Datos inválidos:\n${errors.join('\n')}';
            }
          } catch (_) {}
        }
        if (data['message'] is String) {
          return data['message'] as String;
        }
      }
      
      return '$defaultMessage (${e.response!.statusCode})';
    }
    
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tiempo de espera agotado';
    }
    
    if (e.type == DioExceptionType.connectionError) {
      return 'Error de conexión';
    }
    
    return '$defaultMessage: ${e.message}';
  }

  /// Calcula hash SHA-256 de un string
  String _sha256Hash(String input) {
    // Nota: Necesitas importar 'package:crypto/crypto.dart'
    // y agregar crypto en pubspec.yaml
    try {
      // Importar al inicio del archivo: import 'package:crypto/crypto.dart';
      // import 'dart:convert';
      final bytes = input.codeUnits;
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      throw 'Error al calcular hash: $e';
    }
  }

  /// Decodifica Base64 URL-safe
  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw 'Invalid base64 string';
    }
    
    try {
      final bytes = base64Decode(output);
      return utf8.decode(bytes);
    } catch (e) {
      throw 'Error decodificando base64: $e';
    }
  }

  /// Parsea JSON string a Map
  Map<String, dynamic> _parseJson(String str) {
    try {
      final decoded = json.decode(str);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (e) {
      return {};
    }
  }
}

