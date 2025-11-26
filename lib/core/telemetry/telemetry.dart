// lib/core/telemetry/telemetry.dart
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../data/repositories/telemetry_repository.dart';
import '../storage/telemetry_storage_service.dart';

/// Singleton for centralized telemetry tracking.
///
/// This is a convenience wrapper around TelemetryRepository with:
/// - Automatic batching (20 events or 2 seconds)
/// - Simplified API for common events
/// - Best-effort delivery with retry on failure
/// - **Local storage con Hive:** Guarda eventos localmente con userId
/// - **Envío inteligente:** Envía al backend cuando hay conexión
///
/// Usage:
/// ```dart
/// await Telemetry.i.initialize(userId: 'user123');
/// Telemetry.i.view('home_screen');
/// Telemetry.i.click('buy_button', listingId: '123');
/// await Telemetry.i.flush(); // Force send on logout
/// ```
class Telemetry {
  Telemetry._();
  static final Telemetry i = Telemetry._();

  final _repo = TelemetryRepository();
  final _storage = TelemetryStorageService();
  final _uuid = const Uuid();
  
  String? _userId;
  String? _sessionId;
  Timer? _timer;
  bool _initialized = false;

  static const int _maxBatch = 20;
  static const Duration _syncInterval = Duration(minutes: 2);

  /// Inicializa el servicio de telemetría con el userId y sessionId
  Future<void> initialize({String? userId}) async {
    if (_initialized) return;
    
    try {
      await _storage.initialize();
      _userId = userId;
      _sessionId = _uuid.v4();
      _initialized = true;
      
      print('[Telemetry] ✅ Inicializado - userId: $_userId, sessionId: $_sessionId');
      
      // Intentar enviar eventos pendientes
      _syncPendingEvents();
      
      // Programar sincronización periódica
      _scheduleSyncTimer();
    } catch (e) {
      print('[Telemetry] ❌ Error al inicializar: $e');
    }
  }

  /// Actualiza el userId (útil después de login/logout)
  Future<void> setUserId(String? userId) async {
    _userId = userId;
    print('[Telemetry] 👤 UserId actualizado: $_userId');
    
    // Nueva sesión al cambiar usuario
    _sessionId = _uuid.v4();
  }

  /// Guarda un evento localmente en Hive
  Future<void> _saveEventToStorage(Map<String, dynamic> eventData) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      await _storage.saveEvent(
        eventType: eventData['event_type'] as String,
        sessionId: _sessionId ?? _uuid.v4(),
        userId: _userId,
        listingId: eventData['listing_id'] as String?,
        orderId: eventData['order_id'] as String?,
        chatId: eventData['chat_id'] as String?,
        step: eventData['step'] as String?,
        properties: (eventData['properties'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      
      // Si hay suficientes eventos, intentar enviar
      final count = await _storage.getEventsCount();
      if (count >= _maxBatch) {
        _syncPendingEvents();
      }
    } catch (e) {
      print('[Telemetry] ⚠️ Error al guardar evento localmente: $e');
    }
  }

  /// Sincroniza eventos pendientes con el backend
  Future<void> _syncPendingEvents() async {
    try {
      final pendingEvents = await _storage.getPendingEvents();
      
      if (pendingEvents.isEmpty) {
        return;
      }
      
      print('[Telemetry] 📤 Enviando ${pendingEvents.length} eventos pendientes...');
      
      // Enviar eventos en lotes
      const batchSize = 50;
      for (var i = 0; i < pendingEvents.length; i += batchSize) {
        final end = (i + batchSize < pendingEvents.length) ? i + batchSize : pendingEvents.length;
        final batch = pendingEvents.sublist(i, end);
        
        try {
          // Extraer solo los eventos (sin las keys)
          final events = batch.map((e) => e.value).toList();
          await _repo.ingestEvents(events);
          
          // Si el envío fue exitoso, eliminar eventos del storage
          final keysToDelete = batch.map((e) => e.key).toList();
          await _storage.deleteEvents(keysToDelete);
          
          print('[Telemetry] ✅ Lote de ${batch.length} eventos enviado exitosamente');
        } catch (e) {
          print('[Telemetry] ⚠️ Error al enviar lote: $e');
          // No eliminar los eventos si falló el envío
          break; // Detener si falla un lote
        }
      }
    } catch (e) {
      print('[Telemetry] ❌ Error en sincronización: $e');
    }
  }

  /// Programa timer para sincronización periódica
  void _scheduleSyncTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) {
      _syncPendingEvents();
    });
  }

  /// Forzar envío inmediato (por ejemplo, al cerrar sesión).
  Future<void> flush() async {
    await _syncPendingEvents();
  }

  /// Limpia la cache de eventos (útil en logout)
  Future<void> clearCache() async {
    await _storage.clearAll();
    print('[Telemetry] 🗑️ Cache limpiada');
  }

  /// Obtiene estadísticas de almacenamiento
  Future<TelemetryStorageStats> getStats() async {
    return _storage.getStats();
  }

  // ----------------- Eventos públicos -----------------

  /// Vista de pantalla
  void view(String screen, {Map<String, dynamic>? props}) {
    _saveEventToStorage({
      'event_type': 'screen.view',
      'properties': {
        'screen': screen,
        if (props != null) ...props,
      },
    });
  }

  /// Click genérico de UI
  void click(
    String button, {
    String? listingId,
    String? orderId,
    String? chatId,
    Map<String, dynamic>? props,
  }) {
    _saveEventToStorage({
      'event_type': 'ui.click',
      if (listingId != null) 'listing_id': listingId,
      if (orderId != null) 'order_id': orderId,
      if (chatId != null) 'chat_id': chatId,
      'properties': {
        'button': button,
        if (props != null) ...props,
      },
    });
  }

  /// Búsqueda ejecutada (para BQ 2.1)
  void searchPerformed({String? q, String? categoryId, int? results}) {
    _saveEventToStorage({
      'event_type': 'search.performed',
      'properties': {
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoryId != null) 'category_id': categoryId,
        if (results != null) 'results': results,
      },
    });
  }

  /// Filtro realmente aplicado (para BQ 2.2)
  /// filter: 'category' | 'brand' | 'price' | 'availability' | ...
  /// value: valor textual (p.ej. 'laptops' o '0-500k')
  void filterUsed({required String filter, String? value}) {
    _saveEventToStorage({
      'event_type': 'search.filter.used',
      'properties': {
        'filter': filter,
        if (value != null) 'value': value,
      },
    });
  }

  /// Paso de checkout (por si haces el funnel detallado)
  void checkoutStep(String step, {Map<String, dynamic>? props}) {
    _saveEventToStorage({
      'event_type': 'checkout.step',
      'step': step,
      'properties': props ?? const {},
    });
  }

  /// [BQ1] Tracking de clics en categorías para análisis de popularidad
  /// Permite responder: "¿Qué categorías son más populares entre los usuarios?"
  void categoryClicked({
    required String categoryId,
    required String categoryName,
    String? source, // 'home_chips', 'search', 'filter', etc.
  }) {
    _saveEventToStorage({
      'event_type': 'category.clicked',
      'category_id': categoryId,
      'properties': {
        'category_name': categoryName,
        if (source != null) 'source': source,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  /// [BQ1] Tracking de tiempo de navegación en una categoría
  /// Permite medir engagement con categorías específicas
  void categoryViewed({
    required String categoryId,
    required String categoryName,
    required int durationSeconds,
    int? itemsViewed,
  }) {
    _saveEventToStorage({
      'event_type': 'category.viewed',
      'category_id': categoryId,
      'properties': {
        'category_name': categoryName,
        'duration_seconds': durationSeconds,
        if (itemsViewed != null) 'items_viewed': itemsViewed,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }
  
  // ==================== Form Abandonment Tracking ====================
  
  /// Tracking de inicio del formulario de creación de listing
  void formStarted() {
    _saveEventToStorage({
      'event_type': 'listing.form.started',
      'properties': {
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }
  
  /// Tracking de abandono del formulario de creación de listing
  void formAbandoned({
    required String formState,
    required bool hasTitle,
    required bool hasPrice,
    required bool hasImage,
    required bool hasCategory,
    required bool hasBrand,
    int? timeSpentSeconds,
  }) {
    _saveEventToStorage({
      'event_type': 'listing.form.abandoned',
      'properties': {
        'form_state': formState,
        'has_title': hasTitle,
        'has_price': hasPrice,
        'has_image': hasImage,
        'has_category': hasCategory,
        'has_brand': hasBrand,
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }
  
  /// Tracking de completado del formulario de creación de listing
  void formCompleted({
    required bool hadDraft,
    int? timeSpentSeconds,
  }) {
    _saveEventToStorage({
      'event_type': 'listing.form.completed',
      'properties': {
        'had_draft': hadDraft,
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }
}
