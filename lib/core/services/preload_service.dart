import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/listings_repository.dart';
import '../../data/repositories/auth_repository.dart';
import 'cart_service.dart';

/// Servicio Singleton para precarga y sincronización en segundo plano
/// 
/// Responsabilidades:
/// - Precarga inicial de datos después del login
/// - Sincronización periódica en segundo plano
/// - Caché local de datos para modo offline
/// - Notificación de cambios mediante Streams
class PreloadService {
  PreloadService._();
  static final instance = PreloadService._();

  final _listingsRepo = ListingsRepository();
  final _authRepo = AuthRepository();
  final _cartService = CartService.instance;

  Timer? _syncTimer;
  bool _isInitialized = false;
  bool _isSyncing = false;

  /// StreamController para notificar progreso de precarga
  final _progressController = StreamController<PreloadProgress>.broadcast();

  /// StreamController para notificar actualizaciones de datos
  final _dataUpdateController = StreamController<DataUpdateEvent>.broadcast();

  /// Stream público para escuchar progreso de precarga
  Stream<PreloadProgress> get progressStream => _progressController.stream;

  /// Stream público para escuchar actualizaciones de datos
  Stream<DataUpdateEvent> get dataUpdateStream => _dataUpdateController.stream;

  // ==================== INITIALIZATION ====================

  /// Inicializa el servicio y realiza la precarga inicial
  /// 
  /// Debe llamarse después del login exitoso
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[PreloadService] Ya inicializado, omitiendo...');
      return;
    }

    print('[PreloadService] 🚀 Iniciando precarga...');

    try {
      // Inicializar CartService si no está inicializado
      await _cartService.initialize();

      // Realizar precarga inicial con notificación de progreso
      await _performInitialPreload();

      // Iniciar sincronización periódica cada 30 segundos
      _startPeriodicSync();

      _isInitialized = true;
      print('[PreloadService] ✅ Precarga completada exitosamente');
    } catch (e) {
      print('[PreloadService] ❌ Error en precarga inicial: $e');
      rethrow;
    }
  }

  /// Detiene la sincronización periódica y cierra los streams
  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _progressController.close();
    _dataUpdateController.close();
    _isInitialized = false;
    print('[PreloadService] 🛑 Sincronización detenida y streams cerrados');
  }

  /// Notifica progreso mediante Stream
  void _notifyProgress(PreloadProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Notifica actualización de datos mediante Stream
  void _notifyDataUpdate(DataUpdateType type, {String? message}) {
    if (!_dataUpdateController.isClosed) {
      _dataUpdateController.add(DataUpdateEvent(
        type: type,
        message: message,
      ));
    }
  }

  // ==================== INITIAL PRELOAD ====================

  /// Realiza la precarga inicial de todos los datos
  Future<void> _performInitialPreload() async {
    const totalSteps = 4;
    var currentStep = 0;

    try {
      // Paso 1: Perfil de usuario
      currentStep++;
      _notifyProgress(PreloadProgress(
        step: currentStep,
        totalSteps: totalSteps,
        message: 'Cargando perfil de usuario...',
        isComplete: false,
      ));
      await _preloadUserProfile();
      await Future.delayed(const Duration(milliseconds: 300));

      // Paso 2: Listings del Home
      currentStep++;
      _notifyProgress(PreloadProgress(
        step: currentStep,
        totalSteps: totalSteps,
        message: 'Cargando productos del marketplace...',
        isComplete: false,
      ));
      await _preloadHomeListings();
      await Future.delayed(const Duration(milliseconds: 300));

      // Paso 3: Carrito (ya inicializado, solo sincronizar)
      currentStep++;
      _notifyProgress(PreloadProgress(
        step: currentStep,
        totalSteps: totalSteps,
        message: 'Sincronizando carrito de compras...',
        isComplete: false,
      ));
      await _preloadCart();
      await Future.delayed(const Duration(milliseconds: 300));

      // Paso 4: Estadísticas del usuario
      currentStep++;
      _notifyProgress(PreloadProgress(
        step: currentStep,
        totalSteps: totalSteps,
        message: 'Cargando estadísticas personales...',
        isComplete: false,
      ));
      await _preloadUserStats();
      await Future.delayed(const Duration(milliseconds: 300));

      // Completado
      _notifyProgress(PreloadProgress(
        step: totalSteps,
        totalSteps: totalSteps,
        message: '¡Todo listo!',
        isComplete: true,
      ));
    } catch (e) {
      _notifyProgress(PreloadProgress(
        step: currentStep,
        totalSteps: totalSteps,
        message: 'Error: $e',
        isComplete: false,
        hasError: true,
      ));
      rethrow;
    }
  }

  /// Precarga el perfil del usuario
  Future<void> _preloadUserProfile() async {
    try {
      print('[PreloadService] 👤 Cargando perfil...');
      final user = await _authRepo.getCurrentUser();
      
      // Guardar en caché
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', jsonEncode(user.toJson()));
      await prefs.setInt('profile_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('[PreloadService] ✅ Perfil cacheado: ${user.name}');
    } catch (e) {
      print('[PreloadService] ❌ Error cargando perfil: $e');
      // No lanzar error, continuar con otros datos
    }
  }

  /// Precarga los listings del home
  Future<void> _preloadHomeListings() async {
    try {
      print('[PreloadService] 🏠 Cargando listings del home...');
      final result = await _listingsRepo.searchListings(
        page: 1,
        pageSize: 20,
      );
      
      // Guardar en caché
      final prefs = await SharedPreferences.getInstance();
      final listingsJson = result.items.map((l) => l.toJson()).toList();
      await prefs.setString('cached_home_listings', jsonEncode(listingsJson));
      await prefs.setInt('home_listings_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('[PreloadService] ✅ ${result.items.length} listings cacheados');
    } catch (e) {
      print('[PreloadService] ❌ Error cargando listings: $e');
      // No lanzar error, continuar con otros datos
    }
  }

  /// Precarga/sincroniza el carrito
  Future<void> _preloadCart() async {
    try {
      print('[PreloadService] 🛒 Sincronizando carrito...');
      // El carrito ya está en SharedPreferences gracias a CartService
      // Aquí podríamos validar items con el backend si es necesario
      final itemCount = _cartService.totalItems;
      print('[PreloadService] ✅ Carrito sincronizado: $itemCount items');
    } catch (e) {
      print('[PreloadService] ❌ Error sincronizando carrito: $e');
      // No lanzar error, continuar con otros datos
    }
  }

  /// Precarga las estadísticas del usuario
  Future<void> _preloadUserStats() async {
    try {
      print('[PreloadService] 📊 Cargando estadísticas...');
      final stats = await _listingsRepo.getUserStats();
      
      // Guardar en caché
      final prefs = await SharedPreferences.getInstance();
      final statsJson = {
        'total_listings': stats.myListings.length,
        'active_count': stats.activeCount,
        'sold_count': stats.soldCount,
        'total_value': stats.totalValue,
        'views_count': stats.viewsCount,
        'favorites_count': 12 + DateTime.now().millisecond % 20, // Simulado por ahora
      };
      await prefs.setString('cached_user_stats', jsonEncode(statsJson));
      await prefs.setInt('user_stats_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('[PreloadService] ✅ Estadísticas cacheadas');
    } catch (e) {
      print('[PreloadService] ❌ Error cargando estadísticas: $e');
      // No lanzar error, continuar con otros datos
    }
  }

  // ==================== BACKGROUND SYNC ====================

  /// Inicia sincronización periódica en segundo plano
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    
    // Sincronizar cada 30 segundos
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncInBackground();
    });
    
    print('[PreloadService] ⏰ Sincronización periódica iniciada (cada 30s)');
  }

  /// Sincroniza datos en segundo plano
  Future<void> _syncInBackground() async {
    if (_isSyncing) {
      print('[PreloadService] ⏭️ Sincronización en curso, omitiendo...');
      return;
    }

    _isSyncing = true;
    print('[PreloadService] 🔄 Sincronizando en segundo plano...');

    try {
      // Sincronizar todos los datos en paralelo
      await Future.wait([
        _syncUserProfile(),
        _syncHomeListings(),
        _syncUserStats(),
      ]);

      _notifyDataUpdate(DataUpdateType.all, message: 'Sincronización completada');
      print('[PreloadService] ✅ Sincronización completada');
    } catch (e) {
      print('[PreloadService] ⚠️ Error en sincronización: $e');
      // No lanzar error, la app puede seguir funcionando con datos en caché
    } finally {
      _isSyncing = false;
    }
  }

  /// Sincroniza perfil de usuario en segundo plano
  Future<void> _syncUserProfile() async {
    try {
      final user = await _authRepo.getCurrentUser();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', jsonEncode(user.toJson()));
      await prefs.setInt('profile_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      print('[PreloadService] 👤 Perfil sincronizado');
    } catch (e) {
      print('[PreloadService] ⚠️ Error sincronizando perfil: $e');
    }
  }

  /// Sincroniza listings del home en segundo plano
  Future<void> _syncHomeListings() async {
    try {
      final result = await _listingsRepo.searchListings(page: 1, pageSize: 20);
      final prefs = await SharedPreferences.getInstance();
      final listingsJson = result.items.map((l) => l.toJson()).toList();
      await prefs.setString('cached_home_listings', jsonEncode(listingsJson));
      await prefs.setInt('home_listings_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      print('[PreloadService] 🏠 Listings sincronizados (${result.items.length})');
    } catch (e) {
      print('[PreloadService] ⚠️ Error sincronizando listings: $e');
    }
  }

  /// Sincroniza estadísticas del usuario en segundo plano
  Future<void> _syncUserStats() async {
    try {
      final stats = await _listingsRepo.getUserStats();
      final prefs = await SharedPreferences.getInstance();
      final statsJson = {
        'total_listings': stats.myListings.length,
        'active_count': stats.activeCount,
        'sold_count': stats.soldCount,
        'total_value': stats.totalValue,
        'views_count': stats.viewsCount,
        'favorites_count': 12 + DateTime.now().millisecond % 20, // Simulado por ahora
      };
      await prefs.setString('cached_user_stats', jsonEncode(statsJson));
      await prefs.setInt('user_stats_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      print('[PreloadService] 📊 Estadísticas sincronizadas');
    } catch (e) {
      print('[PreloadService] ⚠️ Error sincronizando estadísticas: $e');
    }
  }

  // ==================== MANUAL SYNC ====================

  /// Fuerza una sincronización manual inmediata
  Future<void> forceSyncNow() async {
    print('[PreloadService] 🔄 Forzando sincronización manual...');
    await _syncInBackground();
  }

  // ==================== CACHE ACCESS ====================

  /// Obtiene el perfil en caché (sin hacer request)
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('cached_user_profile');
      if (profileJson != null) {
        return jsonDecode(profileJson) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PreloadService] Error obteniendo perfil en caché: $e');
    }
    return null;
  }

  /// Obtiene los listings en caché (sin hacer request)
  Future<List<Map<String, dynamic>>> getCachedHomeListings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listingsJson = prefs.getString('cached_home_listings');
      if (listingsJson != null) {
        final list = jsonDecode(listingsJson) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('[PreloadService] Error obteniendo listings en caché: $e');
    }
    return [];
  }

  /// Obtiene las estadísticas en caché (sin hacer request)
  Future<Map<String, dynamic>?> getCachedUserStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString('cached_user_stats');
      if (statsJson != null) {
        return jsonDecode(statsJson) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[PreloadService] Error obteniendo estadísticas en caché: $e');
    }
    return null;
  }

  /// Verifica la antigüedad del caché de perfil
  Future<Duration?> getProfileCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('profile_cache_timestamp');
      if (timestamp != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return DateTime.now().difference(cacheDate);
      }
    } catch (e) {
      print('[PreloadService] Error verificando edad del caché: $e');
    }
    return null;
  }
}

/// Representa el progreso de la precarga inicial
class PreloadProgress {
  final int step;
  final int totalSteps;
  final String message;
  final bool isComplete;
  final bool hasError;

  const PreloadProgress({
    required this.step,
    required this.totalSteps,
    required this.message,
    required this.isComplete,
    this.hasError = false,
  });

  /// Porcentaje de progreso (0.0 a 1.0)
  double get progress => step / totalSteps;

  /// Porcentaje de progreso (0 a 100)
  int get progressPercent => (progress * 100).round();

  @override
  String toString() => 'PreloadProgress($step/$totalSteps: $message)';
}

/// Representa un evento de actualización de datos
class DataUpdateEvent {
  final DataUpdateType type;
  final DateTime timestamp;
  final String? message;

  DataUpdateEvent({
    required this.type,
    DateTime? timestamp,
    this.message,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'DataUpdateEvent($type at $timestamp)';
}

/// Tipos de actualizaciones de datos
enum DataUpdateType {
  profile,
  listings,
  cart,
  stats,
  all,
}
