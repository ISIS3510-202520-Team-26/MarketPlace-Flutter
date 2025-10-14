// lib/presentation/home/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/api/listings_api.dart';
import '../../data/api/catalog_api.dart';
import '../../data/api/images_api.dart';
import '../../core/telemetry/telemetry.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // -------- UI state --------
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _err;

  // -------- Data (sin cambios) --------
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, String> _brandById = {};
  Map<String, String> _categoryById = {};
  String? _selectedCategoryId;

  // cache fotos
  final Set<String> _expanded = <String>{};
  final Map<String, String> _photoUrlCache = {};

  static const _primary = Color(0xFF0F6E5D);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _searchCtrl.addListener(_onSearchChanged);
    Telemetry.i.view('home'); // <- Telemetría: pantalla
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------- Bootstrap (igual) --------------------
  Future<void> _bootstrap() async {
    setState(() { _loading = true; _err = null; });

    try {
      final catalog = CatalogApi();
      final futures = await Future.wait([
        catalog.categories(),
        catalog.brands(),
        ListingsApi().list(),
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
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _applyFilters();
      // Telemetría debounced (solo si hay algo que buscar o cambió categoría)
      final q = _searchCtrl.text.trim();
      if (q.isNotEmpty || _selectedCategoryId != null) {
        Telemetry.i.searchPerformed(
          q: q.isEmpty ? null : q,
          categoryId: _selectedCategoryId,
          results: _items.length,
        );
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
      if (!mounted) return;
      setState(() { _photoUrlCache[listingId] = url; });
    } catch (_) {/* placeholder */}
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
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
          _circleIcon(
            icon: Icons.shopping_cart_outlined,
            onTap: () {
              Telemetry.i.click('cart_icon');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart no implementado aún')),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),

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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const SizedBox(height: 4),
                      _buildCategoryChips(),
                      const SizedBox(height: 12),
                      _buildSectionHeader(),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('Sin resultados')),
                        )
                      else
                        _buildGrid(),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Telemetry.i.click('fab_publish');
          context.push('/listings/create');
        },
        label: const Text('Publicar'),
        icon: const Icon(Icons.add),
        backgroundColor: _primary,
      ),
    );
  }

  // ---------- Widgets auxiliares ----------
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
            left: 16, right: 16,
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
                  // Telemetría: submit explícito
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
    final chips = <Widget>[
      _categoryChip(label: 'All categories', id: null, selected: _selectedCategoryId == null),
      for (final c in _categories)
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
      onSelected: (_) {
        setState(() => _selectedCategoryId = id);
        _applyFilters();
        // Telemetría: cambio de categoría
        Telemetry.i.click('filter_category', props: {
          'category_id': id,
          'selected': selected,
        });
      },
      shape: const StadiumBorder(),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _primary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? Colors.transparent : Colors.grey.shade300,
      ),
      selectedColor: _primary,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }

  // ---------- GRID ----------
  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 300,
      ),
      itemBuilder: (context, index) => _buildListingCard(_items[index]),
    );
  }

  // Tarjeta compacta
  Widget _buildListingCard(Map<String, dynamic> it) {
    final id = (it['id'] ?? it['uuid']).toString();

    // precio
    final centsRaw = it['price_cents'];
    final cents = (centsRaw is int) ? centsRaw : int.tryParse('$centsRaw') ?? 0;
    final priceText = _formatMoney(cents);

    // textos
    final title = (it['title'] ?? '').toString();
    final brand = (it['brand_name'] ?? it['brand']?['name'] ?? '').toString();
    final cat   = (it['category_name'] ?? it['category']?['name'] ?? '').toString();
    final subtitle = brand.isNotEmpty ? brand : cat;

    // URLs
    final immediateUrl = _firstPhotoUrl(it);
    final storageKey   = _firstPhotoStorageKey(it);
    final cachedUrl    = _photoUrlCache[id];
    final photoUrl     = immediateUrl ?? cachedUrl;

    if (photoUrl == null && storageKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensurePhotoUrlFor(id, storageKey);
      });
    }

    return InkWell(
      onTap: () {
        Telemetry.i.click('listing_card', listingId: id);
        context.push('/listings/$id');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen cuadrada
            AspectRatio(
              aspectRatio: 1,
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
                Text(
                  priceText,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Telemetry.i.click('add_to_cart', listingId: id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Añadido al carrito (demo)')),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
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
    );
  }

  // -------- utilitario de dinero --------
  String _formatMoney(int cents) {
    final intPart = cents ~/ 100;
    final rem = cents % 100;
    if (rem == 0) return '\$$intPart';
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }
}
