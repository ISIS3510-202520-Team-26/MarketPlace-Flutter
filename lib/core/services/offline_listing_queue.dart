import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/pending_listing.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/listings_repository.dart';
import '../net/connectivity_service.dart';

/// Sistema de Cola Offline para Publicaciones
/// 
/// Permite crear publicaciones sin conexión y subirlas automáticamente
/// cuando se detecta conectividad.
class OfflineListingQueue {
  OfflineListingQueue._();
  static final OfflineListingQueue instance = OfflineListingQueue._();

  final _listingsRepo = ListingsRepository();
  final _connectivity = ConnectivityService.instance;
  final _uuid = const Uuid();
  
  static const _queueKey = 'offline_listing_queue';
  
  final _listeners = <VoidCallback>[];
  List<PendingListing> _queue = [];
  bool _isProcessing = false;
  Timer? _retryTimer;

  Future<void> initialize() async {
    print('[OfflineQueue] Inicializando cola de publicaciones offline...');
    await _loadQueue();
    _startPeriodicRetry();
    print('[OfflineQueue] Cola inicializada con ${_queue.length} publicaciones pendientes');
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        print('[OfflineQueue] Error en listener: $e');
      }
    }
  }

  List<PendingListing> get pendingListings => List.unmodifiable(_queue);
  int get pendingCount => _queue.where((l) => !l.isCompleted).length;
  bool get hasUploading => _queue.any((l) => l.isUploading);

  Future<String> enqueue({
    required String title,
    String? description,
    required String categoryId,
    String? brandId,
    required int priceCents,
    String currency = 'COP',
    String condition = 'used',
    int quantity = 1,
    double? latitude,
    double? longitude,
    bool priceSuggestionUsed = false,
    List<int>? imageBytes,
    String? imageName,
    String? imageContentType,
  }) async {
    print('[OfflineQueue] Agregando nueva publicación a la cola...');
    
    final id = _uuid.v4();
    final now = DateTime.now();
    
    String? imageBase64;
    if (imageBytes != null) {
      try {
        imageBase64 = base64Encode(imageBytes);
        print('[OfflineQueue] Imagen codificada: ${imageBytes.length} bytes');
      } catch (e) {
        print('[OfflineQueue] Error al codificar imagen: $e');
      }
    }
    
    final pending = PendingListing(
      id: id,
      title: title,
      description: description,
      categoryId: categoryId,
      brandId: brandId,
      priceCents: priceCents,
      currency: currency,
      condition: condition,
      quantity: quantity,
      latitude: latitude,
      longitude: longitude,
      priceSuggestionUsed: priceSuggestionUsed,
      imageBase64: imageBase64,
      imageName: imageName,
      imageContentType: imageContentType,
      createdAt: now,
      lastAttemptAt: now,
      attemptCount: 0,
      status: 'pending',
    );
    
    _queue.add(pending);
    await _saveQueue();
    _notifyListeners();
    
    print('[OfflineQueue] Publicación agregada: $id');
    _processQueueInBackground();
    
    return id;
  }

  void _processQueueInBackground() {
    if (_isProcessing) {
      print('[OfflineQueue] Ya hay un proceso en ejecución');
      return;
    }
    
    Future(() async {
      await processQueue();
    }).catchError((error) {
      print('[OfflineQueue] Error en procesamiento background: $error');
    });
  }

  Future<void> processQueue() async {
    if (_isProcessing) {
      print('[OfflineQueue] Procesamiento ya en curso');
      return;
    }
    
    if (_queue.isEmpty) {
      print('[OfflineQueue] Cola vacía, nada que procesar');
      return;
    }
    
    final isOnline = await _connectivity.isOnline;
    if (!isOnline) {
      print('[OfflineQueue] Sin conexión, esperando...');
      return;
    }
    
    _isProcessing = true;
    print('[OfflineQueue] Iniciando procesamiento de ${_queue.length} publicaciones...');
    
    try {
      for (var i = 0; i < _queue.length; i++) {
        final pending = _queue[i];
        
        if (pending.isCompleted) continue;
        if (!pending.shouldRetry) {
          print('[OfflineQueue] Saltando ${pending.id} (max intentos alcanzado)');
          continue;
        }
        
        print('[OfflineQueue] Procesando: ${pending.title} (intento ${pending.attemptCount + 1})');
        
        _queue[i] = pending.copyWith(
          status: 'uploading',
          lastAttemptAt: DateTime.now(),
        );
        await _saveQueue();
        _notifyListeners();
        
        final currentPending = _queue[i];
        
        try {
          await _uploadPendingListing(currentPending);
          
          _queue[i] = currentPending.copyWith(
            status: 'completed',
            attemptCount: currentPending.attemptCount + 1,
            lastAttemptAt: DateTime.now(),
          );
          
          print('[OfflineQueue] Publicación subida exitosamente: ${currentPending.title}');
          
        } catch (e) {
          final newAttemptCount = currentPending.attemptCount + 1;
          final shouldRetry = newAttemptCount < 5;
          
          _queue[i] = currentPending.copyWith(
            status: shouldRetry ? 'pending' : 'failed',
            attemptCount: newAttemptCount,
            lastAttemptAt: DateTime.now(),
            errorMessage: e.toString(),
          );
          
          print('[OfflineQueue] Error al subir ${currentPending.title}: $e');
          print('[OfflineQueue] Intentos: $newAttemptCount/5');
        }
        
        await _saveQueue();
        _notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
      }
  
      _cleanupCompletedListings();
      
    } catch (e) {
      print('[OfflineQueue] Error general en procesamiento: $e');
    } finally {
      _isProcessing = false;
      print('[OfflineQueue] Procesamiento finalizado');
    }
  }

  Future<void> _uploadPendingListing(PendingListing pending) async {
    final listing = Listing(
      id: '',
      sellerId: '',
      title: pending.title,
      description: pending.description,
      categoryId: pending.categoryId,
      brandId: pending.brandId,
      priceCents: pending.priceCents,
      currency: pending.currency,
      condition: pending.condition,
      quantity: pending.quantity,
      isActive: true,
      latitude: pending.latitude,
      longitude: pending.longitude,
      priceSuggestionUsed: pending.priceSuggestionUsed,
      quickViewEnabled: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    print('[OfflineQueue] Creando listing en backend...');
    final createdListing = await _listingsRepo.createListing(listing);
    print('[OfflineQueue] Listing creado: ${createdListing.id}');
    
    final imageBytes = pending.getImageBytes();
    if (imageBytes != null && pending.imageName != null) {
      print('[OfflineQueue] Subiendo imagen (${imageBytes.length} bytes)...');
      
      await _listingsRepo.uploadListingImage(
        listingId: createdListing.id,
        imageBytes: imageBytes,
        filename: pending.imageName!,
        contentType: pending.imageContentType ?? 'image/jpeg',
      );
      
      print('[OfflineQueue] Imagen subida exitosamente');
    }
  }

  void _startPeriodicRetry() {
    _retryTimer?.cancel();
    
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      print('[OfflineQueue] Timer de reintento activado');
      _processQueueInBackground();
    });
  }

  void _cleanupCompletedListings() {
    final now = DateTime.now();
    final before = _queue.length;
    
    _queue.removeWhere((listing) {
      if (!listing.isCompleted) return false;
      final age = now.difference(listing.lastAttemptAt);
      return age.inHours > 24;
    });
    
    final removed = before - _queue.length;
    if (removed > 0) {
      print('[OfflineQueue] Limpiadas $removed publicaciones completadas antiguas');
      _saveQueue();
      _notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    final before = _queue.length;
    _queue.removeWhere((l) => l.id == id);
    
    if (_queue.length < before) {
      await _saveQueue();
      _notifyListeners();
      print('[OfflineQueue] Publicación eliminada: $id');
    }
  }

  Future<void> retry(String id) async {
    final index = _queue.indexWhere((l) => l.id == id);
    if (index == -1) return;
    
    final pending = _queue[index];
    _queue[index] = pending.copyWith(
      status: 'pending',
      errorMessage: null,
    );
    
    await _saveQueue();
    _notifyListeners();
    
    print('[OfflineQueue] Reintentando publicación: $id');
    _processQueueInBackground();
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _queue.map((l) => l.toJson()).toList();
      final encoded = jsonEncode(json);
      await prefs.setString(_queueKey, encoded);
      print('[OfflineQueue] Cola guardada: ${_queue.length} items');
    } catch (e) {
      print('[OfflineQueue] Error al guardar cola: $e');
    }
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_queueKey);
      
      if (encoded == null) {
        _queue = [];
        return;
      }
      
      final json = jsonDecode(encoded) as List<dynamic>;
      _queue = json
          .map((item) => PendingListing.fromJson(item as Map<String, dynamic>))
          .toList();
      
      print('[OfflineQueue] Cola cargada: ${_queue.length} items');
    } catch (e) {
      print('[OfflineQueue] Error al cargar cola: $e');
      _queue = [];
    }
  }

  Future<void> clearAll() async {
    _queue.clear();
    await _saveQueue();
    _notifyListeners();
    print('[OfflineQueue] Cola limpiada completamente');
  }

  void dispose() {
    _retryTimer?.cancel();
    _listeners.clear();
    print('[OfflineQueue] Servicio detenido');
  }
}
