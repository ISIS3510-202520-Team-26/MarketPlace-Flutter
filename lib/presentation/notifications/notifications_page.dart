// ============================================================================
// ✨✨✨ SP4 NUEVA VISTA 4/4: NOTIFICATIONS PAGE ✨✨✨
// ============================================================================
// Esta es la CUARTA y ÚLTIMA vista protegida creada para el Sprint 4
// 
// TECNOLOGÍAS IMPLEMENTADAS:
// ============================================================================
// 
// 📁 LOCAL FILES (File I/O):
// - Similar a FileManager (iOS) / File API (Android)
// - path_provider para obtener directorios del sistema
// - dart:io File para lectura/escritura
// - Almacena notificaciones en JSON en el disco local
// - Persiste datos entre reinicios de la app
// - NO usa base de datos, solo archivos planos
// 
// 🧠 LRU CACHE (Least Recently Used):
// - Equivalente a NSCache (iOS) / LRUCache (Android)
// - Implementación manual con LinkedHashMap
// - Eviction policy: Elimina el menos recientemente usado al llenar
// - O(1) para get/put gracias al HashMap
// - Mejora performance evitando lecturas repetidas de disco
// - Similar a SparseArray/ArrayMap (Android) en funcionamiento
// 
// ============================================================================
// COMPARACIÓN CON OTRAS TECNOLOGÍAS:
// ============================================================================
// 
// iOS EQUIVALENTES:
// - FileManager.default.urls() ≈ path_provider.getApplicationDocumentsDirectory()
// - NSCache ≈ LruCacheService (implementación manual)
// - FileHandle ≈ dart:io File
// - UserDefaults ≈ Hive (usado en Favorites, no aquí)
// 
// ANDROID EQUIVALENTES:
// - Context.getFilesDir() ≈ path_provider.getApplicationDocumentsDirectory()
// - LRUCache<K,V> ≈ LruCacheService (implementación manual)
// - File/FileInputStream ≈ dart:io File
// - SparseArray/ArrayMap ≈ LinkedHashMap en LRU
// - SharedPreferences ≈ Hive (usado en Favorites, no aquí)
// 
// ============================================================================
// DIFERENCIAS CON FAVORITES PAGE:
// ============================================================================
// - Favorites: Usa Hive (Preferences/KeyChain) - key-value inmediato
// - Notifications: Usa File I/O (FileManager) - lectura/escritura de archivos
// - Favorites: Usa CachedNetworkImage (Glide/Kingfisher) - cache de imágenes
// - Notifications: Usa LRU Cache manual (NSCache) - cache de objetos en memoria
// 
// ============================================================================
// MARCADORES: "✨ SP4 NOTIF:" en todo el código para visibilidad
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/cache/lru_cache_service.dart';
import '../../data/repositories/orders_repository.dart';
import '../../data/repositories/hive_repository.dart';
import '../../data/repositories/review_repository.dart';

// ============================================================================
// ✨ SP4 NOTIF: CLASE PRINCIPAL - NOTIFICATIONS PAGE
// ============================================================================
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  /// ✨ SP4 NOTIF: Método estático para agregar notificación desde cualquier lugar
  /// Uso: NotificationsPage.addNotification(type: 'order', title: '...', message: '...')
  static Future<void> addNotification({
    required String type,
    required String title,
    required String message,
    String? relatedId,
  }) async {
    try {
      print('✨ SP4 NOTIF: Agregando nueva notificación: $type - $title');
      
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/notifications.json';
      final file = File(filePath);
      
      List<Map<String, dynamic>> notifications = [];
      
      // Leer notificaciones existentes
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(contents);
        notifications = jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      // Agregar nueva notificación al inicio
      final newNotification = {
        'id': '${type}_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'icon': _getIconForType(type),
        'color': _getColorForType(type),
        if (relatedId != null) 'relatedId': relatedId,
      };
      
      notifications.insert(0, newNotification);
      
      // Limitar a 50 notificaciones máximo
      if (notifications.length > 50) {
        notifications = notifications.sublist(0, 50);
      }
      
      // Guardar al archivo
      final jsonString = jsonEncode(notifications);
      await file.writeAsString(jsonString);
      
      print('✨ SP4 NOTIF: ✅ Notificación agregada exitosamente');
      
    } catch (e) {
      print('✨ SP4 NOTIF: ⚠️ Error al agregar notificación: $e');
    }
  }
  
  static String _getIconForType(String type) {
    switch (type) {
      case 'order':
        return 'shopping_bag';
      case 'message':
        return 'chat';
      case 'favorite':
        return 'favorite';
      case 'review':
        return 'star';
      case 'system':
        return 'info';
      case 'promo':
        return 'local_offer';
      default:
        return 'notifications';
    }
  }
  
  static String _getColorForType(String type) {
    switch (type) {
      case 'order':
        return 'green';
      case 'message':
        return 'blue';
      case 'favorite':
        return 'red';
      case 'review':
        return 'amber';
      case 'system':
        return 'purple';
      case 'promo':
        return 'orange';
      default:
        return 'grey';
    }
  }

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // ============================================================================
  // ✨ SP4 NOTIF: STATE VARIABLES
  // ============================================================================
  
  /// ✨ SP4 NOTIF: Lista de notificaciones cargadas desde Local Files
  List<Map<String, dynamic>> _notifications = [];
  
  /// ✨ SP4 NOTIF: Loading state
  bool _isLoading = true;
  
  /// ✨ SP4 NOTIF: Error message si falla la lectura de archivos
  String? _errorMessage;
  
  /// ✨ SP4 NOTIF: LRU CACHE para notificaciones (NSCache / LRUCache equivalent)
  /// maxSize: 50 notificaciones en memoria
  /// onEvicted: callback cuando una notificación es expulsada del cache
  late final LruCacheService<String, Map<String, dynamic>> _lruCache;
  
  /// ✨ SP4 NOTIF: Path del archivo JSON donde se guardan las notificaciones
  File? _notificationsFile;
  
  /// ✨ SP4 NOTIF: Repositorios para obtener datos reales del usuario
  final _ordersRepo = OrdersRepository();
  final _hiveRepo = HiveRepository(baseUrl: 'http://3.19.208.242:8000/v1');
  final _reviewRepo = ReviewRepository();

  // ============================================================================
  // ✨ SP4 NOTIF: INIT STATE - Inicializar LRU Cache y cargar notificaciones
  // ============================================================================
  @override
  void initState() {
    super.initState();
    
    print('✨✨✨ SP4 NOTIF: Inicializando Notifications Page (Vista 4/4) ✨✨✨');
    
    // ✨ SP4 NOTIF: Crear LRU Cache con límite de 50 items
    // Equivalente a NSCache (iOS) / LRUCache (Android)
    _lruCache = LruCacheService<String, Map<String, dynamic>>(
      maxSize: 50,
      onEvicted: (key, value) {
        print('✨ SP4 NOTIF: 🗑️ Notificación $key expulsada del LRU Cache');
      },
    );
    
    print('✨ SP4 NOTIF: LRU Cache creado (equivalente a NSCache/LRUCache)');
    
    // ✨ SP4 NOTIF: Cargar notificaciones desde Local Files
    _loadNotifications();
  }

  // ============================================================================
  // ✨ SP4 NOTIF: CARGAR NOTIFICACIONES DESDE LOCAL FILES (FILE I/O)
  // ============================================================================
  /// Carga notificaciones desde archivo JSON en disco
  /// Equivalente a FileManager (iOS) / File API (Android)
  Future<void> _loadNotifications() async {
    print('✨ SP4 NOTIF: Cargando notificaciones desde Local Files...');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✨ SP4 NOTIF: Obtener directorio de documentos de la app
      // Equivalente a:
      // - iOS: FileManager.default.urls(for: .documentDirectory)
      // - Android: Context.getFilesDir()
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/notifications.json';
      _notificationsFile = File(filePath);
      
      print('✨ SP4 NOTIF: Ruta del archivo: $filePath');
      
      // ✨ SP4 NOTIF: Verificar si el archivo existe
      if (await _notificationsFile!.exists()) {
        print('✨ SP4 NOTIF: Archivo existe, leyendo contenido...');
        
        // ✨ SP4 NOTIF: Leer archivo como string (File I/O)
        final contents = await _notificationsFile!.readAsString();
        
        // ✨ SP4 NOTIF: Parsear JSON
        final List<dynamic> jsonData = jsonDecode(contents);
        
        // ✨ SP4 NOTIF: Convertir a lista de mapas
        _notifications = jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
        
        print('✨ SP4 NOTIF: ✅ ${_notifications.length} notificaciones cargadas desde disco');
        
        // ✨ SP4 NOTIF: Pre-cargar los primeros 10 notificaciones al LRU Cache
        // Esto mejora performance para las notificaciones más recientes
        for (int i = 0; i < _notifications.length && i < 10; i++) {
          final notif = _notifications[i];
          final notifId = notif['id'] as String;
          _lruCache.put(notifId, notif);
        }
        
        print('✨ SP4 NOTIF: Pre-cargadas ${_notifications.length < 10 ? _notifications.length : 10} notificaciones al LRU Cache');
        _lruCache.printStats();
        
      } else {
        print('✨ SP4 NOTIF: Archivo no existe, generando notificaciones basadas en datos reales...');
        
        // ✨ SP4 NOTIF: Crear notificaciones reales del usuario
        _notifications = await _createRealNotifications();
        
        // ✨ SP4 NOTIF: Guardar notificaciones reales al archivo
        await _saveNotificationsToFile();
      }
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e, stackTrace) {
      print('✨ SP4 NOTIF: ⚠️ Error al cargar notificaciones: $e');
      print('✨ SP4 NOTIF: Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar notificaciones: $e';
      });
    }
  }

  // ============================================================================
  // ✨ SP4 NOTIF: GUARDAR NOTIFICACIONES A LOCAL FILES (FILE I/O)
  // ============================================================================
  /// Guarda notificaciones al archivo JSON en disco
  /// Equivalente a FileManager.write() (iOS) / FileOutputStream (Android)
  Future<void> _saveNotificationsToFile() async {
    print('✨ SP4 NOTIF: Guardando notificaciones a Local Files...');
    
    try {
      if (_notificationsFile == null) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/notifications.json';
        _notificationsFile = File(filePath);
      }
      
      // ✨ SP4 NOTIF: Convertir notificaciones a JSON
      final jsonString = jsonEncode(_notifications);
      
      // ✨ SP4 NOTIF: Escribir al archivo (File I/O)
      await _notificationsFile!.writeAsString(jsonString);
      
      print('✨ SP4 NOTIF: ✅ ${_notifications.length} notificaciones guardadas en disco');
      print('✨ SP4 NOTIF: Archivo: ${_notificationsFile!.path}');
      
    } catch (e) {
      print('✨ SP4 NOTIF: ⚠️ Error al guardar notificaciones: $e');
      throw Exception('Error al guardar notificaciones: $e');
    }
  }

  // ============================================================================
  // ✨ SP4 NOTIF: OBTENER NOTIFICACIÓN POR ID (USANDO LRU CACHE)
  // ============================================================================
  /// Obtiene una notificación por ID, primero buscando en LRU Cache
  /// Si no está en cache (MISS), busca en la lista y lo agrega al cache
  /// Equivalente a NSCache.object(forKey:) con fallback a disco
  // ignore: unused_element
  Map<String, dynamic>? _getNotificationById(String notificationId) {
    print('✨ SP4 NOTIF: Obteniendo notificación $notificationId...');
    
    // ✨ SP4 NOTIF: Intentar obtener del LRU Cache primero (O(1))
    var notification = _lruCache.get(notificationId);
    
    if (notification != null) {
      // ✨ SP4 NOTIF: Cache HIT - Notificación encontrada en memoria
      print('✨ SP4 NOTIF: ✅ Cache HIT - Notificación obtenida del LRU Cache');
      return notification;
    }
    
    // ✨ SP4 NOTIF: Cache MISS - Buscar en la lista cargada de disco
    print('✨ SP4 NOTIF: ❌ Cache MISS - Buscando en lista de disco...');
    
    notification = _notifications.firstWhere(
      (notif) => notif['id'] == notificationId,
      orElse: () => {},
    );
    
    if (notification.isNotEmpty) {
      // ✨ SP4 NOTIF: Agregar al LRU Cache para futuras consultas
      _lruCache.put(notificationId, notification);
      print('✨ SP4 NOTIF: ✅ Notificación agregada al LRU Cache');
      return notification;
    }
    
    print('✨ SP4 NOTIF: ⚠️ Notificación no encontrada');
    return null;
  }

  // ============================================================================
  // ✨ SP4 NOTIF: MARCAR COMO LEÍDA
  // ============================================================================
  /// Marca una notificación como leída y actualiza el archivo
  Future<void> _markAsRead(String notificationId) async {
    print('✨ SP4 NOTIF: Marcando notificación $notificationId como leída...');
    
    try {
      // ✨ SP4 NOTIF: Actualizar en la lista
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        setState(() {
          _notifications[index]['isRead'] = true;
        });
        
        // ✨ SP4 NOTIF: Actualizar en LRU Cache si existe
        if (_lruCache.containsKey(notificationId)) {
          _lruCache.put(notificationId, _notifications[index]);
        }
        
        // ✨ SP4 NOTIF: Guardar cambios a Local Files
        await _saveNotificationsToFile();
        
        print('✨ SP4 NOTIF: ✅ Notificación marcada como leída');
      }
      
    } catch (e) {
      print('✨ SP4 NOTIF: ⚠️ Error al marcar como leída: $e');
    }
  }

  // ============================================================================
  // ✨ SP4 NOTIF: ELIMINAR NOTIFICACIÓN
  // ============================================================================
  /// Elimina una notificación de la lista, del disco y del cache
  Future<void> _deleteNotification(String notificationId) async {
    print('✨ SP4 NOTIF: Eliminando notificación $notificationId...');
    
    try {
      // ✨ SP4 NOTIF: Eliminar de la lista
      setState(() {
        _notifications.removeWhere((notif) => notif['id'] == notificationId);
      });
      
      // ✨ SP4 NOTIF: Guardar cambios a Local Files
      await _saveNotificationsToFile();
      
      // ✨ SP4 NOTIF: Eliminar del LRU Cache
      _lruCache.remove(notificationId);
      
      print('✨ SP4 NOTIF: ✅ Notificación eliminada exitosamente');
      _lruCache.printStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Notificación eliminada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
    } catch (e) {
      print('✨ SP4 NOTIF: ⚠️ Error al eliminar notificación: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================================
  // ✨ SP4 NOTIF: REFRESCAR NOTIFICACIONES
  // ============================================================================
  /// ✨ SP4 NOTIF: Regenera notificaciones basadas en datos actuales del usuario
  Future<void> _refreshNotifications() async {
    print('✨ SP4 NOTIF: Refrescando notificaciones...');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // ✨ SP4 NOTIF: Generar nuevas notificaciones desde datos reales
      _notifications = await _createRealNotifications();
      
      // ✨ SP4 NOTIF: Guardar al archivo
      await _saveNotificationsToFile();
      
      // ✨ SP4 NOTIF: Limpiar y recargar cache
      _lruCache.clear();
      for (int i = 0; i < _notifications.length && i < 10; i++) {
        final notif = _notifications[i];
        final notifId = notif['id'] as String;
        _lruCache.put(notifId, notif);
      }
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notificaciones actualizadas'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      print('✨ SP4 NOTIF: ✅ Notificaciones refrescadas exitosamente');
      
    } catch (e) {
      print('✨ SP4 NOTIF: ⚠️ Error al refrescar notificaciones: $e');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al actualizar: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================================
  // ✨ SP4 NOTIF: CREAR NOTIFICACIONES REALES
  // ============================================================================
  /// ✨ SP4 NOTIF: Crear notificaciones basadas en acciones reales del usuario
  Future<List<Map<String, dynamic>>> _createRealNotifications() async {
    print('✨ SP4 NOTIF: Generando notificaciones basadas en datos reales del usuario...');
    
    final List<Map<String, dynamic>> notifications = [];
    final now = DateTime.now();
    
    try {
      // ============================================================================
      // ✨ SP4 NOTIF: 1. NOTIFICACIONES DE ÓRDENES
      // ============================================================================
      try {
        print('✨ SP4 NOTIF: Obteniendo órdenes del usuario...');
        final orders = await _ordersRepo.getMyOrders(pageSize: 5);
        
        for (final order in orders) {
          notifications.add({
            'id': 'order_${order.id}',
            'type': 'order',
            'title': _getOrderTitle(order.status),
            'message': 'Orden #${order.id.substring(0, 8)} - ${_getOrderMessage(order.status)}',
            'timestamp': order.createdAt.toIso8601String(),
            'isRead': false,
            'icon': 'shopping_bag',
            'color': _getOrderColor(order.status),
            'relatedId': order.id,
          });
        }
        print('✨ SP4 NOTIF: ✅ ${orders.length} notificaciones de órdenes generadas');
      } catch (e) {
        print('✨ SP4 NOTIF: ⚠️ Error al obtener órdenes: $e');
      }
      
      // ============================================================================
      // ✨ SP4 NOTIF: 2. NOTIFICACIONES DE FAVORITOS
      // ============================================================================
      try {
        print('✨ SP4 NOTIF: Obteniendo favoritos del usuario...');
        final favorites = await _hiveRepo.getFavorites();
        
        if (favorites.isNotEmpty) {
          // Generar notificación sobre productos favoritos guardados
          notifications.add({
            'id': 'favorites_${now.millisecondsSinceEpoch}',
            'type': 'favorite',
            'title': '💖 Tienes ${favorites.length} favoritos',
            'message': 'Revisa tus productos guardados y encuentra las mejores ofertas',
            'timestamp': now.subtract(const Duration(hours: 1)).toIso8601String(),
            'isRead': true,
            'icon': 'favorite',
            'color': 'red',
          });
        }
        print('✨ SP4 NOTIF: ✅ Notificación de favoritos generada (${favorites.length} items)');
      } catch (e) {
        print('✨ SP4 NOTIF: ⚠️ Error al obtener favoritos: $e');
      }
      
      // ============================================================================
      // ✨ SP4 NOTIF: 3. NOTIFICACIONES DE REVIEWS
      // ============================================================================
      try {
        print('✨ SP4 NOTIF: Obteniendo reviews del usuario...');
        
        // Obtener userId de la sesión de Hive
        final userId = await _hiveRepo.getCurrentUserId();
        
        if (userId != null && userId.isNotEmpty) {
          final reviews = await _reviewRepo.loadUserReviewsAsync(userId, limit: 3);
          
          for (final review in reviews) {
            notifications.add({
              'id': 'review_${review.id}',
              'type': 'review',
              'title': 'Review publicada ⭐',
              'message': 'Tu reseña de ${review.rating} estrellas ha sido publicada',
              'timestamp': review.createdAt.toIso8601String(),
              'isRead': true,
              'icon': 'star',
              'color': 'amber',
              'relatedId': review.id,
            });
          }
          print('✨ SP4 NOTIF: ✅ ${reviews.length} notificaciones de reviews generadas');
        } else {
          print('✨ SP4 NOTIF: ⚠️ No hay userId en sesión, omitiendo reviews');
        }
      } catch (e) {
        print('✨ SP4 NOTIF: ⚠️ Error al obtener reviews: $e');
      }
      
      // ============================================================================
      // ✨ SP4 NOTIF: 4. NOTIFICACIÓN DE BIENVENIDA (si no hay otras)
      // ============================================================================
      if (notifications.isEmpty) {
        print('✨ SP4 NOTIF: No hay actividad reciente, generando notificación de bienvenida...');
        notifications.add({
          'id': 'welcome_${now.millisecondsSinceEpoch}',
          'type': 'system',
          'title': '¡Bienvenido! 👋',
          'message': 'Explora el marketplace y encuentra productos increíbles',
          'timestamp': now.toIso8601String(),
          'isRead': false,
          'icon': 'info',
          'color': 'blue',
        });
      }
      
      // Ordenar por timestamp (más reciente primero)
      notifications.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'] as String);
        final bTime = DateTime.parse(b['timestamp'] as String);
        return bTime.compareTo(aTime);
      });
      
      print('✨ SP4 NOTIF: ✅ Total de ${notifications.length} notificaciones reales generadas');
      
    } catch (e, stackTrace) {
      print('✨ SP4 NOTIF: ⚠️ Error general al generar notificaciones: $e');
      print('✨ SP4 NOTIF: Stack trace: $stackTrace');
      
      // Fallback: notificación de error
      notifications.add({
        'id': 'error_${now.millisecondsSinceEpoch}',
        'type': 'system',
        'title': 'Error al cargar notificaciones',
        'message': 'No se pudieron cargar tus notificaciones. Intenta más tarde.',
        'timestamp': now.toIso8601String(),
        'isRead': false,
        'icon': 'error',
        'color': 'red',
      });
    }
    
    return notifications;
  }
  
  /// ✨ SP4 NOTIF: Helper - Obtener título según estado de orden
  String _getOrderTitle(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '⏳ Orden pendiente';
      case 'confirmed':
        return '✅ Orden confirmada';
      case 'processing':
        return '📦 Orden en preparación';
      case 'shipped':
        return '🚚 Orden enviada';
      case 'delivered':
        return '🎉 Orden entregada';
      case 'cancelled':
        return '❌ Orden cancelada';
      default:
        return '📋 Actualización de orden';
    }
  }
  
  /// ✨ SP4 NOTIF: Helper - Obtener mensaje según estado de orden
  String _getOrderMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Esperando confirmación del vendedor';
      case 'confirmed':
        return 'Tu orden ha sido confirmada y está siendo preparada';
      case 'processing':
        return 'Estamos preparando tu pedido';
      case 'shipped':
        return 'Tu pedido está en camino';
      case 'delivered':
        return '¡Tu pedido ha sido entregado exitosamente!';
      case 'cancelled':
        return 'La orden ha sido cancelada';
      default:
        return 'Estado actualizado';
    }
  }
  
  /// ✨ SP4 NOTIF: Helper - Obtener color según estado de orden
  String _getOrderColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'orange';
      case 'confirmed':
      case 'delivered':
        return 'green';
      case 'processing':
        return 'blue';
      case 'shipped':
        return 'purple';
      case 'cancelled':
        return 'red';
      default:
        return 'grey';
    }
  }

  // ============================================================================
  // ✨ SP4 NOTIF: BUILD UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !(n['isRead'] as bool)).length;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔔 Notificaciones'),
            if (unreadCount > 0)
              Text(
                '$unreadCount sin leer',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          // ✨ SP4 NOTIF: Botón para regenerar notificaciones reales
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar notificaciones',
            onPressed: _refreshNotifications,
          ),
          // ✨ SP4 NOTIF: Botón para ver estadísticas del LRU Cache
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Ver estadísticas del cache',
            onPressed: _showCacheStats,
          ),
          // ✨ SP4 NOTIF: Botón para limpiar cache
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Limpiar LRU Cache',
            onPressed: _clearCache,
          ),
          // ✨ SP4 NOTIF: Marcar todas como leídas
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: Column(
        children: [
          // ✨ SP4 NOTIF: Tech badges mostrando tecnologías usadas
          _buildTechBadges(),
          
          // ✨ SP4 NOTIF: Lista de notificaciones
          Expanded(
            child: _buildNotificationsList(),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ✨ SP4 NOTIF: TECH BADGES - Mostrar tecnologías implementadas
  // ============================================================================
  Widget _buildTechBadges() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBadge('📁 Local Files', Colors.blue),
          const SizedBox(width: 8),
          _buildBadge('🧠 LRU Cache', Colors.purple),
          const SizedBox(width: 8),
          _buildBadge('Vista 4/4', Colors.green),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================================
  // ✨ SP4 NOTIF: LISTA DE NOTIFICACIONES
  // ============================================================================
  Widget _buildNotificationsList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('📁 Cargando notificaciones desde Local Files...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay notificaciones'),
            SizedBox(height: 8),
            Text(
              'Recibirás notificaciones sobre tus pedidos,\nmensajes y actualizaciones',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  // ============================================================================
  // ✨ SP4 NOTIF: NOTIFICATION CARD
  // ============================================================================
  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final notificationId = notification['id'] as String;
    final type = notification['type'] as String;
    final title = notification['title'] as String;
    final message = notification['message'] as String;
    final timestamp = DateTime.parse(notification['timestamp'] as String);
    final isRead = notification['isRead'] as bool;
    final iconName = notification['icon'] as String;
    final colorName = notification['color'] as String;

    final icon = _getIconData(iconName);
    final color = _getColor(colorName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isRead ? null : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getTypeLabel(type),
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (!isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.done, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Marcar como leída'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'mark_read') {
              _markAsRead(notificationId);
            } else if (value == 'delete') {
              _confirmDelete(notificationId);
            }
          },
        ),
        onTap: () {
          if (!isRead) {
            _markAsRead(notificationId);
          }
          _showNotificationDetails(notification);
        },
      ),
    );
  }

  // ============================================================================
  // ✨ SP4 NOTIF: HELPERS
  // ============================================================================
  
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'chat':
        return Icons.chat_bubble;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'system_update':
        return Icons.system_update;
      case 'local_offer':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'amber':
        return Colors.amber;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'order':
        return 'PEDIDO';
      case 'message':
        return 'MENSAJE';
      case 'favorite':
        return 'FAVORITO';
      case 'review':
        return 'RESEÑA';
      case 'system':
        return 'SISTEMA';
      case 'promo':
        return 'PROMO';
      default:
        return type.toUpperCase();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Justo ahora';
    }
  }

  // ============================================================================
  // ✨ SP4 NOTIF: DIALOGS
  // ============================================================================
  
  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getIconData(notification['icon'] as String)),
            const SizedBox(width: 8),
            Expanded(child: Text(notification['title'] as String)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'] as String,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Recibido: ${_formatTimestamp(DateTime.parse(notification['timestamp'] as String))}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String notificationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Eliminar Notificación'),
        content: const Text('¿Estás seguro de que quieres eliminar esta notificación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteNotification(notificationId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showCacheStats() {
    final stats = _lruCache.stats;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧠 Estadísticas LRU Cache'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tamaño máximo: ${stats['maxSize']}'),
            Text('Items actuales: ${stats['currentSize']}'),
            const Divider(),
            Text('Hits (encontrados): ${stats['hitCount']}'),
            Text('Misses (no encontrados): ${stats['missCount']}'),
            Text('Evictions (expulsados): ${stats['evictionCount']}'),
            const Divider(),
            Text(
              'Hit Rate: ${stats['hitRate']}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    _lruCache.clear();
    _lruCache.resetStats();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧹 LRU Cache limpiado'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    print('✨ SP4 NOTIF: Marcando todas las notificaciones como leídas...');
    
    try {
      setState(() {
        for (var notif in _notifications) {
          notif['isRead'] = true;
          // Actualizar en cache si existe
          if (_lruCache.containsKey(notif['id'] as String)) {
            _lruCache.put(notif['id'] as String, notif);
          }
        }
      });
      
      await _saveNotificationsToFile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Todas las notificaciones marcadas como leídas'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      print('✨ SP4 NOTIF: ⚠️ Error al marcar todas como leídas: $e');
    }
  }

  @override
  void dispose() {
    print('✨ SP4 NOTIF: Liberando recursos de Notifications Page...');
    _lruCache.printStats();
    super.dispose();
  }
}
