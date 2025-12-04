// ============================================================================
// SP4 KV: HIVE REPOSITORY - INTEGRACION HIVE + BACKEND
// ============================================================================
// Este archivo implementa la capa de integracion entre Hive (BD Llave/Valor)
// y el Backend remoto. Combina:
// - Almacenamiento local rapido con Hive
// - Sincronizacion con Backend
// - Cache inteligente
// - Persistencia de preferencias
//
// CASOS DE USO:
// 1. Guardar configuraciones del usuario localmente
// 2. Sincronizar feature flags desde Backend
// 3. Cachear datos frecuentes para acceso offline
// 4. Persistir sesion de usuario
// 5. Almacenar preferencias de UI
//
// MARCADORES: "SP4 KV REPO:" para visibilidad en logs
// ============================================================================

import 'package:dio/dio.dart';
import '../services/hive_service.dart';

// ============================================================================
// SP4 KV REPO: CLASE PRINCIPAL - REPOSITORIO INTEGRADO
// ============================================================================
class HiveRepository {
  final Dio _dio;
  final HiveService _hiveService;

  // SP4 KV REPO: Constructor con dependencias
  HiveRepository({
    required String baseUrl,
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )),
        _hiveService = HiveService() {
    print('SP4 KV REPO: Repositorio Hive inicializado');
    print('SP4 KV REPO: Base URL: $baseUrl');
  }

  // ============================================================================
  // SP4 KV REPO: INICIALIZACION
  // ============================================================================

  // SP4 KV REPO: Inicializar Hive y cargar configuraciones
  Future<void> initialize() async {
    print('SP4 KV REPO: Inicializando repositorio...');
    
    await _hiveService.initialize();
    
    // SP4 KV REPO: Carga configuraciones iniciales
    final isFirstLaunch = _hiveService.isFirstLaunch();
    
    if (isFirstLaunch) {
      print('SP4 KV REPO: Primera vez - Configurando valores por defecto...');
      await _setupDefaultConfig();
      await _hiveService.setFirstLaunch(false);
    }
    
    print('SP4 KV REPO: Repositorio inicializado exitosamente');
  }

  // SP4 KV REPO: Configurar valores por defecto en primera ejecucion
  Future<void> _setupDefaultConfig() async {
    print('SP4 KV REPO: Configurando valores por defecto...');
    
    await _hiveService.setThemeMode('system');
    await _hiveService.setLanguage('es');
    await _hiveService.setNotificationsEnabled(true);
    await _hiveService.setBackendUrl('http://3.19.208.242:8000/v1');
    
    print('SP4 KV REPO: Valores por defecto configurados');
  }

  // ============================================================================
  // SP4 KV REPO: FEATURE FLAGS - SINCRONIZACION CON BACKEND
  // ============================================================================

  // SP4 KV REPO: Sincronizar feature flags desde Backend
  Future<Map<String, bool>> syncFeatureFlagsFromBackend() async {
    print('SP4 KV REPO: Sincronizando feature flags desde Backend...');
    
    try {
      // SP4 KV REPO: Obtiene flags del Backend
      final response = await _dio.get('/features');
      
      if (response.statusCode == 200) {
        print('SP4 KV REPO: Feature flags obtenidos del Backend');
        final flags = Map<String, bool>.from(response.data);
        
        // SP4 KV REPO: Guarda en Hive para acceso offline
        await _hiveService.syncFeatureFlags(flags);
        
        print('SP4 KV REPO: ${flags.length} feature flags sincronizados');
        return flags;
      }
    } catch (e) {
      print('SP4 KV REPO: Error al sincronizar feature flags: $e');
      print('SP4 KV REPO: Usando flags locales de Hive...');
    }
    
    // SP4 KV REPO: Si falla, usa los flags locales
    return _hiveService.getAllFeatureFlags();
  }

  // SP4 KV REPO: Verificar si una feature esta habilitada (con fallback)
  Future<bool> isFeatureEnabled(String featureKey, {bool defaultValue = false}) async {
    print('SP4 KV REPO: Verificando feature: $featureKey');
    
    // SP4 KV REPO: Primero verifica en Hive (rapido)
    final localValue = _hiveService.isFeatureEnabled(featureKey, defaultValue: defaultValue);
    
    // SP4 KV REPO: Intenta actualizar desde Backend en background
    try {
      await syncFeatureFlagsFromBackend();
    } catch (e) {
      print('SP4 KV REPO: No se pudo actualizar flags desde Backend');
    }
    
    return localValue;
  }

  // SP4 KV REPO: Registrar uso de una feature en Backend
  Future<void> registerFeatureUse(String featureKey) async {
    print('SP4 KV REPO: Registrando uso de feature: $featureKey');
    
    try {
      final response = await _dio.post('/features/use', data: {
        'feature_key': featureKey,
      });
      
      if (response.statusCode == 202) {
        print('SP4 KV REPO: Uso de feature registrado en Backend');
      }
    } catch (e) {
      print('SP4 KV REPO: Error al registrar uso de feature: $e');
    }
  }

  // ============================================================================
  // SP4 KV REPO: USER PREFERENCES - PREFERENCIAS DEL USUARIO
  // ============================================================================

  // SP4 KV REPO: Guardar todas las preferencias de usuario
  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    print('SP4 KV REPO: Guardando preferencias de usuario...');
    
    for (final entry in preferences.entries) {
      await _hiveService.setUserPreference(entry.key, entry.value);
    }
    
    print('SP4 KV REPO: ${preferences.length} preferencias guardadas');
  }

  // SP4 KV REPO: Obtener resumen de configuracion de usuario
  Map<String, dynamic> getUserSettings() {
    print('SP4 KV REPO: Obteniendo configuracion de usuario...');
    
    final settings = {
      'theme_mode': _hiveService.getThemeMode(),
      'language': _hiveService.getLanguage(),
      'notifications_enabled': _hiveService.getNotificationsEnabled(),
      'preferred_campus': _hiveService.getPreferredCampus(),
      'has_active_session': _hiveService.hasActiveSession(),
      'last_login': _hiveService.getLastLoginDate(),
    };
    
    print('SP4 KV REPO: Configuracion obtenida');
    return settings;
  }

  // SP4 KV REPO: Actualizar tema de la app
  Future<void> updateTheme(String theme) async {
    print('SP4 KV REPO: Actualizando tema a: $theme');
    
    await _hiveService.setThemeMode(theme);
    
    print('SP4 KV REPO: Tema actualizado exitosamente');
  }

  // SP4 KV REPO: Actualizar idioma
  Future<void> updateLanguage(String languageCode) async {
    print('SP4 KV REPO: Actualizando idioma a: $languageCode');
    
    await _hiveService.setLanguage(languageCode);
    
    print('SP4 KV REPO: Idioma actualizado exitosamente');
  }

  // SP4 KV REPO: Toggle notificaciones
  Future<void> toggleNotifications(bool enabled) async {
    print('SP4 KV REPO: Configurando notificaciones: $enabled');
    
    await _hiveService.setNotificationsEnabled(enabled);
    
    print('SP4 KV REPO: Notificaciones actualizadas');
  }

  // ============================================================================
  // SP4 KV REPO: CACHE - GESTION DE CACHE LOCAL
  // ============================================================================

  // SP4 KV REPO: Cachear datos de listings desde Backend
  Future<List<Map<String, dynamic>>> getListingsWithCache({
    bool forceRefresh = false,
  }) async {
    print('SP4 KV REPO: Obteniendo listings (forceRefresh: $forceRefresh)...');
    
    // SP4 KV REPO: Si no es refresh forzado, intenta usar cache
    if (!forceRefresh) {
      final cached = _hiveService.getCachedListings();
      if (cached != null && cached.isNotEmpty) {
        print('SP4 KV REPO: ${cached.length} listings obtenidos del cache Hive');
        return cached;
      }
    }
    
    print('SP4 KV REPO: Obteniendo listings desde Backend...');
    
    try {
      final response = await _dio.get('/listings', queryParameters: {
        'page': 1,
        'page_size': 20,
      });
      
      if (response.statusCode == 200) {
        final data = response.data;
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        
        // SP4 KV REPO: Cachea en Hive para proximas consultas
        await _hiveService.cacheListings(items);
        
        print('SP4 KV REPO: ${items.length} listings obtenidos y cacheados');
        return items;
      }
    } catch (e) {
      print('SP4 KV REPO: Error al obtener listings: $e');
      
      // SP4 KV REPO: Fallback al cache aunque este vacio
      final cached = _hiveService.getCachedListings();
      if (cached != null) {
        print('SP4 KV REPO: Usando cache como fallback');
        return cached;
      }
    }
    
    return [];
  }

  // SP4 KV REPO: Cachear datos del usuario actual
  Future<void> cacheUserData(Map<String, dynamic> userData) async {
    print('SP4 KV REPO: Cacheando datos del usuario: ${userData['id']}');
    
    await _hiveService.cacheCurrentUser(userData);
    
    print('SP4 KV REPO: Usuario cacheado en Hive');
  }

  // SP4 KV REPO: Obtener usuario del cache
  Map<String, dynamic>? getCachedUser() {
    print('SP4 KV REPO: Obteniendo usuario del cache Hive...');
    
    return _hiveService.getCachedCurrentUser();
  }
  
  // SP4 KV REPO: Cachear listings directamente (para HomePage)
  Future<void> cacheListings(List<Map<String, dynamic>> listings) async {
    print('SP4 KV REPO: Cacheando ${listings.length} listings en Hive...');
    
    await _hiveService.cacheListings(listings);
    
    print('SP4 KV REPO: Listings cacheados exitosamente');
  }
  
  // SP4 KV REPO: Obtener listings del cache (para HomePage)
  List<Map<String, dynamic>>? getCachedListings() {
    print('SP4 KV REPO: Obteniendo listings del cache Hive...');
    
    final cached = _hiveService.getCachedListings();
    
    if (cached != null && cached.isNotEmpty) {
      print('SP4 KV REPO: ${cached.length} listings encontrados en cache');
    } else {
      print('SP4 KV REPO: No hay listings en cache');
    }
    
    return cached;
  }

  // SP4 KV REPO: Limpiar cache (por ejemplo, al logout)
  Future<void> clearCache() async {
    print('SP4 KV REPO: Limpiando cache de Hive...');
    
    await _hiveService.clearCache();
    
    print('SP4 KV REPO: Cache limpiado');
  }

  // ============================================================================
  // SP4 KV REPO: SESSION - GESTION DE SESION
  // ============================================================================

  // SP4 KV REPO: Iniciar sesion (guardar token y datos)
  Future<void> startSession({
    required String token,
    required String userId,
    Map<String, dynamic>? userData,
  }) async {
    print('SP4 KV REPO: Iniciando sesion para usuario: $userId');
    
    await _hiveService.setAuthToken(token);
    await _hiveService.setCurrentUserId(userId);
    await _hiveService.setLastLoginDate();
    
    if (userData != null) {
      await _hiveService.cacheCurrentUser(userData);
    }
    
    print('SP4 KV REPO: Sesion iniciada y guardada en Hive');
  }

  // SP4 KV REPO: Verificar si hay sesion activa
  bool hasActiveSession() {
    return _hiveService.hasActiveSession();
  }

  // SP4 KV REPO: Obtener token de sesion
  String? getSessionToken() {
    return _hiveService.getAuthToken();
  }

  // SP4 KV REPO: Obtener ID del usuario actual
  Future<String?> getCurrentUserId() async {
    return _hiveService.getCurrentUserId();
  }

  // SP4 KV REPO: Cerrar sesion (limpiar datos)
  Future<void> endSession() async {
    print('SP4 KV REPO: Cerrando sesion...');
    
    await _hiveService.clearSession();
    await _hiveService.clearCache();
    
    print('SP4 KV REPO: Sesion cerrada y cache limpiado');
  }

  // ============================================================================
  // SP4 KV REPO: ESTADISTICAS Y DIAGNOSTICO
  // ============================================================================

  // SP4 KV REPO: Obtener estadisticas de Hive
  Map<String, dynamic> getStorageStatistics() {
    print('SP4 KV REPO: Obteniendo estadisticas de almacenamiento Hive...');
    
    final stats = _hiveService.getStorageStats();
    final lastFlagsSync = _hiveService.getFeatureFlagsLastSync();
    
    final result = {
      ...stats,
      'feature_flags_last_sync': lastFlagsSync,
      'backend_url': _hiveService.getBackendUrl(),
      'app_version': _hiveService.getAppVersion(),
    };
    
    print('SP4 KV REPO: Estadisticas calculadas');
    return result;
  }

  // SP4 KV REPO: Exportar todos los datos de Hive (debug)
  Map<String, dynamic> exportAllHiveData() {
    print('SP4 KV REPO: Exportando todos los datos de Hive...');
    
    return _hiveService.exportAllData();
  }

  // SP4 KV REPO: Reset completo (borrar todo)
  Future<void> resetAllData() async {
    print('SP4 KV REPO: RESET COMPLETO - Borrando todos los datos de Hive...');
    
    await _hiveService.clearAllData();
    await _setupDefaultConfig();
    
    print('SP4 KV REPO: Datos borrados y configuracion por defecto restaurada');
  }

  // ============================================================================
  // SP4 KV REPO: OPERACIONES COMBINADAS
  // ============================================================================

  // SP4 KV REPO: Sincronizacion completa (flags + cache + prefs)
  Future<Map<String, dynamic>> performFullSync() async {
    print('SP4 KV REPO: Iniciando sincronizacion completa...');
    
    final results = {
      'feature_flags_synced': false,
      'listings_cached': 0,
      'errors': <String>[],
    };
    
    try {
      // SP4 KV REPO: Sincroniza feature flags
      final flags = await syncFeatureFlagsFromBackend();
      results['feature_flags_synced'] = flags.isNotEmpty;
      
      // SP4 KV REPO: Actualiza cache de listings
      final listings = await getListingsWithCache(forceRefresh: true);
      results['listings_cached'] = listings.length;
      
      print('SP4 KV REPO: Sincronizacion completa finalizada');
      print('SP4 KV REPO: Flags=${results['feature_flags_synced']}, Listings=${results['listings_cached']}');
      
    } catch (e) {
      print('SP4 KV REPO: Error durante sincronizacion: $e');
      results['errors'] = [e.toString()];
    }
    
    return results;
  }

  // SP4 KV REPO: Configurar perfil de usuario completo
  Future<void> setupUserProfile({
    required String campus,
    required String theme,
    required String language,
    required bool notifications,
  }) async {
    print('SP4 KV REPO: Configurando perfil de usuario completo...');
    
    await _hiveService.setPreferredCampus(campus);
    await _hiveService.setThemeMode(theme);
    await _hiveService.setLanguage(language);
    await _hiveService.setNotificationsEnabled(notifications);
    
    print('SP4 KV REPO: Perfil de usuario configurado en Hive');
  }

  // ============================================================================
  // ✨✨✨ SP4 FAV: GESTIÓN DE FAVORITOS (PREFERENCES/USERDEFAULTS) ✨✨✨
  // ============================================================================
  // Equivalente a:
  // - iOS: UserDefaults / Keychain
  // - Android: SharedPreferences / DataStore
  // - Flutter: Hive key-value storage
  // ============================================================================

  /// SP4 FAV: Obtener lista de favoritos desde Hive (Preferences)
  List<Map<String, dynamic>> getFavorites() {
    print('✨ SP4 FAV: Obteniendo favoritos desde Hive (Preferences)...');
    
    try {
      final favorites = _hiveService.getFavorites();
      print('✨ SP4 FAV: ${favorites.length} favoritos obtenidos');
      return favorites;
    } catch (e) {
      print('✨ SP4 FAV: Error al obtener favoritos: $e');
      return [];
    }
  }

  /// SP4 FAV: Agregar item a favoritos en Hive (Preferences)
  Future<void> addFavorite(Map<String, dynamic> favorite) async {
    print('✨ SP4 FAV: Agregando favorito a Hive: ${favorite['name']}');
    
    try {
      await _hiveService.addFavorite(favorite);
      print('✨ SP4 FAV: ✅ Favorito guardado en Hive Preferences');
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al agregar favorito: $e');
      rethrow;
    }
  }

  /// SP4 FAV: Eliminar item de favoritos en Hive (Preferences)
  Future<void> removeFavorite(String itemId) async {
    print('✨ SP4 FAV: Eliminando favorito con ID: $itemId');
    
    try {
      await _hiveService.removeFavorite(itemId);
      print('✨ SP4 FAV: ✅ Favorito eliminado de Hive');
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al eliminar favorito: $e');
      rethrow;
    }
  }

  /// SP4 FAV: Limpiar todos los favoritos
  Future<void> clearAllFavorites() async {
    print('✨ SP4 FAV: Limpiando todos los favoritos...');
    
    try {
      await _hiveService.clearAllFavorites();
      print('✨ SP4 FAV: ✅ Todos los favoritos eliminados');
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al limpiar favoritos: $e');
      rethrow;
    }
  }
}
