// lib/core/storage/offline_repository_mixin.dart
import 'dart:async';
import '../net/connectivity_service.dart';


mixin OfflineRepositoryMixin {
  /// Verifica si hay conexión a internet
  Future<bool> get hasConnection async {
    return ConnectivityService.instance.isOnline;
  }

  /// Ejecuta una operación con fallback a cache
  Future<T> executeWithFallback<T>({
    required Future<T> Function() fetchFromApi,
    required Future<void> Function(T data) saveToCache,
    required Future<T?> Function() fetchFromCache,
    required String errorMessage,
  }) async {
    final isOnline = await hasConnection;
    
    if (!isOnline) {
      print('[OfflineRepo] Sin conexión, usando cache local...');
      final cachedData = await fetchFromCache();
      
      if (cachedData != null) {
        print('[OfflineRepo] Datos recuperados del cache');
        return cachedData;
      }
      
      throw 'Sin conexión y sin datos en cache';
    }
    
    try {
      final data = await fetchFromApi();
      
      try {
        await saveToCache(data);
      } catch (e) {
        print('[OfflineRepo] Error guardando en cache: $e');
      }
      
      return data;
    } catch (e) {
      print('[OfflineRepo] Error en API: $e');
      
      print('[OfflineRepo] API falló, intentando cache local...');
      final cachedData = await fetchFromCache();
      
      if (cachedData != null) {
        print('[OfflineRepo] Datos recuperados del cache (fallback)');
        return cachedData;
      }
      
      throw errorMessage;
    }
  }

  Future<T?> executeOptimistic<T>({
    required Future<T?> Function() fetchFromCache,
    required Future<T> Function() fetchFromApi,
    required Future<void> Function(T data) saveToCache,
    void Function(T data)? onUpdated,
  }) async {
    final cachedData = await fetchFromCache();
    
    _updateInBackground(
      fetchFromApi: fetchFromApi,
      saveToCache: saveToCache,
      onUpdated: onUpdated,
    );
    
    return cachedData;
  }

  Future<void> _updateInBackground<T>({
    required Future<T> Function() fetchFromApi,
    required Future<void> Function(T data) saveToCache,
    void Function(T data)? onUpdated,
  }) async {
    try {
      final data = await fetchFromApi();
      await saveToCache(data);
      onUpdated?.call(data);
      print('[OfflineRepo] Cache actualizado en background');
    } catch (e) {
      print('[OfflineRepo] Error en actualización background: $e');
    }
  }
}
