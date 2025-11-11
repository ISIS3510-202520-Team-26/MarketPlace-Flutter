import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/listings_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../core/storage/storage.dart';

class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, this.listing, this.listingId});
  final Listing? listing;
  final String? listingId;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  final _repo = ListingsRepository();
  final _catalogRepo = CatalogRepository();
  final _storage = StorageHelper.instance;
  Listing? _data;
  bool _loading = true;
  String? _error;
  
  // Nombres legibles de marca y categoría
  String? _brandName;
  String? _categoryName;
  
  // URL de la imagen principal (obtenida si es necesario)
  String? _mainImageUrl;

  @override
  void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    // PASO 1: Intentar cargar desde caché primero (para modo offline)
    if (widget.listingId != null) {
      final cached = await _loadFromCache(widget.listingId!);
      if (cached) {
        print('[ListingDetail] ✅ Cargado desde caché');
        // Si cargamos desde caché, aún intentamos actualizar en segundo plano
        _updateInBackground();
        return;
      } else {
        print('[ListingDetail] ⚠️ No hay datos en caché para listing ${widget.listingId}');
      }
    }
    
    // PASO 2: Si no hay caché, intentar cargar desde la red
    try {
      _data = widget.listing ?? await _repo.getListingById(widget.listingId!);
      
      // Cargar nombres de marca y categoría
      await _loadBrandAndCategoryNames();
      
      // Cargar URL de imagen principal si es necesario
      await _loadMainImageUrl();
      
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      print('[ListingDetail] ❌ Error cargando desde red: $e');
      
      // Si falla la carga desde red y no había caché, mostrar error amigable
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el producto.\n\n'
              'Verifica tu conexión a internet o vuelve a Home para que se descarguen los productos.';
          _loading = false;
        });
      }
    }
  }
  
  /// Intenta cargar el listing desde el caché
  /// 
  /// Retorna true si se cargó exitosamente desde caché
  Future<bool> _loadFromCache(String listingId) async {
    try {
      print('[ListingDetail] 🔍 Buscando en caché: listing_detail_$listingId');
      
      final cachedDetail = await _storage.getCachedListingDetail(listingId);
      
      if (cachedDetail == null) {
        print('[ListingDetail] ❌ No encontrado en caché');
        return false;
      }
      
      print('[ListingDetail] ✅ Encontrado en caché, reconstruyendo...');
      print('[ListingDetail] Datos del caché: ${cachedDetail.keys.join(", ")}');
      
      // Reconstruir el objeto Listing desde el caché
      try {
        _data = Listing.fromJson(cachedDetail);
        print('[ListingDetail] ✅ Listing reconstruido exitosamente');
      } catch (e) {
        print('[ListingDetail] ❌ Error reconstruyendo Listing: $e');
        return false;
      }
      
      // Usar los nombres cacheados si están disponibles
      _brandName = cachedDetail['cached_brand_name']?.toString();
      _categoryName = cachedDetail['cached_category_name']?.toString();
      _mainImageUrl = cachedDetail['cached_image_url']?.toString();
      
      print('[ListingDetail] 📦 Nombres cacheados - Marca: $_brandName, Categoría: $_categoryName');
      print('[ListingDetail] 🖼️ URL de imagen: ${_mainImageUrl != null ? "Disponible" : "No disponible"}');
      
      if (mounted) setState(() => _loading = false);
      
      return true;
    } catch (e) {
      print('[ListingDetail] ⚠️ Error general cargando desde caché: $e');
      return false;
    }
  }
  
  /// Actualiza los datos en segundo plano sin bloquear la UI
  /// 
  /// Se ejecuta después de mostrar datos del caché para actualizar silenciosamente
  Future<void> _updateInBackground() async {
    try {
      if (widget.listingId == null) return;
      
      // Cargar datos frescos del servidor
      final freshData = await _repo.getListingById(widget.listingId!);
      
      // Solo actualizar si aún estamos montados
      if (!mounted) return;
      
      _data = freshData;
      
      // Actualizar nombres y URL de imagen
      await _loadBrandAndCategoryNames();
      await _loadMainImageUrl();
      
      if (mounted) setState(() {});
      
      print('[ListingDetail] ✅ Datos actualizados en segundo plano');
    } catch (e) {
      print('[ListingDetail] ⚠️ Error actualizando en segundo plano: $e');
      // No mostrar error al usuario, ya tiene los datos del caché
    }
  }
  
  /// Carga la URL de la imagen principal
  Future<void> _loadMainImageUrl() async {
    if (_data?.photos == null || _data!.photos!.isEmpty) return;
    
    final firstPhoto = _data!.photos!.first;
    
    // Si ya tiene imageUrl, usarla directamente
    if (firstPhoto.imageUrl != null && firstPhoto.imageUrl!.isNotEmpty) {
      _mainImageUrl = firstPhoto.imageUrl;
      if (mounted) setState(() {});
      return;
    }
    
    // Si no tiene imageUrl pero tiene storageKey, obtener URL presignada
    if (firstPhoto.storageKey.isNotEmpty) {
      try {
        _mainImageUrl = await _repo.getImagePreviewUrl(firstPhoto.storageKey);
        if (mounted) setState(() {});
      } catch (e) {
        print('[ListingDetail] Error obteniendo URL de imagen: $e');
      }
    }
  }
  
  /// Carga los nombres legibles de marca y categoría desde el catálogo
  Future<void> _loadBrandAndCategoryNames() async {
    if (_data == null) return;
    
    try {
      // Cargar categorías y buscar la correspondiente
      final categories = await _catalogRepo.getCategories();
      final category = categories.firstWhere(
        (c) => c.id == _data!.categoryId,
        orElse: () => throw 'Categoría no encontrada',
      );
      _categoryName = category.name;
      
      // Cargar marcas y buscar la correspondiente (si existe)
      if (_data!.brandId != null) {
        final brands = await _catalogRepo.getBrands();
        final brand = brands.where((b) => b.id == _data!.brandId).firstOrNull;
        _brandName = brand?.name;
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      print('[ListingDetail] Error cargando nombres: $e');
      // No lanzar error, solo usar IDs como fallback
    }
  }

  String _money(int cents, String cur) =>
      NumberFormat.simpleCurrency(name: cur).format(cents / 100);

  /// Widget para mostrar la imagen con manejo de errores
  /// Ahora soporta tanto URLs (con conexión) como imágenes cacheadas (bytes en base64)
  Widget _buildImage(String url, ColorScheme cs) {
    if (url.isEmpty) {
      return Container(
        color: cs.surfaceVariant,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    // Si es una imagen cacheada (base64), mostrarla directamente
    if (url.startsWith('cached_image:')) {
      try {
        final base64String = url.replaceFirst('cached_image:', '');
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('[ListingDetail] Error mostrando imagen cacheada: $error');
            return Container(
              color: cs.surfaceVariant,
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
            );
          },
        );
      } catch (e) {
        print('[ListingDetail] Error decodificando imagen cacheada: $e');
        return Container(
          color: cs.surfaceVariant,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.grey,
            ),
          ),
        );
      }
    }
    
    // Si es una URL normal, cargarla desde la red
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: cs.surfaceVariant,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('[ListingDetail] Error cargando imagen desde red: $error');
        return Container(
          color: cs.surfaceVariant,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'Error al cargar imagen',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Error de conexión',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: tt.bodyMedium?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Volver a Home'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Hero(
                        tag: 'listing-photo-${_data!.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _mainImageUrl != null
                              ? _buildImage(_mainImageUrl!, cs)
                              : Container(
                                  color: cs.surfaceVariant,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_data!.title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_money(_data!.priceCents, _data!.currency),
                        style: tt.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _MetaRow(
                      icon: Icons.sell_outlined, 
                      label: 'Marca', 
                      value: _brandName ?? _data!.brandId ?? '—',
                    ),
                    _MetaRow(
                      icon: Icons.category_outlined, 
                      label: 'Categoría', 
                      value: _categoryName ?? _data!.categoryId,
                    ),
                    _MetaRow(icon: Icons.inventory_2_outlined, label: 'Condición', value: _data!.condition ?? '—'),
                    if (_data!.latitude != null && _data!.longitude != null)
                      _MetaRow(
                        icon: Icons.location_on_outlined,
                        label: 'Ubicación',
                        value:
                            '${_data!.latitude!.toStringAsFixed(5)}, ${_data!.longitude!.toStringAsFixed(5)}',
                      ),
                    const SizedBox(height: 12),
                    Text('Descripción', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text((_data!.description ?? '').trim().isNotEmpty
                        ? _data!.description!.trim()
                        : 'Sin descripción.', style: tt.bodyMedium),
                    const SizedBox(height: 80),
                  ],
                ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {/* TODO: carrito/chat */},
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Agregar'),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 18), const SizedBox(width: 8),
        Text('$label: ', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: t.bodyMedium)),
      ]),
    );
  }
}
