// lib/core/storage/telemetry_storage_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/event.dart';

/// Servicio de almacenamiento local para telemetría usando Hive
/// 
/// Almacena eventos de telemetría localmente asociados al userId
/// antes de enviarlos al backend. Permite:
/// - Almacenamiento offline de eventos
/// - Asociación automática con userId
/// - Recuperación de eventos pendientes de envío
/// - Limpieza de eventos ya enviados
class TelemetryStorageService {
  static final TelemetryStorageService _instance = TelemetryStorageService._internal();
  factory TelemetryStorageService() => _instance;
  TelemetryStorageService._internal();

  Box<Map>? _eventsBox;
  bool _initialized = false;

  /// Inicializa Hive y abre la box de eventos
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      print('[TelemetryStorage] 📦 Inicializando Hive...');
      
      // Inicializar Hive con la ruta de la app
      await Hive.initFlutter();
      
      // Abrir box para eventos de telemetría
      _eventsBox = await Hive.openBox<Map>('telemetry_events');
      
      _initialized = true;
      print('[TelemetryStorage] ✅ Hive inicializado, ${_eventsBox!.length} eventos en cache');
    } catch (e) {
      print('[TelemetryStorage] ❌ Error al inicializar Hive: $e');
      rethrow;
    }
  }

  /// Guarda un evento de telemetría localmente
  /// 
  /// Asocia automáticamente el userId y genera una clave única.
  /// Los eventos se almacenan como Maps para facilitar la serialización.
  Future<void> saveEvent({
    required String eventType,
    required String sessionId,
    String? userId,
    String? listingId,
    String? orderId,
    String? chatId,
    String? step,
    required Map<String, dynamic> properties,
  }) async {
    await _ensureInitialized();
    
    final eventData = {
      'event_type': eventType,
      'session_id': sessionId,
      'user_id': userId,
      'listing_id': listingId,
      'order_id': orderId,
      'chat_id': chatId,
      'step': step,
      'properties': properties,
      'occurred_at': DateTime.now().toIso8601String(),
      'stored_at': DateTime.now().toIso8601String(),
    };
    
    // Generar clave única: timestamp + tipo de evento
    final key = '${DateTime.now().millisecondsSinceEpoch}_$eventType';
    
    await _eventsBox!.put(key, eventData);
    
    print('[TelemetryStorage] 💾 Evento guardado: $eventType (userId: $userId, total: ${_eventsBox!.length})');
  }

  /// Obtiene todos los eventos pendientes de envío
  /// 
  /// Retorna una lista de tuplas (key, Event) para poder eliminarlos después
  Future<List<MapEntry<String, Event>>> getPendingEvents() async {
    await _ensureInitialized();
    
    final events = <MapEntry<String, Event>>[];
    
    for (final key in _eventsBox!.keys) {
      try {
        final data = _eventsBox!.get(key);
        if (data != null) {
          // Convertir Map a Map<String, dynamic> explícitamente
          final eventMap = Map<String, dynamic>.from(data as Map);
          
          // Crear un Event con un ID temporal (se reemplazará en el servidor)
          final event = Event(
            id: key.toString(),
            eventType: eventMap['event_type'] as String,
            sessionId: eventMap['session_id'] as String,
            userId: eventMap['user_id'] as String?,
            listingId: eventMap['listing_id'] as String?,
            orderId: eventMap['order_id'] as String?,
            chatId: eventMap['chat_id'] as String?,
            step: eventMap['step'] as String?,
            properties: Map<String, dynamic>.from(eventMap['properties'] as Map? ?? {}),
            occurredAt: DateTime.parse(eventMap['occurred_at'] as String),
          );
          
          events.add(MapEntry(key.toString(), event));
        }
      } catch (e) {
        print('[TelemetryStorage] ⚠️ Error al parsear evento $key: $e');
      }
    }
    
    print('[TelemetryStorage] 📤 ${events.length} eventos pendientes de envío');
    return events;
  }

  /// Obtiene eventos pendientes filtrados por userId
  Future<List<MapEntry<String, Event>>> getPendingEventsByUser(String userId) async {
    final allEvents = await getPendingEvents();
    
    final userEvents = allEvents.where((entry) => entry.value.userId == userId).toList();
    
    print('[TelemetryStorage] 👤 ${userEvents.length} eventos del usuario $userId');
    return userEvents;
  }

  /// Elimina eventos después de enviarlos exitosamente
  Future<void> deleteEvents(List<String> keys) async {
    await _ensureInitialized();
    
    for (final key in keys) {
      await _eventsBox!.delete(key);
    }
    
    print('[TelemetryStorage] 🗑️ ${keys.length} eventos eliminados después del envío');
  }

  /// Obtiene el conteo de eventos almacenados
  Future<int> getEventsCount() async {
    await _ensureInitialized();
    return _eventsBox!.length;
  }

  /// Obtiene el conteo de eventos por usuario
  Future<int> getEventsCountByUser(String userId) async {
    final userEvents = await getPendingEventsByUser(userId);
    return userEvents.length;
  }

  /// Limpia eventos antiguos (más de 7 días)
  /// 
  /// Útil para evitar acumulación infinita si hay problemas de red
  Future<int> cleanupOldEvents({int maxAgeDays = 7}) async {
    await _ensureInitialized();
    
    final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));
    final keysToDelete = <String>[];
    
    for (final key in _eventsBox!.keys) {
      try {
        final data = _eventsBox!.get(key);
        if (data != null) {
          final eventMap = Map<String, dynamic>.from(data as Map);
          final storedAt = DateTime.parse(eventMap['stored_at'] as String);
          
          if (storedAt.isBefore(cutoffDate)) {
            keysToDelete.add(key.toString());
          }
        }
      } catch (e) {
        print('[TelemetryStorage] ⚠️ Error al verificar antigüedad de evento $key: $e');
      }
    }
    
    for (final key in keysToDelete) {
      await _eventsBox!.delete(key);
    }
    
    print('[TelemetryStorage] 🧹 ${keysToDelete.length} eventos antiguos limpiados');
    return keysToDelete.length;
  }

  /// Limpia todos los eventos almacenados
  Future<void> clearAll() async {
    await _ensureInitialized();
    
    final count = _eventsBox!.length;
    await _eventsBox!.clear();
    
    print('[TelemetryStorage] 🗑️ Todos los eventos limpiados ($count eventos)');
  }

  /// Obtiene estadísticas de almacenamiento
  Future<TelemetryStorageStats> getStats() async {
    await _ensureInitialized();
    
    final events = await getPendingEvents();
    final userIds = events.map((e) => e.value.userId).whereType<String>().toSet();
    
    // Agrupar por tipo de evento
    final eventTypeCount = <String, int>{};
    for (final entry in events) {
      final type = entry.value.eventType;
      eventTypeCount[type] = (eventTypeCount[type] ?? 0) + 1;
    }
    
    // Encontrar evento más antiguo
    DateTime? oldestEvent;
    for (final entry in events) {
      if (oldestEvent == null || entry.value.occurredAt.isBefore(oldestEvent)) {
        oldestEvent = entry.value.occurredAt;
      }
    }
    
    return TelemetryStorageStats(
      totalEvents: events.length,
      uniqueUsers: userIds.length,
      eventTypeCount: eventTypeCount,
      oldestEvent: oldestEvent,
    );
  }

  /// Cierra la box de Hive
  Future<void> close() async {
    if (_eventsBox != null && _eventsBox!.isOpen) {
      await _eventsBox!.close();
      _initialized = false;
      print('[TelemetryStorage] 🔒 Hive cerrado');
    }
  }

  // ==================== HELPERS ====================

  /// Asegura que el servicio esté inicializado
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}

/// Estadísticas de almacenamiento de telemetría
class TelemetryStorageStats {
  final int totalEvents;
  final int uniqueUsers;
  final Map<String, int> eventTypeCount;
  final DateTime? oldestEvent;

  const TelemetryStorageStats({
    required this.totalEvents,
    required this.uniqueUsers,
    required this.eventTypeCount,
    this.oldestEvent,
  });

  @override
  String toString() {
    return 'TelemetryStats(total: $totalEvents, users: $uniqueUsers, oldest: $oldestEvent)';
  }
}
