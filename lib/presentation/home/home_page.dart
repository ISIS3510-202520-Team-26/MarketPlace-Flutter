import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:market_app/core/ux/ux_tunning_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:dio/dio.dart';

import '../../data/repositories/listings_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/telemetry_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/ux/ux_hints.dart';
import '../../core/storage/storage.dart';
import '../../core/net/connectivity_service.dart';
import '../../core/analytics/category_analytics.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/preload_service.dart';
import '../../core/theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // -------- Repositories --------
  final _listingsRepo = ListingsRepository();
  final _catalogRepo = CatalogRepository();
  final _telemetryRepo = TelemetryRepository();
  final _authRepo = AuthRepository();

  // -------- Storage Services --------
  final _storage = StorageHelper.instance;
  final _cartService = CartService.instance;
  
  // -------- Analytics (BQ1) --------
  final _analytics = CategoryAnalytics.instance;
  DateTime? _categoryViewStartTime;

  // -------- UI state --------
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;

  // -------- Data --------
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, String> _brandById = {};
  Map<String, String> _categoryById = {};
  String? _selectedCategoryId;

  // -------- Filtros de ubicación --------
  bool _useLocationFilter = false;
  bool _loadingLocation = false;
  double? _userLat;
  double? _userLon;
  double _radiusKm = 5.0; // Radio por defecto
  String? _locationError;

  // cache fotos
  final Map<String, String> _photoUrlCache = {};

  // -------- UX desde BQs --------
  UxHints _hints = const UxHints();

  // -------- CTAs por tiempo --------
  List<String> _ctaPriority = const ['search', 'publish', 'auth']; // fallback
  Timer? _ctaShowTimer;
  bool _ctaReady = false;
  int _homeAvgSeconds = 20; // fallback si endpoint falla
  static const int _ctaMinSeconds = 6;
  static const int _ctaMaxSeconds = 60;

  // “No gracias” con cooldown
  final Map<String, DateTime> _dismissedAt = <String, DateTime>{};
  Timer? _ctaRearmTimer;
  static const Duration _ctaCooldown = Duration(seconds: 90);

  static const _primary = Color(0xFF0F6E5D);
  static const _cardBg = Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _bootstrap();
    _searchCtrl.addListener(_onSearchChanged);
    Telemetry.i.view('home');
    _loadUxHints();
    _loadDwellAndProgramCtas();
    _cartService.initialize(); // Inicializar carrito
    _cartService.addListener(_onCartChanged); // Escuchar cambios del carrito
    _cacheUserProfileInBackground(); // Cachear perfil en segundo plano
    _listenToDataUpdates(); // Escuchar actualizaciones mediante Stream
  }
  
  void _onCartChanged() {
    if (mounted) setState(() {}); // Actualizar UI cuando cambie el carrito
  }
  
  /// Escucha actualizaciones de datos mediante Stream del PreloadService
  /// 
  /// Cuando el PreloadService sincroniza datos en segundo plano (cada 30s),
  /// este Stream recibe notificaciones y actualiza la UI automáticamente.
  void _listenToDataUpdates() {
    final preloadService = PreloadService.instance;
    preloadService.dataUpdateStream.listen((event) {
      if (!mounted) return;
      
      // Solo recargar si es actualización de listings o general
      if (event.type == DataUpdateType.listings || event.type == DataUpdateType.all) {
        print('[HomePage] 📡 Stream recibido: ${event.type} - Recargando datos...');
        _bootstrap();
      }
    });
  }

  /// Cachea el perfil del usuario en segundo plano
  /// 
  /// Se ejecuta silenciosamente sin afectar la UI. Si hay error, no se muestra
  /// al usuario ya que el perfil se intentará cargar directamente al abrir ProfilePage.
  Future<void> _cacheUserProfileInBackground() async {
    try {
      print('[HomePage] 📥 Descargando perfil en segundo plano...');
      
      // Verificar si ya hay un perfil cacheado válido
      final hasCachedProfile = await _storage.hasCachedUserProfile();
      if (hasCachedProfile) {
        print('[HomePage] ✅ Perfil ya cacheado, verificando si necesita actualización...');
        
        // Opcional: Verificar antigüedad del cache
        final cacheTimestamp = await _storage.getProfileCacheTimestamp();
        if (cacheTimestamp != null) {
          final age = DateTime.now().difference(cacheTimestamp);
          if (age.inHours < 24) {
            print('[HomePage] ⏭️ Cache reciente (${age.inHours}h), omitiendo descarga');
            return; // Cache es reciente, no descargar
          }
        }
      }
      
      // Descargar perfil del backend
      final user = await _authRepo.getCurrentUser();
      
      // Guardar en cache usando toFullJson()
      await _storage.cacheUserProfile(user.toFullJson());
      
      print('[HomePage] 💾 Perfil cacheado exitosamente en segundo plano');
    } catch (e) {
      // Error silencioso - no afectar experiencia del usuario
      print('[HomePage] ⚠️ Error al cachear perfil (silencioso): $e');
      // No mostrar error al usuario, ProfilePage manejará el caso
    }
  }

  // Cargar preferencias del usuario al iniciar
  Future<void> _loadUserPreferences() async {
    final prefs = await _storage.getDefaultFilters();
    setState(() {
      _useLocationFilter = prefs.locationEnabled;
      _radiusKm = prefs.radius ?? 5.0;
    });
  }

  // ---------- Dwell (endpoint) ----------
  Future<void> _loadDwellAndProgramCtas() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final data = await _telemetryRepo.getTimeByScreen(
        start: startOfDay,
        end: now,
      );
      final list = data.map((t) => {
            'screen': t.screen,
            'avg_seconds': t.avgSeconds,
          }).toList();

      list.sort((a, b) {
        final av = ((a['avg_seconds'] ?? 0) as num).toDouble();
        final bv = ((b['avg_seconds'] ?? 0) as num).toDouble();
        return bv.compareTo(av);
      });

      final mapped = <String>[];
      for (final e in list) {
        final screen = (e['screen'] ?? '').toString();
        final key = _ctaKeyForScreen(screen);
        if (key != null && !mapped.contains(key)) mapped.add(key);
      }
      if (mapped.isNotEmpty) {
        setState(() => _ctaPriority = mapped);
      }

      final homeRow = list.firstWhere(
        (e) => (e['screen'] ?? '') == 'home',
        orElse: () => const {'avg_seconds': 20},
      );
      final avg = ((homeRow['avg_seconds'] ?? 20) as num).toInt();
      _homeAvgSeconds = avg.clamp(_ctaMinSeconds, _ctaMaxSeconds);

      _scheduleCtaShowTimer();
    } catch (_) {
      _homeAvgSeconds = 20;
      _scheduleCtaShowTimer();
    }
  }

  String? _ctaKeyForScreen(String screen) {
    switch (screen) {
      case 'home':
        return 'search';
      case 'create_listing':
        return 'publish';
      case 'login':
      case 'register':
        return 'auth';
      default:
        return null;
    }
  }

  void _scheduleCtaShowTimer() {
    _ctaShowTimer?.cancel();
    _ctaReady = false;
    final seconds = _homeAvgSeconds.clamp(_ctaMinSeconds, _ctaMaxSeconds);
    Telemetry.i.click('cta_timer_started', props: {'screen': 'home', 'seconds': seconds});
    _ctaShowTimer = Timer(Duration(seconds: seconds), () {
      _ctaReady = true;
      Telemetry.i.click('cta_timer_fired', props: {'screen': 'home'});
      if (mounted) setState(() {});
    });
  }

  // ---------- UX hints ----------
  Future<void> _loadUxHints() async {
    try {
      final hints = await UxTuningService.instance.loadHints();
      if (!mounted) return;
      setState(() => _hints = hints);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctaRearmTimer?.cancel();
    _ctaShowTimer?.cancel();
    _searchCtrl.dispose();
    _cartService.removeListener(_onCartChanged); // Remover listener del carrito
    super.dispose();
  }

  // -------------------- Bootstrap --------------------
  Future<void> _bootstrap() async {
    // PASO 1: Cargar cache primero (si existe) y mostrarlo INMEDIATAMENTE
    print('[HomePage] 📦 Intentando cargar cache...');
    var cachedCategories = await _storage.getCachedCategories();
    var cachedListings = await _storage.getCachedListings();
    
    print('[HomePage] Cache categorías: ${cachedCategories?.length ?? 0}');
    print('[HomePage] Cache listados: ${cachedListings?.length ?? 0}');
    
    final hasCache = cachedCategories != null && 
                     cachedListings != null && 
                     cachedCategories.isNotEmpty && 
                     cachedListings.isNotEmpty;
    
    print('[HomePage] ¿Tiene cache válido? $hasCache');
    
    if (hasCache) {
      // Tenemos cache, mostrarlo INMEDIATAMENTE antes de verificar internet
      print('[HomePage] ✅ Mostrando cache inmediatamente...');
      _categories = _uniqById(cachedCategories);
      _categoryById = {
        for (final c in _categories) (c['id'] as String): (c['name'] ?? '').toString(),
      };
      
      _all = cachedListings.map((it) => _augmentListing(it)).toList();
      _applyFilters();
      
      // Mostrar la UI con los datos del cache
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      
      // Precargar detalles de los listings del cache en segundo plano
      // (se actualizarán más tarde si hay internet)
      _preloadListingDetailsFromCache();
    } else {
      // No hay cache, mostrar loading
      print('[HomePage] ⏳ No hay cache, mostrando loading...');
      if (mounted) {
        setState(() {
          _loading = true;
        });
      }
    }

    // PASO 2: Verificar conectividad
    final isOnline = await ConnectivityService.instance.isOnline;

    // PASO 3: Si no hay internet
    if (!isOnline) {
      print('[HomePage] ❌ Sin conexión a internet');
      
      if (mounted) {
        // SIEMPRE mostrar notificación de sin conexión
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasCache 
                      ? 'Sin conexión. Mostrando datos guardados anteriormente.'
                      : 'Sin conexión a internet. Por favor, verifica tu conexión.',
                  ),
                ),
              ],
            ),
            backgroundColor: hasCache ? Colors.orange : Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        
        // Si no hay cache, simplemente mostramos lista vacía con mensaje amigable
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    // PASO 4: Hay internet, intentar cargar datos frescos
    try {
      // Si no teníamos cache, mostrar loading
      if (!hasCache && mounted) {
        setState(() => _loading = true);
      }

      // Hay internet, llamar API
      final ListingsPage listingsPage;

      if (_useLocationFilter && _userLat != null && _userLon != null) {
        listingsPage = await _listingsRepo.searchListings(
          pageSize: 200,
          nearLat: _userLat,
          nearLon: _userLon,
          radiusKm: _radiusKm,
        );
      } else {
        listingsPage = await _listingsRepo.searchListings(pageSize: 200);
      }

      final futures = await Future.wait([
        _catalogRepo.getCategories(),
        _catalogRepo.getBrands(),
      ]);

      final cats = (futures[0] as List).map((c) => {
            'id': c.id,
            'uuid': c.id,
            'name': c.name,
            'slug': c.slug,
          }).toList();

      final brands = (futures[1] as List).map((b) => {
            'id': b.id,
            'uuid': b.id,
            'name': b.name,
            'slug': b.slug,
            'category_id': b.categoryId,
          }).toList();

      // Convertir Listing objects a JSON completo (con todos los campos)
      final listings = listingsPage.items.map((l) {
        // Usar toUpdateJson() que incluye todos los campos necesarios
        final json = <String, dynamic>{
          'id': l.id,
          'uuid': l.id,
          'seller_id': l.sellerId,
          'title': l.title,
          'description': l.description,
          'price_cents': l.priceCents,
          'currency': l.currency,
          'category_id': l.categoryId,
          'brand_id': l.brandId,
          'condition': l.condition,
          'quantity': l.quantity,
          'is_active': l.isActive,
          'latitude': l.latitude,
          'longitude': l.longitude,
          'price_suggestion_used': l.priceSuggestionUsed,
          'quick_view_enabled': l.quickViewEnabled,
          'created_at': l.createdAt.toIso8601String(),
          'updated_at': l.updatedAt.toIso8601String(),
          'photos': l.photos?.map((p) => {
                'id': p.id,
                'listing_id': p.listingId,
                'storage_key': p.storageKey,
                'image_url': p.imageUrl,
                'width': p.width,
                'height': p.height,
                'created_at': p.createdAt.toIso8601String(),
              }).toList() ?? [],
        };
        return json;
      }).toList();

      _categories = _uniqById(cats);
      _categoryById = {
        for (final c in _categories) (c['id'] as String): (c['name'] ?? '').toString(),
      };

      _brandById = {
        for (final b in _uniqById(brands)) (b['id'] as String): (b['name'] ?? '').toString(),
      };

      // Cachear categorías (24 horas)
      print('[HomePage] 💾 Guardando categorías en cache...');
      await _storage.cacheCategories(_categories);

      // Cachear listados SIEMPRE (15 minutos) - incluso con filtro de ubicación
      // para que el usuario pueda ver algo si pierde conexión
      print('[HomePage] 💾 Guardando ${listings.length} listados en cache...');
      await _storage.cacheListings(listings);
      print('[HomePage] ✅ Cache guardado correctamente');

      _all = listings.map((it) => _augmentListing(it)).toList();
      _applyFilters();
      
      // Precargar detalles de listings para modo offline
      _preloadListingDetails();
      
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      print('[HomePage] ⚠️ Error al cargar de API: $e');
      
      // Error al cargar de API
      if (mounted) {
        if (hasCache) {
          // Ya mostramos el cache antes, solo notificar el error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Error al actualizar datos. Mostrando datos guardados.'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            _loading = false;
          });
        } else {
          // No hay cache ni datos, mostrar notificación pero NO pantalla de error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('No se pudo cargar los datos. Verifica tu conexión.'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Reintentar',
                textColor: Colors.white,
                onPressed: () => _bootstrap(),
              ),
            ),
          );
          setState(() {
            _loading = false;
          });
        }
      }
    }
  }

  Map<String, dynamic> _augmentListing(Map<String, dynamic> it) {
    final m = Map<String, dynamic>.from(it);
    final brandId = (m['brand_id'] ?? m['brandId'])?.toString();
    final catId = (m['category_id'] ?? m['categoryId'])?.toString();

    m['brand_name'] = m['brand_name'] ?? m['brand']?['name'] ?? (brandId != null ? _brandById[brandId] : null);
    m['category_name'] =
        m['category_name'] ?? m['category']?['name'] ?? (catId != null ? _categoryById[catId] : null);

    return m;
  }

  /// Precarga los detalles desde el caché local (sin URLs presignadas nuevas)
  /// 
  /// Se ejecuta cuando mostramos datos del caché para tener los detalles disponibles offline.
  /// No intenta obtener URLs presignadas nuevas, usa lo que ya está en el caché.
  Future<void> _preloadListingDetailsFromCache() async {
    try {
      print('[HomePage] 🔄 Preparando detalles desde caché...');
      print('[HomePage] Total de listings a cachear: ${_all.length}');
      
      final detailsToCache = <Map<String, dynamic>>[];
      
      for (final listing in _all) {
        final listingId = (listing['id'] ?? listing['uuid'])?.toString();
        if (listingId == null) {
          print('[HomePage] ⚠️ Listing sin ID, saltando...');
          continue;
        }
        
        final detailData = Map<String, dynamic>.from(listing);
        
        // Agregar nombres legibles de marca y categoría
        final brandId = (listing['brand_id'] ?? listing['brandId'])?.toString();
        final categoryId = (listing['category_id'] ?? listing['categoryId'])?.toString();
        
        detailData['cached_brand_name'] = brandId != null ? _brandById[brandId] : null;
        detailData['cached_category_name'] = categoryId != null ? _categoryById[categoryId] : null;
        
        // Usar imageUrl si está disponible (no intentar obtener presignadas)
        String? imageUrl;
        final photos = listing['photos'] as List<dynamic>?;
        if (photos != null && photos.isNotEmpty) {
          final firstPhoto = photos.first as Map<String, dynamic>;
          imageUrl = firstPhoto['image_url']?.toString();
        }
        
        detailData['cached_image_url'] = imageUrl;
        detailsToCache.add(detailData);
      }
      
      if (detailsToCache.isNotEmpty) {
        print('[HomePage] 💾 Guardando ${detailsToCache.length} detalles en caché...');
        await _storage.cacheMultipleListingDetails(detailsToCache);
        print('[HomePage] ✅ Detalles preparados desde caché: ${detailsToCache.length} listings');
      } else {
        print('[HomePage] ⚠️ No hay detalles para cachear');
      }
    } catch (e) {
      print('[HomePage] ⚠️ Error preparando detalles desde caché: $e');
      print('[HomePage] Stack trace: ${StackTrace.current}');
    }
  }

  /// Precarga los detalles de todos los listings visibles en Home
  /// 
  /// Este método se ejecuta en segundo plano después de cargar los listings.
  /// Cachea los detalles completos (incluyendo URLs de imágenes presignadas)
  /// para que funcionen offline cuando el usuario entre a la vista de detalle.
  Future<void> _preloadListingDetails() async {
    try {
      print('[HomePage] 🔄 Iniciando precarga de detalles de listings...');
      print('[HomePage] Total de listings a precachear: ${_all.length}');
      
      final detailsToCache = <Map<String, dynamic>>[];
      
      // Procesar cada listing visible
      for (final listing in _all) {
        final listingId = (listing['id'] ?? listing['uuid'])?.toString();
        if (listingId == null) {
          print('[HomePage] ⚠️ Listing sin ID, saltando...');
          continue;
        }
        
        // Preparar datos completos del listing
        final detailData = Map<String, dynamic>.from(listing);
        
        // Agregar nombres legibles de marca y categoría
        final brandId = (listing['brand_id'] ?? listing['brandId'])?.toString();
        final categoryId = (listing['category_id'] ?? listing['categoryId'])?.toString();
        
        detailData['cached_brand_name'] = brandId != null ? _brandById[brandId] : null;
        detailData['cached_category_name'] = categoryId != null ? _categoryById[categoryId] : null;
        
        // Intentar obtener y cachear la imagen como base64
        String? cachedImage;
        final photos = listing['photos'] as List<dynamic>?;
        
        if (photos != null && photos.isNotEmpty) {
          final firstPhoto = photos.first as Map<String, dynamic>;
          String? imageUrl;
          
          // Si ya tiene imageUrl, usarla
          if (firstPhoto['image_url'] != null && firstPhoto['image_url'].toString().isNotEmpty) {
            imageUrl = firstPhoto['image_url'].toString();
          } 
          // Si tiene storageKey, obtener URL presignada
          else if (firstPhoto['storage_key'] != null && firstPhoto['storage_key'].toString().isNotEmpty) {
            try {
              imageUrl = await _listingsRepo.getImagePreviewUrl(
                firstPhoto['storage_key'].toString(),
              );
            } catch (e) {
              print('[HomePage] ⚠️ Error obteniendo URL para listing $listingId: $e');
            }
          }
          
          // Descargar la imagen y convertirla a base64 para cache offline
          if (imageUrl != null) {
            try {
              final dio = Dio();
              final response = await dio.get<List<int>>(
                imageUrl,
                options: Options(responseType: ResponseType.bytes),
              );
              
              if (response.statusCode == 200 && response.data != null) {
                final base64String = base64Encode(response.data!);
                cachedImage = 'cached_image:$base64String';
                print('[HomePage] 🖼️ Imagen descargada y cacheada para listing $listingId');
              }
            } catch (e) {
              print('[HomePage] ⚠️ Error descargando imagen para listing $listingId: $e');
              // Si falla la descarga, guardar la URL como fallback
              cachedImage = imageUrl;
            }
          }
        }
        
        detailData['cached_image_url'] = cachedImage;
        detailsToCache.add(detailData);
      }
      
      // Cachear todos los detalles de una vez
      if (detailsToCache.isNotEmpty) {
        print('[HomePage] 💾 Guardando ${detailsToCache.length} detalles con URLs presignadas...');
        await _storage.cacheMultipleListingDetails(detailsToCache);
        print('[HomePage] ✅ Precarga completada: ${detailsToCache.length} listings cacheados');
      } else {
        print('[HomePage] ⚠️ No hay detalles para precachear');
      }
    } catch (e) {
      print('[HomePage] ⚠️ Error en precarga de detalles: $e');
      print('[HomePage] Stack trace: ${StackTrace.current}');
      // No interrumpir la experiencia del usuario si falla la precarga
    }
  }

  List<Map<String, dynamic>> _uniqById(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final m in list) {
      final id = (m['id'] ?? m['uuid'])?.toString();
      if (id == null) continue;
      if (seen.add(id)) out.add(m);
    }
    return out;
  }

  // -------------------- Ubicación --------------------
  Future<void> _getUserLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'GPS desactivado');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Permiso denegado permanentemente');
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() => _locationError = 'Permiso denegado');
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _userLat = lastKnown.latitude;
        _userLon = lastKnown.longitude;
        if (mounted) setState(() {});
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      _userLat = position.latitude;
      _userLon = position.longitude;

      print('[HomePage] Ubicación obtenida: $_userLat, $_userLon');

      Telemetry.i.click('location_obtained', props: {
        'lat': _userLat,
        'lon': _userLon,
      });
    } catch (e) {
      _locationError = 'No se pudo obtener ubicación: $e';
      print('[HomePage] Error obteniendo ubicación: $e');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _toggleLocationFilter(bool enabled) async {
    if (enabled && _userLat == null) {
      await _getUserLocation();
      if (_userLat == null) {
        setState(() => _useLocationFilter = false);
        if (mounted && _locationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_locationError!)),
          );
        }
        return;
      }
    }

    setState(() => _useLocationFilter = enabled);

    // Guardar preferencia de ubicación
    await UserPreferencesService.instance.setLocationEnabled(enabled);

    Telemetry.i.click('location_filter_toggle', props: {
      'enabled': enabled,
      'radius_km': _radiusKm,
    });

    await _bootstrap();
  }

  // -------------------- Search & Filters --------------------
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _applyFilters();
      final q = _searchCtrl.text.trim();
      if (q.isNotEmpty || _selectedCategoryId != null) {
        Telemetry.i.searchPerformed(
          q: q.isEmpty ? null : q,
          categoryId: _selectedCategoryId,
          results: _items.length,
        );
        
        // Guardar búsqueda en historial si no está vacía
        if (q.isNotEmpty) {
          _storage.recordSearch(q);
        }
      }
    });
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final cat = _selectedCategoryId;

    List<Map<String, dynamic>> cur = _all;

    if (cat != null) {
      cur = cur.where((it) {
        final cid = (it['category_id'] ?? it['categoryId'])?.toString();
        return cid == cat;
      }).toList();
    }

    if (q.isNotEmpty) {
      cur = cur.where((it) {
        final title = (it['title'] ?? '').toString().toLowerCase();
        final brand = (it['brand_name'] ?? it['brand']?['name'] ?? '').toString().toLowerCase();
        final catn = (it['category_name'] ?? it['category']?['name'] ?? '').toString().toLowerCase();
        return title.contains(q) || brand.contains(q) || catn.contains(q);
      }).toList();
    }

    setState(() => _items = cur);
  }

  // -------------------- Foto helpers --------------------
  String? _firstPhotoUrl(Map<String, dynamic> it) {
    final photos = it['photos'] as List<dynamic>?;
    if (photos == null || photos.isEmpty) return null;
    final p = (photos.first as Map);
    return (p['image_url'] ?? p['preview_url'])?.toString();
    // Nota: en tu DTO de photo usas imageUrl; aquí soportamos ambas claves.
  }

  String? _firstPhotoStorageKey(Map<String, dynamic> it) {
    final photos = it['photos'] as List<dynamic>?;
    if (photos == null || photos.isEmpty) return null;
    final p = (photos.first as Map);
    return p['storage_key']?.toString();
  }

  Future<void> _ensurePhotoUrlFor(String listingId, String objectKey) async {
    if (_photoUrlCache.containsKey(listingId)) return;
    try {
      final url = await _listingsRepo.getImagePreviewUrl(objectKey);
      if (!mounted) return;
      setState(() {
        _photoUrlCache[listingId] = url;
      });
    } catch (_) {/* placeholder */}
  }

  // -------------------- UX helpers (BQs) --------------------
  List<Map<String, dynamic>> _sortedCategories() {
    if (_hints.recommendedCategoryIds.isEmpty) return _categories;

    final idOrder = _hints.recommendedCategoryIds;
    final idx = {for (int i = 0; i < idOrder.length; i++) idOrder[i]: i};

    final list = _categories.toList();
    list.sort((a, b) {
      final aid = (a['id'] ?? a['uuid']).toString();
      final bid = (b['id'] ?? b['uuid']).toString();
      final ai = idx[aid];
      final bi = idx[bid];

      if (ai != null && bi != null) return ai.compareTo(bi);
      if (ai != null) return -1;
      if (bi != null) return 1;

      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      return an.compareTo(bn);
    });
    return list;
  }

  bool _isDismissedActive(String key) {
    final t = _dismissedAt[key];
    if (t == null) return false;
    return DateTime.now().isBefore(t.add(_ctaCooldown));
  }

  String? _nextCtaKey() {
    for (final k in _ctaPriority) {
      if (!_isDismissedActive(k)) return k;
    }
    return null;
  }

  void _dismissCta(String key) {
    setState(() {
      _dismissedAt[key] = DateTime.now();
    });
    Telemetry.i.click('cta_dismiss', props: {'key': key, 'screen': 'home'});
    _scheduleCtaRearm();
  }

  void _scheduleCtaRearm() {
    _ctaRearmTimer?.cancel();
    if (_dismissedAt.isEmpty) return;

    final now = DateTime.now();
    final expirations = _dismissedAt.values
        .map((t) => t.add(_ctaCooldown))
        .where((e) => e.isAfter(now))
        .toList();

    if (expirations.isEmpty) {
      _dismissedAt.removeWhere((_, t) => !now.isBefore(t.add(_ctaCooldown)));
      if (mounted) setState(() {});
      return;
    }

    expirations.sort((a, b) => a.compareTo(b));
    final delay = expirations.first.difference(now);
    _ctaRearmTimer = Timer(delay, () {
      final now2 = DateTime.now();
      _dismissedAt.removeWhere((_, t) => !now2.isBefore(t.add(_ctaCooldown)));
      if (mounted) {
        Telemetry.i.click('cta_rearmed', props: {'screen': 'home'});
        setState(() {});
      }
      _scheduleCtaRearm();
    });
  }

  Widget? _buildDwellCta() {
    if (!_ctaReady) return null;

    final key = _nextCtaKey();
    if (key == null) return null;

    switch (key) {
      case 'search':
        return _ctaCard(
          icon: Icons.search,
          title: '¿Buscas algo en específico?',
          subtitle: 'Usa la búsqueda para encontrarlo más rápido.',
          actionText: 'Buscar',
          onTap: () {
            Telemetry.i.click('cta_search_from_dwell');
            _openSearchSheet();
          },
          onDismiss: () => _dismissCta(key),
        );
      case 'publish':
        return _ctaCard(
          icon: Icons.add_circle_outline,
          title: '¿Quieres vender algo hoy?',
          subtitle: 'Muchos usuarios están publicando – súmate ahora.',
          actionText: 'Publicar',
          onTap: () {
            Telemetry.i.click('cta_publish_from_dwell');
            context.push('/listings/create');
          },
          onDismiss: () => _dismissCta(key),
        );
      case 'auth':
        return _ctaCard(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Crea tu cuenta en 1 minuto',
          subtitle: 'Registrarte te permite publicar y chatear con compradores.',
          actionText: 'Crear cuenta',
          onTap: () {
            Telemetry.i.click('cta_register_from_dwell');
            context.push('/register');
          },
          onDismiss: () => _dismissCta(key),
        );
      default:
        return null;
    }
  }

  Widget _ctaCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onTap,
    VoidCallback? onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(actionText),
                    ),
                    const SizedBox(width: 8),
                    if (onDismiss != null) TextButton(onPressed: onDismiss, child: const Text('No gracias')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final dwellCta = _buildDwellCta();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Home',
          style: TextStyle(
            color: _primary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          _circleIcon(icon: Icons.search, onTap: () {
            Telemetry.i.click('open_search');
            _openSearchSheet();
          }),
          const SizedBox(width: 8),
          _buildCartIcon(),
          const SizedBox(width: 8),
          _circleIcon(
            icon: Icons.person_outline,
            onTap: () {
              Telemetry.i.click('profile_icon');
              context.push('/profile');
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidar cache antes de recargar
          await _storage.invalidateListingsCache();
          await _bootstrap();
          await _loadUxHints();
          await _loadDwellAndProgramCtas();
        },
        child: _loading
            ? _buildShimmerLoading()
            : ListView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: _loading ? 0 : 80, // Espacio para FAB solo cuando no está cargando
                    ),
                    children: [
                      const SizedBox(height: 4),
                      if (dwellCta != null) ...[
                        dwellCta,
                        const SizedBox(height: 12),
                      ],
                      _buildCategoryAnalytics(),
                      const SizedBox(height: 12),
                      _buildCategoryChips(),
                      const SizedBox(height: 12),
                      _buildLocationFilter(),
                      const SizedBox(height: 12),
                      _buildSectionHeader(),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No hay productos disponibles',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Verifica tu conexión a internet e intenta nuevamente',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _bootstrap,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      else
                        _buildGrid(),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
      floatingActionButton: _loading ? null : Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppTheme.elevatedShadow,
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Telemetry.i.click('fab_publish');
            context.push('/listings/create');
          },
          label: const Text(
            'Publicar',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          icon: const Icon(Icons.add, size: 22),
          backgroundColor: AppTheme.primary,
          elevation: 0,
        ),
      ),
    );
  }

  // ---------- Widgets auxiliares ----------
  Widget _buildCartIcon() {
    final itemCount = _cartService.totalItems;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Telemetry.i.click('cart_icon');
              context.push('/cart');
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined, color: _primary, size: 20),
            ),
          ),
          if (itemCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  itemCount > 99 ? '99+' : '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleIcon({required IconData icon, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
      ),
    );
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por título, marca o categoría…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  _applyFilters();

                  final q = _searchCtrl.text.trim();
                  Telemetry.i.searchPerformed(
                    q: q.isEmpty ? null : q,
                    categoryId: _selectedCategoryId,
                    results: _items.length,
                  );

                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: _useLocationFilter ? Border.all(color: _primary, width: 1.5) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _useLocationFilter ? Icons.location_on : Icons.location_off,
                color: _useLocationFilter ? _primary : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buscar cerca de mí',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _useLocationFilter ? _primary : Colors.black87,
                      ),
                    ),
                    if (_useLocationFilter && _userLat != null && _userLon != null)
                      Text(
                        'Radio: ${_radiusKm.toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      )
                    else if (_loadingLocation)
                      Text(
                        'Obteniendo ubicación...',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      )
                    else if (_locationError != null)
                      const Text(
                        'No se pudo obtener ubicación',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                  ],
                ),
              ),
              if (_loadingLocation)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: _useLocationFilter,
                  onChanged: _loadingLocation ? null : _toggleLocationFilter,
                  activeColor: _primary,
                ),
            ],
          ),
          if (_useLocationFilter && _userLat != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Radio:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Slider(
                    value: _radiusKm,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    label: '${_radiusKm.toStringAsFixed(1)} km',
                    activeColor: _primary,
                    onChanged: (value) {
                      setState(() => _radiusKm = value);
                    },
                    onChangeEnd: (value) async {
                      Telemetry.i.click('location_radius_changed', props: {'radius_km': value});
                      // Guardar radio como preferencia
                      await UserPreferencesService.instance.setDefaultRadius(value);
                      _bootstrap();
                    },
                  ),
                ),
                Text(
                  '${_radiusKm.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Popular Product',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            Telemetry.i.click('filter');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Filter no implementado aún')),
            );
          },
          child: Text(
            'Filter',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final ordered = _sortedCategories();

    final chips = <Widget>[
      _categoryChip(label: 'All categories', id: null, selected: _selectedCategoryId == null),
      for (final c in ordered)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _categoryChip(
            label: (c['name'] ?? '').toString(),
            id: c['id'] as String,
            selected: _selectedCategoryId == c['id'],
          ),
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  Widget _categoryChip({required String label, String? id, required bool selected}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (isSelected) async {
        // Guardar el tiempo de visualización de la categoría anterior
        if (_categoryViewStartTime != null && _selectedCategoryId != null) {
          final duration = DateTime.now().difference(_categoryViewStartTime!).inSeconds;
          if (duration > 0) {
            final prevCategoryName = _categoryById[_selectedCategoryId!] ?? 'Unknown';
            
            // [BQ1] Registrar tiempo de visualización en analytics local
            await _analytics.recordCategoryViewDuration(
              _selectedCategoryId!,
              prevCategoryName,
              duration,
            );
            
            // [BQ1] Enviar a telemetría para análisis agregado
            Telemetry.i.categoryViewed(
              categoryId: _selectedCategoryId!,
              categoryName: prevCategoryName,
              durationSeconds: duration,
              itemsViewed: _items.length,
            );
          }
        }
        
        setState(() => _selectedCategoryId = isSelected ? id : null);
        _applyFilters();

        Telemetry.i.click('filter_category', props: {'category_id': id, 'selected': isSelected});

        if (isSelected && id != null) {
          // [BQ1] Registrar clic en categoría en analytics local
          await _analytics.recordCategoryClick(id, label);
          
          // [BQ1] Enviar a telemetría para análisis agregado
          Telemetry.i.categoryClicked(
            categoryId: id,
            categoryName: label,
            source: 'home_chips',
          );
          
          // Marcar inicio de visualización de esta categoría
          _categoryViewStartTime = DateTime.now();
          
          Telemetry.i.filterUsed(filter: 'category', value: id);
          UxTuningService.instance.recordLocalCategoryUse(id);
        } else {
          // Usuario deseleccionó la categoría
          _categoryViewStartTime = null;
        }
      },
      shape: const StadiumBorder(),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _primary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? Colors.transparent : Colors.grey.shade300),
      selectedColor: _primary,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }

  // ---------- GRID ----------
  Widget _buildGrid() {
    return AnimationLimiter(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 300,
        ),
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              scale: 0.5,
              child: FadeInAnimation(
                child: _buildListingCard(_items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> it) {
    final id = (it['id'] ?? it['uuid']).toString();
    final centsRaw = it['price_cents'];
    final cents = (centsRaw is int) ? centsRaw : int.tryParse('$centsRaw') ?? 0;
    final priceText = _formatMoney(cents);

    final title = (it['title'] ?? '').toString();
    final brand = (it['brand_name'] ?? it['brand']?['name'] ?? '').toString();
    final cat = (it['category_name'] ?? it['category']?['name'] ?? '').toString();
    final subtitle = brand.isNotEmpty ? brand : cat;

    final immediateUrl = _firstPhotoUrl(it);
    final storageKey = _firstPhotoStorageKey(it);
    final cachedUrl = _photoUrlCache[id];
    final photoUrl = immediateUrl ?? cachedUrl;

    if (photoUrl == null && storageKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensurePhotoUrlFor(id, storageKey);
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          onTap: () {
            Telemetry.i.click('listing_card', listingId: id);
            context.push('/listings/$id');
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Hero(
                tag: 'listing-photo-$id',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, _) => Container(color: Colors.grey.shade200),
                          errorWidget: (c, _, __) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported_outlined),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, size: 40, color: Colors.white),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(priceText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    Telemetry.i.click('add_to_cart', listingId: id);
                    
                    await _cartService.addItem(
                      listingId: id,
                      title: title,
                      priceCents: cents,
                      currency: 'COP',
                      imageUrl: photoUrl,
                      sellerId: (it['seller_id'] ?? it['sellerId'])?.toString(),
                    );
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$title añadido al carrito'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Ver carrito',
                            onPressed: () {
                              context.push('/cart');
                            },
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.add, size: 18, color: _primary),
                  ),
                ),
              ],
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  String _formatMoney(int cents) {
    final intPart = cents ~/ 100;
    final rem = cents % 100;
    if (rem == 0) return '\$$intPart';
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  /// [BQ1] Business Question: "¿Qué categorías son más populares?"
  /// Widget que muestra las estadísticas de las categorías más clicadas
  Widget _buildCategoryAnalytics() {
    return FutureBuilder<List<CategoryStats>>(
      future: _analytics.getTopCategories(limit: 3),
      builder: (context, snapshot) {
        // No mostrar nada si aún no hay datos
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final topCategories = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary.withOpacity(0.05), _primary.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primary.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tus categorías favoritas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'BQ1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...topCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final stat = entry.value;
                
                return Padding(
                  padding: EdgeInsets.only(bottom: index < topCategories.length - 1 ? 8 : 0),
                  child: InkWell(
                    onTap: () async {
                      // Seleccionar esta categoría
                      setState(() => _selectedCategoryId = stat.categoryId);
                      _applyFilters();
                      
                      // Registrar el clic
                      await _analytics.recordCategoryClick(stat.categoryId, stat.categoryName);
                      Telemetry.i.categoryClicked(
                        categoryId: stat.categoryId,
                        categoryName: stat.categoryName,
                        source: 'favorites_widget',
                      );
                      
                      _categoryViewStartTime = DateTime.now();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedCategoryId == stat.categoryId 
                          ? _primary.withOpacity(0.1)
                          : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedCategoryId == stat.categoryId
                            ? _primary
                            : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Ranking medal
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: index == 0
                                  ? Colors.amber
                                  : index == 1
                                      ? Colors.grey[400]
                                      : Colors.brown[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Category name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat.categoryName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${stat.clicks} ${stat.clicks == 1 ? 'clic' : 'clics'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Stats
                          if (stat.averageViewSeconds > 0) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                const SizedBox(height: 2),
                                Text(
                                  '${stat.averageViewSeconds.toStringAsFixed(0)}s',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              // Footer con información adicional
              FutureBuilder<int>(
                future: _analytics.getTotalCategoriesExplored(),
                builder: (context, countSnapshot) {
                  if (!countSnapshot.hasData) return const SizedBox.shrink();
                  
                  return Row(
                    children: [
                      Icon(Icons.explore, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Has explorado ${countSnapshot.data} ${countSnapshot.data == 1 ? 'categoría' : 'categorías'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== Shimmer Loading ====================
  
  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Category chips shimmer
        _buildShimmerChips(),
        const SizedBox(height: 20),
        
        // Grid shimmer
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 6,
          itemBuilder: (context, index) => _buildShimmerCard(),
        ),
        const SizedBox(height: 24), // Espacio adicional al final
      ],
    );
  }

  Widget _buildShimmerChips() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              width: 80,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
