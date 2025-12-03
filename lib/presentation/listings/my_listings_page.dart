import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../../data/repositories/listings_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/models/listing.dart';
import '../../data/models/pending_listing.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/theme_helper.dart';
import '../../core/net/connectivity_service.dart';
import '../../core/services/offline_listing_queue.dart';

/// Página de "Mis Publicaciones"
/// 
/// Muestra todas las publicaciones del usuario autenticado.
/// Similar a HomePage pero filtrada por seller_id del usuario actual.
class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

/// Opciones de ordenamiento para las publicaciones
enum SortOption {
  dateNewest('Más recientes', Icons.schedule),
  dateOldest('Más antiguas', Icons.history),
  alphabeticalAZ('A-Z', Icons.sort_by_alpha),
  alphabeticalZA('Z-A', Icons.sort_by_alpha);

  const SortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Modo de visualización de las publicaciones
enum ViewMode {
  grid('Grid', Icons.grid_view),
  list('Lista', Icons.view_list);

  const ViewMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _MyListingsPageState extends State<MyListingsPage> {
  final _listingsRepo = ListingsRepository();
  final _catalogRepo = CatalogRepository();
  final _offlineQueue = OfflineListingQueue.instance;
  final _connectivity = ConnectivityService.instance;

  bool _loading = true;
  bool _isOnline = true;
  List<Listing> _myListings = [];
  List<PendingListing> _pendingListings = [];
  Map<String, String> _categoryById = {};
  Map<String, String> _brandById = {};
  String? _errorMessage;
  
  // Caché de URLs de imágenes (para storage_key -> URL presignada)
  final Map<String, String> _photoUrlCache = {};
  
  // Timer para verificar conectividad periódicamente
  Timer? _connectivityTimer;
  
  // Estado de ordenamiento y vista (con persistencia)
  SortOption _currentSort = SortOption.dateNewest;
  ViewMode _currentViewMode = ViewMode.grid;
  
  // Keys para SharedPreferences
  static const _sortPrefKey = 'my_listings_sort_preference';
  static const _viewModePrefKey = 'my_listings_view_mode';
  
  // ==================== BÚSQUEDA LOCAL ====================
  
  final _searchController = TextEditingController();
  List<Listing> _filteredListings = [];
  List<PendingListing> _filteredPendingListings = [];
  bool _isSearching = false;
  bool _hasSearchQuery = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    Telemetry.i.view('my_listings_page');
    _loadPreferences(); // Cargar preferencias guardadas
    _checkConnectivity();
    _loadMyListings();
    _loadPendingListings();
    
    // Escuchar cambios en la cola offline
    _offlineQueue.addListener(_onQueueChanged);
    
    // Verificar conectividad periódicamente
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectivity();
    });
  }

  @override
  void dispose() {
    _offlineQueue.removeListener(_onQueueChanged);
    _connectivityTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) {
      setState(() {
        _pendingListings = _offlineQueue.pendingListings
            .where((p) => !p.isCompleted)
            .toList();
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.isOnline;
    if (mounted && _isOnline != isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
      
      // Si recuperamos conexión y hay pendientes, recargar listados
      if (isOnline && _pendingListings.isNotEmpty) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadMyListings();
        });
      }
    }
  }

  void _loadPendingListings() {
    setState(() {
      _pendingListings = _offlineQueue.pendingListings
          .where((p) => !p.isCompleted)
          .toList();
    });
  }

  // ==================== PERSISTENCIA CON SHAREDPREFERENCES ====================

  /// Carga las preferencias guardadas (ordenamiento y vista)
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar ordenamiento guardado
      final sortString = prefs.getString(_sortPrefKey);
      if (sortString != null) {
        final savedSort = SortOption.values.firstWhere(
          (s) => s.name == sortString,
          orElse: () => SortOption.dateNewest,
        );
        _currentSort = savedSort;
        print('[MyListingsPage] 📂 Ordenamiento cargado: ${savedSort.label}');
      }
      
      // Cargar modo de vista guardado
      final viewModeString = prefs.getString(_viewModePrefKey);
      if (viewModeString != null) {
        final savedViewMode = ViewMode.values.firstWhere(
          (v) => v.name == viewModeString,
          orElse: () => ViewMode.grid,
        );
        _currentViewMode = savedViewMode;
        print('[MyListingsPage] 📂 Vista cargada: ${savedViewMode.label}');
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('[MyListingsPage] ⚠️ Error cargando preferencias: $e');
    }
  }

  /// Guarda la preferencia de ordenamiento
  Future<void> _saveSortPreference(SortOption sort) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortPrefKey, sort.name);
      print('[MyListingsPage] 💾 Ordenamiento guardado: ${sort.label}');
    } catch (e) {
      print('[MyListingsPage] ⚠️ Error guardando ordenamiento: $e');
    }
  }

  /// Guarda la preferencia de modo de vista
  Future<void> _saveViewModePreference(ViewMode viewMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewModePrefKey, viewMode.name);
      print('[MyListingsPage] 💾 Vista guardada: ${viewMode.label}');
    } catch (e) {
      print('[MyListingsPage] ⚠️ Error guardando vista: $e');
    }
  }

  /// Aplica el ordenamiento actual a las listas
  void _applySorting() {
    // Ordenar publicaciones activas
    switch (_currentSort) {
      case SortOption.dateNewest:
        _myListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _pendingListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.dateOldest:
        _myListings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _pendingListings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.alphabeticalAZ:
        _myListings.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        _pendingListings.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.alphabeticalZA:
        _myListings.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        _pendingListings.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
    }
  }

  /// Cambia el ordenamiento y reaplica
  void _changeSortOption(SortOption newSort) {
    setState(() {
      _currentSort = newSort;
      _applySorting();
    });
    
    // Guardar preferencia
    _saveSortPreference(newSort);
    
    Telemetry.i.click('my_listings_sort', props: {
      'sort_option': newSort.label,
    });
  }

  /// Cambia el modo de vista
  void _changeViewMode(ViewMode newMode) {
    setState(() {
      _currentViewMode = newMode;
    });
    
    // Guardar preferencia
    _saveViewModePreference(newMode);
    
    Telemetry.i.click('my_listings_view_mode', props: {
      'view_mode': newMode.label,
    });
  }

  // ==================== BÚSQUEDA LOCAL CON FUTURE ====================

  /// Ejecuta la búsqueda local con debouncing
  /// Este es un Future CON handler (maneja estados de carga y errores)
  void _onSearchChanged(String query) {
    // Cancelar búsqueda anterior si existe
    _searchDebounce?.cancel();
    
    // Si la búsqueda está vacía, limpiar filtros inmediatamente
    if (query.trim().isEmpty) {
      setState(() {
        _hasSearchQuery = false;
        _filteredListings = [];
        _filteredPendingListings = [];
      });
      return;
    }
    
    // Debouncing: esperar 300ms antes de buscar
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  /// Realiza la búsqueda local (Future con handler)
  Future<void> _performSearch(String query) async {
    print('[MyListingsPage] 🔍 Buscando: "$query"');
    
    setState(() {
      _isSearching = true;
      _hasSearchQuery = true;
    });
    
    try {
      // Simular un pequeño delay para mostrar el loading
      // (en búsqueda local es casi instantáneo, pero así se ve el estado)
      await Future.delayed(const Duration(milliseconds: 100));
      
      final searchLower = query.toLowerCase().trim();
      
      // Filtrar publicaciones activas
      final filteredActive = _myListings.where((listing) {
        final titleMatch = listing.title.toLowerCase().contains(searchLower);
        final descriptionMatch = listing.description?.toLowerCase().contains(searchLower) ?? false;
        final categoryMatch = _categoryById[listing.categoryId]?.toLowerCase().contains(searchLower) ?? false;
        final brandMatch = listing.brandId != null 
            ? (_brandById[listing.brandId]?.toLowerCase().contains(searchLower) ?? false)
            : false;
        
        return titleMatch || descriptionMatch || categoryMatch || brandMatch;
      }).toList();
      
      // Filtrar publicaciones pendientes
      final filteredPending = _pendingListings.where((pending) {
        final titleMatch = pending.title.toLowerCase().contains(searchLower);
        final descriptionMatch = pending.description?.toLowerCase().contains(searchLower) ?? false;
        final categoryMatch = _categoryById[pending.categoryId]?.toLowerCase().contains(searchLower) ?? false;
        final brandMatch = pending.brandId != null 
            ? (_brandById[pending.brandId]?.toLowerCase().contains(searchLower) ?? false)
            : false;
        
        return titleMatch || descriptionMatch || categoryMatch || brandMatch;
      }).toList();
      
      print('[MyListingsPage] ✅ Encontradas: ${filteredActive.length} activas, ${filteredPending.length} pendientes');
      
      if (mounted) {
        setState(() {
          _filteredListings = filteredActive;
          _filteredPendingListings = filteredPending;
          _isSearching = false;
        });
      }
      
      // Telemetry
      Telemetry.i.click('my_listings_search', props: {
        'query': query,
        'results_count': filteredActive.length + filteredPending.length,
      });
      
    } catch (e) {
      print('[MyListingsPage] ❌ Error en búsqueda: $e');
      
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en búsqueda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Limpia la búsqueda (Future SIN handler - fire and forget)
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _hasSearchQuery = false;
      _filteredListings = [];
      _filteredPendingListings = [];
    });
    
    Telemetry.i.click('my_listings_search_clear');
  }

  Future<void> _loadMyListings() async {
    print('[MyListingsPage] 📦 Cargando mis publicaciones...');
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Verificar conectividad
    final isOnline = await ConnectivityService.instance.isOnline;
    
    if (!isOnline) {
      print('[MyListingsPage] ❌ Sin conexión a internet');
      
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Sin conexión a internet';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Sin conexión a internet'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      // Obtener mis listings y catálogos en paralelo
      final results = await Future.wait([
        _listingsRepo.getMyListings(pageSize: 100),
        _catalogRepo.getCategories(),
        _catalogRepo.getBrands(),
      ]);

      final listingsPage = results[0] as ListingsPage;
      final categories = results[1] as List;
      final brands = results[2] as List;

      // Crear mapas de categorías y marcas
      _categoryById = {
        for (final c in categories) c.id: c.name,
      };
      
      _brandById = {
        for (final b in brands) b.id: b.name,
      };

      print('[MyListingsPage] ✅ ${listingsPage.items.length} publicaciones cargadas');

      if (mounted) {
        setState(() {
          _myListings = listingsPage.items;
          _loading = false;
        });
        
        // Aplicar ordenamiento después de cargar
        _applySorting();
      }
    } catch (e) {
      print('[MyListingsPage] ❌ Error: $e');
      
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: colors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () {
            Telemetry.i.click('my_listings_back');
            context.pop();
          },
        ),
        title: Text(
          'Mis Publicaciones',
          style: TextStyle(
            color: colors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Indicador de estado online/offline (nube)
          if (!_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 12, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          
          // Botón para crear nueva publicación
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colors.primary),
            onPressed: () {
              Telemetry.i.click('my_listings_create_new');
              context.push('/listings/create');
            },
            tooltip: 'Nueva publicación',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? _buildShimmerLoading()
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Campo de búsqueda
                    _buildSearchBar(),
                    
                    // Selector de ordenamiento
                    _buildSortSelector(),
                    
                    // Lista de publicaciones
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await _loadMyListings();
                          _loadPendingListings();
                          await _checkConnectivity();
                        },
                        child: _buildListingsContent(),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Barra de búsqueda
  Widget _buildSearchBar() {
    final colors = context.colors;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Buscar en mis publicaciones...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: _isSearching
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                )
              : Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _hasSearchQuery
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: _clearSearch,
                  tooltip: 'Limpiar búsqueda',
                )
              : null,
        ),
      ),
    );
  }

  /// Selector de ordenamiento y vista
  Widget _buildSortSelector() {
    final colors = context.colors;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Fila de ordenamiento
          Row(
            children: [
              Icon(Icons.filter_list, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Ordenar:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SortOption.values.map((option) {
                      final isSelected = _currentSort == option;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                option.icon,
                                size: 16,
                                color: isSelected ? Colors.white : colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(option.label),
                            ],
                          ),
                          onSelected: (_) => _changeSortOption(option),
                          selectedColor: colors.primary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : colors.primary,
                          ),
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? colors.primary : Colors.grey[300]!,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Fila de modo de vista
          Row(
            children: [
              Icon(Icons.view_module, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Vista:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: ViewMode.values.map((mode) {
                  final isSelected = _currentViewMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mode.icon,
                            size: 16,
                            color: isSelected ? Colors.white : colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(mode.label),
                        ],
                      ),
                      onSelected: (_) => _changeViewMode(mode),
                      selectedColor: colors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : colors.primary,
                      ),
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? colors.primary : Colors.grey[300]!,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Contenido principal: muestra resultados de búsqueda o todas las publicaciones
  Widget _buildListingsContent() {
    // Si hay búsqueda activa, usar listas filtradas
    final displayListings = _hasSearchQuery ? _filteredListings : _myListings;
    final displayPending = _hasSearchQuery ? _filteredPendingListings : _pendingListings;
    
    // Si no hay resultados en búsqueda
    if (_hasSearchQuery && displayListings.isEmpty && displayPending.isEmpty) {
      return _buildNoResultsState();
    }
    
    // Si no hay publicaciones en absoluto
    if (displayListings.isEmpty && displayPending.isEmpty && !_hasSearchQuery) {
      return _buildEmptyState();
    }
    
    // Mostrar publicaciones
    return _buildListingsGrid(displayListings, displayPending);
  }

  /// Grid o Lista de publicaciones (activas + pendientes)
  Widget _buildListingsGrid(List<Listing> listings, List<PendingListing> pending) {
    // Combinar publicaciones activas y pendientes
    final totalItems = pending.length + listings.length;
    
    // Decidir qué vista mostrar
    return _currentViewMode == ViewMode.grid
        ? _buildGridView(totalItems, listings, pending)
        : _buildListView(totalItems, listings, pending);
  }

  /// Vista en Grid (2 columnas)
  Widget _buildGridView(int totalItems, List<Listing> listings, List<PendingListing> pending) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // Primero mostrar publicaciones pendientes
          if (index < pending.length) {
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: 2,
              duration: const Duration(milliseconds: 375),
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: _buildPendingListingCard(pending[index]),
                ),
              ),
            );
          }
          
          // Luego mostrar publicaciones activas
          final listingIndex = index - pending.length;
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 2,
            duration: const Duration(milliseconds: 375),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildListingCard(listings[listingIndex]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Vista en Lista (1 columna)
  Widget _buildListView(int totalItems, List<Listing> listings, List<PendingListing> pending) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // Primero mostrar publicaciones pendientes
          if (index < pending.length) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPendingListingListTile(pending[index]),
                  ),
                ),
              ),
            );
          }
          
          // Luego mostrar publicaciones activas
          final listingIndex = index - pending.length;
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildListingListTile(listings[listingIndex]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Card de publicación individual
  Widget _buildListingCard(Listing listing) {
    final colors = context.colors;
    final categoryName = _categoryById[listing.categoryId] ?? 'Sin categoría';
    final brandName = listing.brandId != null ? _brandById[listing.brandId] : null;
    final price = (listing.priceCents / 100).toStringAsFixed(0);
    
    // Obtener URL de imagen usando el mismo sistema que HomePage
    String? photoUrl;
    String? storageKey;
    
    if (listing.photos != null && listing.photos!.isNotEmpty) {
      final firstPhoto = listing.photos!.first;
      // Intentar obtener URL directa primero
      photoUrl = firstPhoto.imageUrl ?? firstPhoto.previewUrl;
      // Si no hay URL directa, guardar storage_key para obtenerla después
      storageKey = firstPhoto.storageKey;
    }
    
    // Si no tenemos URL directa pero tenemos storage_key, buscar en cache
    if (photoUrl == null && storageKey != null) {
      photoUrl = _photoUrlCache[listing.id];
      
      // Si tampoco está en cache, obtenerla en background
      if (photoUrl == null) {
        // storageKey ya está garantizado como non-null aquí por el if anterior
        final nonNullStorageKey = storageKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensurePhotoUrlFor(listing.id, nonNullStorageKey);
        });
      }
    }

    return GestureDetector(
      onTap: () {
        Telemetry.i.click('my_listing_tap', props: {
          'listing_id': listing.id,
          'title': listing.title,
        });
        context.push('/listings/${listing.id}', extra: listing);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto con Hero animation
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 1,
                child: Hero(
                  tag: 'listing-photo-${listing.id}',
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image_not_supported, 
                              color: Colors.grey[400], size: 40),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image_outlined, 
                            color: Colors.grey[400], size: 40),
                        ),
                ),
              ),
            ),
            
            // Información del producto
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Categoría y marca
                    Text(
                      brandName != null ? '$categoryName • $brandName' : categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Precio y estado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$$price',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: listing.isActive 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            listing.isActive ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: listing.isActive 
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Obtiene y cachea la URL de una imagen usando su storage_key
  /// Similar al sistema usado en HomePage
  Future<void> _ensurePhotoUrlFor(String listingId, String storageKey) async {
    // Si ya está en cache, no hacer nada
    if (_photoUrlCache.containsKey(listingId)) return;
    
    try {
      print('[MyListingsPage] 🖼️ Obteniendo URL para imagen: $storageKey');
      final url = await _listingsRepo.getImagePreviewUrl(storageKey);
      
      if (!mounted) return;
      
      setState(() {
        _photoUrlCache[listingId] = url;
      });
      
      print('[MyListingsPage] ✅ URL cacheada para listing $listingId');
    } catch (e) {
      print('[MyListingsPage] ⚠️ Error obteniendo URL de imagen: $e');
      // No hacer nada, mostrar placeholder
    }
  }

  /// ListTile de publicación individual (vista lista)
  Widget _buildListingListTile(Listing listing) {
    final colors = context.colors;
    final categoryName = _categoryById[listing.categoryId] ?? 'Sin categoría';
    final brandName = listing.brandId != null ? _brandById[listing.brandId] : null;
    final price = (listing.priceCents / 100).toStringAsFixed(0);
    
    // Obtener URL de imagen
    String? photoUrl;
    String? storageKey;
    
    if (listing.photos != null && listing.photos!.isNotEmpty) {
      final firstPhoto = listing.photos!.first;
      photoUrl = firstPhoto.imageUrl ?? firstPhoto.previewUrl;
      storageKey = firstPhoto.storageKey;
    }
    
    if (photoUrl == null && storageKey != null) {
      photoUrl = _photoUrlCache[listing.id];
      
      if (photoUrl == null) {
        final nonNullStorageKey = storageKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensurePhotoUrlFor(listing.id, nonNullStorageKey);
        });
      }
    }

    return GestureDetector(
      onTap: () {
        Telemetry.i.click('my_listing_tap', props: {
          'listing_id': listing.id,
          'title': listing.title,
        });
        context.push('/listings/${listing.id}', extra: listing);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Hero(
                  tag: 'listing-photo-${listing.id}',
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image_not_supported, 
                              color: Colors.grey[400], size: 32),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image_outlined, 
                            color: Colors.grey[400], size: 32),
                        ),
                ),
              ),
            ),
            
            // Información
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Categoría y marca
                    Text(
                      brandName != null ? '$categoryName • $brandName' : categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Precio y estado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$$price',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: listing.isActive 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            listing.isActive ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: listing.isActive 
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ListTile de publicación pendiente (vista lista)
  Widget _buildPendingListingListTile(PendingListing pending) {
    final colors = context.colors;
    final categoryName = _categoryById[pending.categoryId] ?? 'Sin categoría';
    final brandName = pending.brandId != null ? _brandById[pending.brandId] : null;
    final price = (pending.priceCents / 100).toStringAsFixed(0);
    
    // Obtener estado visual
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    if (pending.isUploading) {
      statusText = 'Publicando...';
      statusColor = Colors.blue;
      statusIcon = Icons.cloud_upload;
    } else if (pending.isFailed) {
      statusText = 'Error';
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else {
      statusText = 'Pendiente';
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    }

    return GestureDetector(
      onTap: () => _showPendingListingDialog(pending),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Imagen con overlay
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pending.imageBase64 != null)
                      Image.memory(
                        base64Decode(pending.imageBase64!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image_outlined, 
                              color: Colors.grey[400], size: 32),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image_outlined, 
                          color: Colors.grey[400], size: 32),
                      ),
                    
                    // Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    
                    // Badge de estado
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              statusText,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Información
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    Text(
                      brandName != null ? '$categoryName • $brandName' : categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$$price',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        if (pending.attemptCount > 0)
                          Text(
                            'Intento ${pending.attemptCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de publicación pendiente (en cola de offline)
  Widget _buildPendingListingCard(PendingListing pending) {
    final colors = context.colors;
    final categoryName = _categoryById[pending.categoryId] ?? 'Sin categoría';
    final brandName = pending.brandId != null ? _brandById[pending.brandId] : null;
    final price = (pending.priceCents / 100).toStringAsFixed(0);
    
    // Obtener estado visual
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    if (pending.isUploading) {
      statusText = 'Publicando...';
      statusColor = Colors.blue;
      statusIcon = Icons.cloud_upload;
    } else if (pending.isFailed) {
      statusText = 'Error';
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else {
      statusText = 'Pendiente';
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    }

    return GestureDetector(
      onTap: () {
        // Mostrar diálogo con detalles y opciones
        _showPendingListingDialog(pending);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto o placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Intentar mostrar imagen si existe
                    if (pending.imageBase64 != null)
                      Image.memory(
                        base64Decode(pending.imageBase64!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image_outlined, 
                              color: Colors.grey[400], size: 40),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image_outlined, 
                          color: Colors.grey[400], size: 40),
                      ),
                    
                    // Overlay semi-transparente
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    
                    // Badge de estado en la esquina superior
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Información del producto
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      pending.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Categoría y marca
                    Text(
                      brandName != null ? '$categoryName • $brandName' : categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Precio y número de intentos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$$price',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        if (pending.attemptCount > 0)
                          Text(
                            'Intento ${pending.attemptCount}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo con detalles y opciones de publicación pendiente
  void _showPendingListingDialog(PendingListing pending) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              pending.isUploading
                  ? Icons.cloud_upload
                  : pending.isFailed
                      ? Icons.error_outline
                      : Icons.schedule,
              color: pending.isUploading
                  ? Colors.blue
                  : pending.isFailed
                      ? Colors.red
                      : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pending.title,
                style: const TextStyle(fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado: ${pending.status}'),
            const SizedBox(height: 8),
            Text('Intentos: ${pending.attemptCount}/${PendingListing.maxAttempts}'),
            const SizedBox(height: 8),
            Text('Creado: ${_formatDateTime(pending.createdAt)}'),
            if (pending.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${pending.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              pending.isUploading
                  ? 'Publicando en el servidor...'
                  : pending.isFailed
                      ? 'La publicación falló después de ${pending.attemptCount} intentos. Usa "Reintentar" para intentar nuevamente (se resetearán los intentos a 0).'
                      : 'Esta publicación se subirá automáticamente cuando haya conexión.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (!pending.isUploading) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removePendingListing(pending.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
            if (pending.isFailed || pending.attemptCount > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _retryPendingListing(pending.id);
                },
                child: const Text('Reintentar'),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _removePendingListing(String id) async {
    await _offlineQueue.remove(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación pendiente eliminada')),
      );
    }
  }

  Future<void> _retryPendingListing(String id) async {
    await _offlineQueue.retry(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Reintentando publicar... (contador reseteado a 0)'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diff.inHours < 1) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inDays < 1) {
      return 'Hace ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Estado sin resultados de búsqueda
  Widget _buildNoResultsState() {
    final colors = context.colors;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otras palabras clave',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear),
              label: const Text('Limpiar búsqueda'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado vacío
  Widget _buildEmptyState() {
    final colors = context.colors;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No tienes publicaciones',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¡Comienza a vender tus productos!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Telemetry.i.click('my_listings_empty_create');
                context.push('/listings/create');
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear Publicación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado de error
  Widget _buildErrorState() {
    final colors = context.colors;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Error al cargar publicaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Por favor, intenta de nuevo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMyListings,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Loading con shimmer
  Widget _buildShimmerLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

