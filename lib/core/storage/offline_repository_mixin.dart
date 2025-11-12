// lib/core/storage/offline_repository_mixin.dart
import 'dart:async';
import '../net/connectivity_service.dart';

/// Mixin para repositorios con soporte offline
/// 
/// Proporciona funcionalidad para:
/// - Detectar conectividad
/// - Estrategia: API first, fallback a local storage
/// - Cache automático cuando hay conexión
mixin OfflineRepositoryMixin {
  /// Verifica si hay conexión a internet
  Future<bool> get hasConnection async {
    return ConnectivityService.instance.isOnline;
  }

  /// Ejecuta una operación con fallback a cache
  /// 
  /// 1. Intenta ejecutar `fetchFromApi`
  /// 2. Si tiene éxito, guarda en cache con `saveToCache`
  /// 3. Si falla por conexión, intenta `fetchFromCache`
  Future<T> executeWithFallback<T>({
    required Future<T> Function() fetchFromApi,
    required Future<void> Function(T data) saveToCache,
    required Future<T?> Function() fetchFromCache,
    required String errorMessage,
  }) async {
    try {
      // Intentar primero del API
      final data = await fetchFromApi();
      
      // Guardar en cache para uso offline
      try {
        await saveToCache(data);
      } catch (e) {
        print('[OfflineRepo] ⚠️ Error guardando en cache: $e');
      }
      
      return data;
    } catch (e) {
      print('[OfflineRepo] ❌ Error en API: $e');
      
      // Verificar si es error de conexión
      final isOnline = await hasConnection;
      
      if (!isOnline) {
        print('[OfflineRepo] 📦 Sin conexión, intentando cache local...');
        final cachedData = await fetchFromCache();
        
        if (cachedData != null) {
          print('[OfflineRepo] ✅ Datos recuperados del cache');
          return cachedData;
        }
        
        throw 'Sin conexión y sin datos en cache';
      }
      
      // Si hay conexión pero falló, propagar el error
      throw errorMessage;
    }
  }

  /// Ejecuta operación optimista (muestra cache primero, actualiza después)
  /// 
  /// 1. Devuelve cache inmediatamente si existe
  /// 2. En background, actualiza desde API
  /// 3. Notifica cambios via callback
  Future<T?> executeOptimistic<T>({
    required Future<T?> Function() fetchFromCache,
    required Future<T> Function() fetchFromApi,
    required Future<void> Function(T data) saveToCache,
    void Function(T data)? onUpdated,
  }) async {
    // Mostrar cache primero (si existe)
    final cachedData = await fetchFromCache();
    
    // Actualizar en background
    _updateInBackground(
      fetchFromApi: fetchFromApi,
      saveToCache: saveToCache,
      onUpdated: onUpdated,
    );
    
    return cachedData;
  }

  /// Actualiza datos en background sin bloquear
  Future<void> _updateInBackground<T>({
    required Future<T> Function() fetchFromApi,
    required Future<void> Function(T data) saveToCache,
    void Function(T data)? onUpdated,
  }) async {
    try {
      final data = await fetchFromApi();
      await saveToCache(data);
      onUpdated?.call(data);
      print('[OfflineRepo] 🔄 Cache actualizado en background');
    } catch (e) {
      print('[OfflineRepo] ⚠️ Error en actualización background: $e');
    }
  }
}
