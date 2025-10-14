import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/api/listings_api.dart';
import '../../data/api/catalog_api.dart';
import '../../data/api/images_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // UI state
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _err;

  // Data
  List<Map<String, dynamic>> _all = [];      // todos los listings
  List<Map<String, dynamic>> _items = [];    // filtrados
  List<Map<String, dynamic>> _categories = [];
  Map<String, String> _brandById = {};       // id -> nombre
  Map<String, String> _categoryById = {};    // id -> nombre
  String? _selectedCategoryId;               // null = Todas

  // Expanded state + cache de fotos
  final Set<String> _expanded = <String>{};
  final Map<String, String> _photoUrlCache = {}; // listingId -> photoUrl

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------- Bootstrap --------------------
  Future<void> _bootstrap() async {
    setState(() { _loading = true; _err = null; });

    try {
      // Cargar catálogo (categorías y marcas) en paralelo
      final catalog = CatalogApi();
      final futures = await Future.wait([
        catalog.categories(),
        catalog.brands(), // todas las marcas (para resolver nombres)
        ListingsApi().list(), // todos los listings
      ]);

      final cats = List<Map<String, dynamic>>.from(futures[0] as List);
      final brands = List<Map<String, dynamic>>.from(futures[1] as List);
      final listings = List<Map<String, dynamic>>.from(futures[2] as List);

      _categories = _uniqById(cats);
      _categoryById = {
        for (final c in _categories)
          (c['id'] as String): (c['name'] ?? '').toString(),
      };

      _brandById = {
        for (final b in _uniqById(brands))
          (b['id'] as String): (b['name'] ?? '').toString(),
      };

      _all = listings.map((it) => _augmentListing(it)).toList();
      _applyFilters();
    } catch (e) {
      _err = '$e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Map<String, dynamic> _augmentListing(Map<String, dynamic> it) {
    final m = Map<String, dynamic>.from(it);
    // Resuelve nombres si vienen solo los IDs
    final brandId = (m['brand_id'] ?? m['brandId'])?.toString();
    final catId   = (m['category_id'] ?? m['categoryId'])?.toString();

    m['brand_name'] = m['brand_name'] ??
        m['brand']?['name'] ??
        (brandId != null ? _brandById[brandId] : null);

    m['category_name'] = m['category_name'] ??
        m['category']?['name'] ??
        (catId != null ? _categoryById[catId] : null);

    return m;
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

  // -------------------- Search & Filters --------------------
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _applyFilters);
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
        final catn  = (it['category_name'] ?? it['category']?['name'] ?? '').toString().toLowerCase();
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
      final url = await ImagesApi().preview(objectKey);
      setState(() {
        _photoUrlCache[listingId] = url;
      });
    } catch (_) {
      // Silencioso; dejamos el placeholder
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      body: RefreshIndicator(
        onRefresh: () async { await _bootstrap(); },
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _err != null
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_err!, style: const TextStyle(color: Colors.red)),
                    )
                  ])
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 8),
                      _buildCategoryChips(),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Sin resultados')),
                        ),
                      ..._items.map(_buildListingCard),
                      const SizedBox(height: 80),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/listings/create'),
        label: const Text('Publicar'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar por título, marca o categoría…',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _applyFilters(),
    );
  }

  Widget _buildCategoryChips() {
    final chips = <Widget>[
      ChoiceChip(
        label: const Text('Todas'),
        selected: _selectedCategoryId == null,
        onSelected: (_) {
          setState(() => _selectedCategoryId = null);
          _applyFilters();
        },
      ),
      for (final c in _categories)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ChoiceChip(
            label: Text((c['name'] ?? '').toString()),
            selected: _selectedCategoryId == c['id'],
            onSelected: (_) {
              setState(() => _selectedCategoryId = c['id'] as String);
              _applyFilters();
            },
          ),
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> it) {
    final id = (it['id'] ?? it['uuid']).toString();
    final expanded = _expanded.contains(id);

    // precio
    final cents = (it['price_cents'] ?? 0) as int;
    final price = cents ~/ 100;

    // textos
    final title = (it['title'] ?? '').toString();
    final brand = (it['brand_name'] ?? it['brand']?['name'] ?? '').toString();
    final cat   = (it['category_name'] ?? it['category']?['name'] ?? '').toString();

    // URLs
    final immediateUrl = _firstPhotoUrl(it);
    final storageKey   = _firstPhotoStorageKey(it);
    final cachedUrl    = _photoUrlCache[id];
    final photoUrl     = immediateUrl ?? cachedUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () async {
          setState(() {
            if (expanded) {
              _expanded.remove(id);
            } else {
              _expanded.add(id);
            }
          });
          // Si se expandió y no tenemos url pero sí storage_key, pide preview
          if (!expanded && photoUrl == null && storageKey != null) {
            await _ensurePhotoUrlFor(id, storageKey);
          }
        },
        child: AnimatedCrossFade(
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          firstChild: ListTile(
            title: Text(title),
            subtitle: Text(brand.isNotEmpty ? '$brand · $cat' : cat),
            trailing: Text('\$ $price', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(brand.isNotEmpty ? '$brand · $cat' : cat),
                trailing: Text('\$ $price', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: (photoUrl != null)
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (c, _) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (c, _, __) => const Center(child: Icon(Icons.image_not_supported_outlined)),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 48),
                      ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: Colors.grey.shade700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (it['description'] != null && (it['description'] as String).trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(it['description']),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.sell_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text('Condición: ${it['condition'] ?? '—'}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text('Cantidad: ${it['quantity'] ?? 1}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
