// ============================================================================
// SP4 KV: HIVE SERVICE - BASE DE DATOS LLAVE/VALOR LOCAL
// ============================================================================
// Este archivo implementa el almacenamiento Llave/Valor usando Hive.
// Hive es una BD NoSQL ligera y rapida para Flutter que almacena datos en pares
// clave-valor, ideal para:
// - Configuraciones de usuario
// - Preferencias de la aplicacion
// - Cache de datos frecuentes
// - Feature flags locales
// - Sesion del usuario
//
// VENTAJAS DE HIVE:
// - Ultra rapido (escrito en Dart puro)
// - Sin dependencias nativas
// - Type-safe con TypeAdapters
// - Encriptacion opcional
// - Soporta tipos primitivos y objetos complejos
//
// BOXES IMPLEMENTADOS:
// 1. user_prefs_box - Preferencias del usuario
// 2. app_config_box - Configuracion de la app
// 3. cache_box - Cache temporal de datos
// 4. feature_flags_box - Feature flags del Backend
// 5. session_box - Datos de sesion activa
//
// MARCADORES: Todos los metodos tienen comentarios "SP4 KV:" para visibilidad
// ============================================================================

import 'package:hive_flutter/hive_flutter.dart';

// ============================================================================
// SP4 KV: CLASE PRINCIPAL - SERVICIO DE HIVE
// ============================================================================
class HiveService {
  // SP4 KV: Nombres de los boxes (contenedores de datos)
  static const String userPrefsBox = 'user_preferences';
  static const String appConfigBox = 'app_config';
  static const String cacheBox = 'data_cache';
  static const String featureFlagsBox = 'feature_flags';
  static const String sessionBox = 'user_session';

  // SP4 KV: Singleton pattern
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  bool _initialized = false;

  // ============================================================================
  // SP4 KV: INICIALIZACION
  // ============================================================================
  
  // SP4 KV: Inicializar Hive y abrir todos los boxes
  Future<void> initialize() async {
    if (_initialized) {
      print('SP4 KV: Hive ya esta inicializado');
      return;
    }

    print('SP4 KV: Inicializando Hive...');
    
    try {
      // SP4 KV: Inicializa Hive con Flutter
      await Hive.initFlutter();
      print('SP4 KV: Hive inicializado exitosamente');

      // SP4 KV: Abre todos los boxes necesarios
      print('SP4 KV: Abriendo boxes...');
      
      await Hive.openBox(userPrefsBox);
      print('SP4 KV: Box $userPrefsBox abierto');
      
      await Hive.openBox(appConfigBox);
      print('SP4 KV: Box $appConfigBox abierto');
      
      await Hive.openBox(cacheBox);
      print('SP4 KV: Box $cacheBox abierto');
      
      await Hive.openBox(featureFlagsBox);
      print('SP4 KV: Box $featureFlagsBox abierto');
      
      await Hive.openBox(sessionBox);
      print('SP4 KV: Box $sessionBox abierto');

      _initialized = true;
      print('SP4 KV: Todos los boxes abiertos exitosamente');
      
    } catch (e) {
      print('SP4 KV: Error al inicializar Hive: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SP4 KV: USER PREFERENCES - PREFERENCIAS DEL USUARIO
  // ============================================================================

  // SP4 KV: Guardar preferencia de usuario
  Future<void> setUserPreference(String key, dynamic value) async {
    print('SP4 KV: Guardando preferencia de usuario: $key = $value');
    
    final box = Hive.box(userPrefsBox);
    await box.put(key, value);
    
    print('SP4 KV: Preferencia guardada exitosamente');
  }

  // SP4 KV: Obtener preferencia de usuario
  T? getUserPreference<T>(String key, {T? defaultValue}) {
    print('SP4 KV: Obteniendo preferencia: $key');
    
    final box = Hive.box(userPrefsBox);
    final value = box.get(key, defaultValue: defaultValue) as T?;
    
    print('SP4 KV: Preferencia obtenida: $value');
    return value;
  }

  // SP4 KV: Guardar tema de la app (dark/light)
  Future<void> setThemeMode(String theme) async {
    print('SP4 KV: Configurando tema: $theme');
    await setUserPreference('theme_mode', theme);
  }

  // SP4 KV: Obtener tema de la app
  String getThemeMode() {
    return getUserPreference<String>('theme_mode', defaultValue: 'system') ?? 'system';
  }

  // SP4 KV: Guardar idioma preferido
  Future<void> setLanguage(String languageCode) async {
    print('SP4 KV: Configurando idioma: $languageCode');
    await setUserPreference('language', languageCode);
  }

  // SP4 KV: Obtener idioma preferido
  String getLanguage() {
    return getUserPreference<String>('language', defaultValue: 'es') ?? 'es';
  }

  // SP4 KV: Guardar preferencia de notificaciones
  Future<void> setNotificationsEnabled(bool enabled) async {
    print('SP4 KV: Configurando notificaciones: $enabled');
    await setUserPreference('notifications_enabled', enabled);
  }

  // SP4 KV: Obtener preferencia de notificaciones
  bool getNotificationsEnabled() {
    return getUserPreference<bool>('notifications_enabled', defaultValue: true) ?? true;
  }

  // SP4 KV: Guardar campus preferido del usuario
  Future<void> setPreferredCampus(String campus) async {
    print('SP4 KV: Configurando campus preferido: $campus');
    await setUserPreference('preferred_campus', campus);
  }

  // SP4 KV: Obtener campus preferido
  String? getPreferredCampus() {
    return getUserPreference<String>('preferred_campus');
  }

  // SP4 KV: Obtener todas las preferencias de usuario
  Map<String, dynamic> getAllUserPreferences() {
    print('SP4 KV: Obteniendo todas las preferencias de usuario...');
    
    final box = Hive.box(userPrefsBox);
    final prefs = Map<String, dynamic>.from(box.toMap());
    
    print('SP4 KV: ${prefs.length} preferencias encontradas');
    return prefs;
  }

  // ============================================================================
  // SP4 KV: APP CONFIG - CONFIGURACION DE LA APLICACION
  // ============================================================================

  // SP4 KV: Guardar configuracion de la app
  Future<void> setAppConfig(String key, dynamic value) async {
    print('SP4 KV: Guardando configuracion de app: $key = $value');
    
    final box = Hive.box(appConfigBox);
    await box.put(key, value);
    
    print('SP4 KV: Configuracion guardada');
  }

  // SP4 KV: Obtener configuracion de la app
  T? getAppConfig<T>(String key, {T? defaultValue}) {
    print('SP4 KV: Obteniendo configuracion: $key');
    
    final box = Hive.box(appConfigBox);
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  // SP4 KV: Guardar URL del Backend
  Future<void> setBackendUrl(String url) async {
    print('SP4 KV: Configurando Backend URL: $url');
    await setAppConfig('backend_url', url);
  }

  // SP4 KV: Obtener URL del Backend
  String getBackendUrl() {
    return getAppConfig<String>('backend_url', 
      defaultValue: 'http://3.19.208.242:8000/v1') ?? 'http://3.19.208.242:8000/v1';
  }

  // SP4 KV: Guardar version de la app
  Future<void> setAppVersion(String version) async {
    print('SP4 KV: Guardando version de app: $version');
    await setAppConfig('app_version', version);
  }

  // SP4 KV: Obtener version de la app
  String? getAppVersion() {
    return getAppConfig<String>('app_version');
  }

  // SP4 KV: Marcar primera vez que se abre la app
  Future<void> setFirstLaunch(bool isFirst) async {
    print('SP4 KV: Configurando primera vez: $isFirst');
    await setAppConfig('is_first_launch', isFirst);
  }

  // SP4 KV: Verificar si es primera vez
  bool isFirstLaunch() {
    return getAppConfig<bool>('is_first_launch', defaultValue: true) ?? true;
  }

  // ============================================================================
  // SP4 KV: CACHE - CACHE TEMPORAL DE DATOS
  // ============================================================================

  // SP4 KV: Guardar dato en cache con timestamp
  Future<void> cacheData(String key, dynamic value, {Duration? ttl}) async {
    print('SP4 KV: Guardando en cache: $key');
    
    final box = Hive.box(cacheBox);
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final cacheEntry = {
      'value': value,
      'timestamp': now,
      'ttl': ttl?.inMilliseconds,
    };
    
    await box.put(key, cacheEntry);
    print('SP4 KV: Dato cacheado exitosamente');
  }

  // SP4 KV: Obtener dato del cache (valida TTL)
  T? getCachedData<T>(String key) {
    print('SP4 KV: Obteniendo dato del cache: $key');
    
    final box = Hive.box(cacheBox);
    final entry = box.get(key);
    
    if (entry == null) {
      print('SP4 KV: No hay dato en cache para: $key');
      return null;
    }

    final cacheEntry = entry as Map;
    final timestamp = cacheEntry['timestamp'] as int;
    final ttl = cacheEntry['ttl'] as int?;
    
    // SP4 KV: Valida si el cache expiro
    if (ttl != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = now - timestamp;
      
      if (age > ttl) {
        print('SP4 KV: Cache expirado para: $key (edad: ${age}ms, TTL: ${ttl}ms)');
        box.delete(key);
        return null;
      }
    }
    
    print('SP4 KV: Dato obtenido del cache');
    return cacheEntry['value'] as T?;
  }

  // SP4 KV: Cachear listado de listings
  Future<void> cacheListings(List<Map<String, dynamic>> listings) async {
    print('SP4 KV: Cacheando ${listings.length} listings...');
    await cacheData('cached_listings', listings, ttl: const Duration(minutes: 15));
  }

  // SP4 KV: Obtener listings del cache
  List<Map<String, dynamic>>? getCachedListings() {
    final cached = getCachedData<List>('cached_listings');
    return cached?.cast<Map<String, dynamic>>();
  }

  // SP4 KV: Cachear datos del usuario actual
  Future<void> cacheCurrentUser(Map<String, dynamic> userData) async {
    print('SP4 KV: Cacheando datos del usuario: ${userData['id']}');
    await cacheData('current_user', userData, ttl: const Duration(hours: 1));
  }

  // SP4 KV: Obtener usuario del cache
  Map<String, dynamic>? getCachedCurrentUser() {
    return getCachedData<Map>('current_user')?.cast<String, dynamic>();
  }

  // SP4 KV: Limpiar todo el cache
  Future<void> clearCache() async {
    print('SP4 KV: Limpiando todo el cache...');
    
    final box = Hive.box(cacheBox);
    await box.clear();
    
    print('SP4 KV: Cache limpiado completamente');
  }

  // ============================================================================
  // SP4 KV: FEATURE FLAGS - FLAGS DE CARACTERISTICAS DEL BACKEND
  // ============================================================================

  // SP4 KV: Sincronizar feature flags desde Backend
  Future<void> syncFeatureFlags(Map<String, bool> flags) async {
    print('SP4 KV: Sincronizando ${flags.length} feature flags desde Backend...');
    
    final box = Hive.box(featureFlagsBox);
    
    for (final entry in flags.entries) {
      await box.put(entry.key, entry.value);
      print('SP4 KV: Feature flag guardado: ${entry.key} = ${entry.value}');
    }
    
    // SP4 KV: Guarda timestamp de ultima sincronizacion
    await box.put('_last_sync', DateTime.now().toIso8601String());
    
    print('SP4 KV: Feature flags sincronizados exitosamente');
  }

  // SP4 KV: Verificar si una feature esta habilitada
  bool isFeatureEnabled(String featureKey, {bool defaultValue = false}) {
    print('SP4 KV: Verificando feature flag: $featureKey');
    
    final box = Hive.box(featureFlagsBox);
    final enabled = box.get(featureKey, defaultValue: defaultValue) as bool;
    
    print('SP4 KV: Feature $featureKey = $enabled');
    return enabled;
  }

  // SP4 KV: Obtener todos los feature flags
  Map<String, bool> getAllFeatureFlags() {
    print('SP4 KV: Obteniendo todos los feature flags...');
    
    final box = Hive.box(featureFlagsBox);
    final flags = <String, bool>{};
    
    for (final key in box.keys) {
      if (key != '_last_sync') {
        flags[key as String] = box.get(key) as bool;
      }
    }
    
    print('SP4 KV: ${flags.length} feature flags encontrados');
    return flags;
  }

  // SP4 KV: Obtener timestamp de ultima sincronizacion de flags
  String? getFeatureFlagsLastSync() {
    final box = Hive.box(featureFlagsBox);
    return box.get('_last_sync') as String?;
  }

  // ============================================================================
  // SP4 KV: SESSION - DATOS DE SESION DEL USUARIO
  // ============================================================================

  // SP4 KV: Guardar token de autenticacion
  Future<void> setAuthToken(String token) async {
    print('SP4 KV: Guardando token de autenticacion...');
    
    final box = Hive.box(sessionBox);
    await box.put('auth_token', token);
    
    print('SP4 KV: Token guardado');
  }

  // SP4 KV: Obtener token de autenticacion
  String? getAuthToken() {
    print('SP4 KV: Obteniendo token de autenticacion...');
    
    final box = Hive.box(sessionBox);
    return box.get('auth_token') as String?;
  }

  // SP4 KV: Guardar ID del usuario actual
  Future<void> setCurrentUserId(String userId) async {
    print('SP4 KV: Guardando ID del usuario actual: $userId');
    
    final box = Hive.box(sessionBox);
    await box.put('current_user_id', userId);
  }

  // SP4 KV: Obtener ID del usuario actual
  String? getCurrentUserId() {
    final box = Hive.box(sessionBox);
    return box.get('current_user_id') as String?;
  }

  // SP4 KV: Guardar ultima fecha de login
  Future<void> setLastLoginDate() async {
    print('SP4 KV: Guardando fecha de ultimo login...');
    
    final box = Hive.box(sessionBox);
    await box.put('last_login_date', DateTime.now().toIso8601String());
    
    print('SP4 KV: Fecha de login guardada');
  }

  // SP4 KV: Obtener ultima fecha de login
  String? getLastLoginDate() {
    final box = Hive.box(sessionBox);
    return box.get('last_login_date') as String?;
  }

  // SP4 KV: Verificar si hay sesion activa
  bool hasActiveSession() {
    print('SP4 KV: Verificando sesion activa...');
    
    final token = getAuthToken();
    final userId = getCurrentUserId();
    
    final hasSession = token != null && userId != null;
    print('SP4 KV: Sesion activa: $hasSession');
    
    return hasSession;
  }

  // SP4 KV: Cerrar sesion (limpiar datos de sesion)
  Future<void> clearSession() async {
    print('SP4 KV: Cerrando sesion y limpiando datos...');
    
    final box = Hive.box(sessionBox);
    await box.clear();
    
    print('SP4 KV: Sesion cerrada exitosamente');
  }

  // ============================================================================
  // SP4 KV: ESTADISTICAS Y UTILIDADES
  // ============================================================================

  // SP4 KV: Obtener estadisticas de todos los boxes
  Map<String, dynamic> getStorageStats() {
    print('SP4 KV: Calculando estadisticas de almacenamiento...');
    
    final stats = {
      'user_preferences': Hive.box(userPrefsBox).length,
      'app_config': Hive.box(appConfigBox).length,
      'cache': Hive.box(cacheBox).length,
      'feature_flags': Hive.box(featureFlagsBox).length,
      'session': Hive.box(sessionBox).length,
      'total_keys': Hive.box(userPrefsBox).length +
                    Hive.box(appConfigBox).length +
                    Hive.box(cacheBox).length +
                    Hive.box(featureFlagsBox).length +
                    Hive.box(sessionBox).length,
    };
    
    print('SP4 KV: Estadisticas calculadas: ${stats['total_keys']} llaves totales');
    return stats;
  }

  // SP4 KV: Exportar todos los datos a JSON (para debug)
  Map<String, dynamic> exportAllData() {
    print('SP4 KV: Exportando todos los datos...');
    
    return {
      'user_preferences': Map<String, dynamic>.from(Hive.box(userPrefsBox).toMap()),
      'app_config': Map<String, dynamic>.from(Hive.box(appConfigBox).toMap()),
      'cache': Map<String, dynamic>.from(Hive.box(cacheBox).toMap()),
      'feature_flags': Map<String, dynamic>.from(Hive.box(featureFlagsBox).toMap()),
      'session': Map<String, dynamic>.from(Hive.box(sessionBox).toMap()),
    };
  }

  // ============================================================================
  // ✨✨✨ SP4 FAV: GESTIÓN DE FAVORITOS EN HIVE (PREFERENCES) ✨✨✨
  // ============================================================================
  // Almacena favoritos en Hive como equivalente a:
  // - iOS: UserDefaults / NSUserDefaults
  // - Android: SharedPreferences / DataStore
  // - Web: LocalStorage
  // Usa la box de userPrefs para persistencia O(1)
  // ============================================================================

  /// ✨ SP4 FAV: Obtener lista de favoritos (key-value storage)
  List<Map<String, dynamic>> getFavorites() {
    print('✨ SP4 FAV: Leyendo favoritos desde Hive userPrefs box...');
    
    try {
      final box = Hive.box(userPrefsBox);
      final favoritesData = box.get('favorites', defaultValue: <dynamic>[]);
      
      // Convertir a lista de mapas
      if (favoritesData is List) {
        final favorites = favoritesData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        
        print('✨ SP4 FAV: ${favorites.length} favoritos encontrados en Hive');
        return favorites;
      }
      
      print('✨ SP4 FAV: No hay favoritos guardados');
      return [];
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al leer favoritos: $e');
      return [];
    }
  }

  /// ✨ SP4 FAV: Agregar item a favoritos (Preferences storage)
  Future<void> addFavorite(Map<String, dynamic> favorite) async {
    print('✨ SP4 FAV: Agregando favorito a Hive: ${favorite['name']}');
    
    try {
      final box = Hive.box(userPrefsBox);
      final currentFavorites = getFavorites();
      
      // Verificar si ya existe
      final exists = currentFavorites.any((f) => f['id'] == favorite['id']);
      if (exists) {
        print('✨ SP4 FAV: ⚠️ Favorito ya existe, no se agrega duplicado');
        return;
      }
      
      // Agregar nuevo favorito
      currentFavorites.add(favorite);
      await box.put('favorites', currentFavorites);
      
      print('✨ SP4 FAV: ✅ Favorito guardado en Hive Preferences (total: ${currentFavorites.length})');
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al agregar favorito: $e');
      rethrow;
    }
  }

  /// ✨ SP4 FAV: Eliminar favorito por ID
  Future<void> removeFavorite(String itemId) async {
    print('✨ SP4 FAV: Eliminando favorito con ID: $itemId');
    
    try {
      final box = Hive.box(userPrefsBox);
      final currentFavorites = getFavorites();
      
      // Filtrar para quitar el item
      final updatedFavorites = currentFavorites.where((f) => f['id'] != itemId).toList();
      
      await box.put('favorites', updatedFavorites);
      
      print('✨ SP4 FAV: ✅ Favorito eliminado (quedan: ${updatedFavorites.length})');
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al eliminar favorito: $e');
      rethrow;
    }
  }

  /// ✨ SP4 FAV: Limpiar todos los favoritos
  Future<void> clearAllFavorites() async {
    print('✨ SP4 FAV: Limpiando todos los favoritos...');
    
    try {
      final box = Hive.box(userPrefsBox);
      await box.delete('favorites');
      
      print('✨ SP4 FAV: ✅ Todos los favoritos eliminados de Hive');
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al limpiar favoritos: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SP4 KV: UTILIDADES GENERALES
  // ============================================================================

  // SP4 KV: Limpiar todos los datos (reset completo)
  Future<void> clearAllData() async {
    print('SP4 KV: ATENCION - Limpiando TODOS los datos de Hive...');
    
    await Hive.box(userPrefsBox).clear();
    await Hive.box(appConfigBox).clear();
    await Hive.box(cacheBox).clear();
    await Hive.box(featureFlagsBox).clear();
    await Hive.box(sessionBox).clear();
    
    print('SP4 KV: Todos los datos han sido eliminados');
  }

  // SP4 KV: Cerrar todos los boxes
  Future<void> close() async {
    print('SP4 KV: Cerrando todos los boxes...');
    
    await Hive.close();
    _initialized = false;
    
    print('SP4 KV: Todos los boxes cerrados');
  }
}
