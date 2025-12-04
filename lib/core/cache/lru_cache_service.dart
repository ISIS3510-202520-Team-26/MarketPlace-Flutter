// ============================================================================
// ✨✨✨ SP4 NOTIF: LRU CACHE SERVICE - CACHÉ LEAST RECENTLY USED ✨✨✨
// ============================================================================
// Este archivo implementa un sistema de caché LRU (Least Recently Used) manual
// Equivalente a:
// - iOS: NSCache
// - Android: LRUCache / SparseArray / ArrayMap
// - Java: LinkedHashMap con removeEldestEntry
// 
// FUNCIONAMIENTO LRU:
// - Almacena elementos en memoria con límite de capacidad
// - Al alcanzar el límite, elimina el elemento MENOS RECIENTEMENTE usado
// - Usa LinkedHashMap para mantener orden de acceso (accessOrder: true)
// - O(1) para get/put/remove gracias al HashMap
// - Útil para cachear imágenes, respuestas API, archivos decodificados
//
// DIFERENCIAS CON OTRAS ESTRUCTURAS:
// - SparseArray (Android): Solo claves int, más eficiente en memoria
// - ArrayMap (Android): Más lento pero usa menos memoria que HashMap
// - NSCache (iOS): Automáticamente libera memoria bajo presión
// - LRUCache (Android): Necesita override de sizeOf() para objetos grandes
//
// ESTE IMPLEMENTACIÓN:
// - Genérico: Soporta cualquier tipo K (key) y V (value)
// - Control manual de tamaño máximo
// - Estadísticas de hits/misses para debugging
// - Thread-safe no implementado (úsalo en un solo Isolate)
// - Eviction callbacks opcionales
//
// MARCADORES: "✨ SP4 NOTIF:" en todos los métodos para visibilidad
// ============================================================================

import 'dart:collection';

// ============================================================================
// ✨ SP4 NOTIF: CLASE PRINCIPAL - LRU CACHE
// ============================================================================
/// Cache LRU genérico con límite de capacidad
/// Equivalente a NSCache (iOS) / LRUCache (Android)
class LruCacheService<K, V> {
  /// ✨ SP4 MSG: Tamaño máximo del cache (número de items)
  final int maxSize;
  
  /// ✨ SP4 MSG: Callback cuando un item es evicted (expulsado)
  final void Function(K key, V value)? onEvicted;
  
  /// ✨ SP4 MSG: LinkedHashMap con accessOrder = true (mantiene orden de acceso)
  /// Equivalente a LinkedHashMap<K,V>(accessOrder: true) en Java
  late final LinkedHashMap<K, V> _cache;
  
  /// ✨ SP4 MSG: Estadísticas - Número de hits (encontrado en cache)
  int _hitCount = 0;
  
  /// ✨ SP4 MSG: Estadísticas - Número de misses (no encontrado, fetch externo)
  int _missCount = 0;
  
  /// ✨ SP4 MSG: Estadísticas - Número de evictions (eliminaciones por límite)
  int _evictionCount = 0;

  // ============================================================================
  // ✨ SP4 MSG: CONSTRUCTOR
  // ============================================================================
  LruCacheService({
    required this.maxSize,
    this.onEvicted,
  }) : assert(maxSize > 0, 'maxSize debe ser mayor a 0') {
    _cache = LinkedHashMap<K, V>();
    print('✨ SP4 MSG: LRU Cache creado con maxSize=$maxSize');
    print('✨ SP4 MSG: Equivalente a NSCache (iOS) / LRUCache (Android)');
  }

  // ============================================================================
  // ✨ SP4 MSG: OBTENER VALOR DEL CACHE (GET)
  // ============================================================================
  /// Obtiene un valor del cache. Si existe, lo mueve al final (más reciente)
  /// Equivalente a NSCache.object(forKey:) / LRUCache.get()
  V? get(K key) {
    print('✨ SP4 MSG: LRU get($key)');
    
    if (_cache.containsKey(key)) {
      // IMPORTANTE: Remove y re-insert para mover al final (más reciente)
      // Esto simula el accessOrder de Java LinkedHashMap
      final value = _cache.remove(key)!;
      _cache[key] = value;
      
      _hitCount++;
      print('✨ SP4 MSG: ✅ Cache HIT - Item encontrado (hits: $_hitCount)');
      return value;
    } else {
      _missCount++;
      print('✨ SP4 MSG: ❌ Cache MISS - Item no existe (misses: $_missCount)');
      return null;
    }
  }

  // ============================================================================
  // ✨ SP4 MSG: AGREGAR/ACTUALIZAR VALOR EN CACHE (PUT)
  // ============================================================================
  /// Agrega o actualiza un valor en el cache
  /// Si excede maxSize, elimina el elemento MENOS RECIENTEMENTE usado (LRU)
  /// Equivalente a NSCache.setObject() / LRUCache.put()
  void put(K key, V value) {
    print('✨ SP4 MSG: LRU put($key)');
    
    // Si la key ya existe, la removemos primero (para re-insertarla al final)
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      print('✨ SP4 MSG: Key existente actualizada');
    }
    
    // Agregar el nuevo valor al final (más reciente)
    _cache[key] = value;
    
    // ✨ SP4 MSG: EVICTION POLICY - Si excedimos el tamaño, eliminar el más viejo
    // LinkedHashMap mantiene orden de inserción, el primero es el MÁS VIEJO
    if (_cache.length > maxSize) {
      final oldestKey = _cache.keys.first; // Primer key = menos reciente
      final oldestValue = _cache.remove(oldestKey)!;
      
      _evictionCount++;
      print('✨ SP4 MSG: 🗑️ EVICTION - Eliminado item LRU: $oldestKey (evictions: $_evictionCount)');
      
      // Callback de eviction si fue configurado
      onEvicted?.call(oldestKey, oldestValue);
    }
    
    print('✨ SP4 MSG: ✅ Item agregado al cache (size: ${_cache.length}/$maxSize)');
  }

  // ============================================================================
  // ✨ SP4 MSG: ELIMINAR VALOR DEL CACHE (REMOVE)
  // ============================================================================
  /// Elimina un valor específico del cache
  /// Equivalente a NSCache.removeObject(forKey:) / LRUCache.remove()
  V? remove(K key) {
    print('✨ SP4 MSG: LRU remove($key)');
    
    final value = _cache.remove(key);
    if (value != null) {
      print('✨ SP4 MSG: ✅ Item eliminado del cache');
    } else {
      print('✨ SP4 MSG: ⚠️ Item no existe en cache');
    }
    
    return value;
  }

  // ============================================================================
  // ✨ SP4 MSG: LIMPIAR TODO EL CACHE (CLEAR)
  // ============================================================================
  /// Limpia todo el cache
  /// Equivalente a NSCache.removeAllObjects() / LRUCache.evictAll()
  void clear() {
    print('✨ SP4 MSG: Limpiando TODO el cache...');
    
    final size = _cache.length;
    _cache.clear();
    
    print('✨ SP4 MSG: ✅ Cache limpiado ($size items eliminados)');
  }

  // ============================================================================
  // ✨ SP4 MSG: VERIFICAR SI EXISTE UNA KEY (CONTAINS)
  // ============================================================================
  /// Verifica si una key existe en el cache SIN moverla al final (sin side effects)
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  // ============================================================================
  // ✨ SP4 MSG: OBTENER TAMAÑO ACTUAL DEL CACHE (SIZE)
  // ============================================================================
  /// Retorna el número de items actualmente en el cache
  int get size => _cache.length;

  /// Retorna si el cache está vacío
  bool get isEmpty => _cache.isEmpty;

  /// Retorna si el cache está lleno
  bool get isFull => _cache.length >= maxSize;

  // ============================================================================
  // ✨ SP4 MSG: ESTADÍSTICAS DEL CACHE (DEBUGGING)
  // ============================================================================
  /// Retorna estadísticas del cache para debugging
  Map<String, dynamic> get stats => {
        'maxSize': maxSize,
        'currentSize': _cache.length,
        'hitCount': _hitCount,
        'missCount': _missCount,
        'evictionCount': _evictionCount,
        'hitRate': _hitCount + _missCount > 0
            ? (_hitCount / (_hitCount + _missCount) * 100).toStringAsFixed(2)
            : '0.00',
      };

  /// Imprime estadísticas del cache
  void printStats() {
    print('✨ SP4 MSG: ═══════════════════════════════════');
    print('✨ SP4 MSG: LRU CACHE STATISTICS');
    print('✨ SP4 MSG: ═══════════════════════════════════');
    print('✨ SP4 MSG: Max Size: $maxSize');
    print('✨ SP4 MSG: Current Size: ${_cache.length}');
    print('✨ SP4 MSG: Hits: $_hitCount');
    print('✨ SP4 MSG: Misses: $_missCount');
    print('✨ SP4 MSG: Evictions: $_evictionCount');
    print('✨ SP4 MSG: Hit Rate: ${stats['hitRate']}%');
    print('✨ SP4 MSG: ═══════════════════════════════════');
  }

  /// Resetea las estadísticas del cache (no limpia los datos)
  void resetStats() {
    print('✨ SP4 MSG: Reseteando estadísticas del cache...');
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
  }

  // ============================================================================
  // ✨ SP4 MSG: OBTENER TODAS LAS KEYS Y VALUES
  // ============================================================================
  /// Retorna todas las keys en orden de acceso (más reciente al final)
  Iterable<K> get keys => _cache.keys;

  /// Retorna todos los values
  Iterable<V> get values => _cache.values;

  /// Retorna todas las entries (key-value pairs)
  Iterable<MapEntry<K, V>> get entries => _cache.entries;
}

// ============================================================================
// ✨ SP4 MSG: EJEMPLO DE USO
// ============================================================================
// void main() {
//   // Crear cache LRU para mensajes con límite de 5 items
//   final cache = LruCacheService<String, Map<String, dynamic>>(
//     maxSize: 5,
//     onEvicted: (key, value) {
//       print('Item $key fue evicted del cache');
//     },
//   );
//
//   // Agregar items
//   cache.put('msg1', {'text': 'Hello', 'sender': 'Alice'});
//   cache.put('msg2', {'text': 'Hi', 'sender': 'Bob'});
//
//   // Obtener item (cache hit)
//   final msg1 = cache.get('msg1'); // HIT
//
//   // Obtener item inexistente (cache miss)
//   final msg99 = cache.get('msg99'); // MISS
//
//   // Imprimir estadísticas
//   cache.printStats();
// }
