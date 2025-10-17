import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:market_app/core/ux/ux_tunning_service.dart';

import '../../data/api/listings_api.dart';
import '../../data/api/catalog_api.dart';
import '../../data/api/images_api.dart';
import '../../data/api/analytics_api.dart'; // ← NUEVO: para dwell
import '../../core/telemetry/telemetry.dart';
import '../../core/ux/ux_hints.dart';

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

  // -------- Data --------
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, String> _brandById = {};
  Map<String, String> _categoryById = {};
  String? _selectedCategoryId;

  // cache fotos
  final Set<String> _expanded = <String>{};
  final Map<String, String> _photoUrlCache = {};

  // -------- UX desde BQs --------
  UxHints _hints = const UxHints();
  int _plainSearches = 0;
  bool _nudgeShown = false;

  // -------- CTAs por tiempo --------
  // Orden dinámico de CTAs basado en dwell por pantalla (endpoint)
  List<String> _ctaPriority = const ['search', 'publish', 'auth']; // fallback
  // Mostrar CTA tras X segundos en esta pestaña (home)
  Timer? _ctaShowTimer;
  bool _ctaReady = false;
  int _homeAvgSeconds = 20; // fallback si endpoint falla
  static const int _ctaMinSeconds = 6;   // límites sanos para no demorar demasiado
  static const int _ctaMaxSeconds = 60;  // ni esperar eternidades

  // “No gracias” con cooldown
  final Map<String, DateTime> _dismissedAt = <String, DateTime>{};
  Timer? _ctaRearmTimer;
  static const Duration _ctaCooldown = Duration(seconds: 90);

  static const _primary = Color(0xFF0F6E5D);
  static const _cardBg = Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _searchCtrl.addListener(_onSearchChanged);
    Telemetry.i.view('home');
    _loadUxHints();
    _loadDwellAndProgramCtas(); // ← carga ranking y programa timer por tiempo
  }

  // ---------- Dwell (endpoint) ----------
  Future<void> _loadDwellAndProgramCtas() async {
    try {
      final data = await AnalyticsApi().bq24DwellByScreenToday(); // GET endpoint
      final list = List<Map<String, dynamic>>.from(data);

      // 1) Ranking de CTAs: mapeo pantalla → CTA, ordenado por avg_seconds desc
      list.sort((a, b) {
        final av = ((a['avg_seconds'] ?? 0) as num).toDouble();
        final bv = ((b['avg_seconds'] ?? 0) as num).toDouble();
        return bv.compareTo(av);
      });

      // Mapea a claves de CTA y quita duplicados manteniendo orden
      final mapped = <String>[];
      for (final e in list) {
        final screen = (e['screen'] ?? '').toString();
        final key = _ctaKeyForScreen(screen);
        if (key != null && !mapped.contains(key)) mapped.add(key);
      }
      if (mapped.isNotEmpty) {
        setState(() => _ctaPriority = mapped);
      }

      // 2) Umbral temporal para mostrar CTA en Home: usa avg_seconds de 'home'
      final homeRow = list.firstWhere(
        (e) => (e['screen'] ?? '') == 'home',
        orElse: () => const {'avg_seconds': 20},
      );
      final avg = ((homeRow['avg_seconds'] ?? 20) as num).toInt();
      _homeAvgSeconds = avg.clamp(_ctaMinSeconds, _ctaMaxSeconds);

      // Programa timer para mostrar CTA tras _homeAvgSeconds
      _scheduleCtaShowTimer();
    } catch (_) {
      // Fallback: sin endpoint, usamos defaults y mostramos tras 20s
      _homeAvgSeconds = 20;
      _scheduleCtaShowTimer();
    }
  }

  String? _ctaKeyForScreen(String screen) {
    switch (screen) {
      case 'home':
        return 'search';     // CTA enfocado a compra/búsqueda
      case 'create_listing':
        return 'publish';    // CTA de publicar
      case 'login':
      case 'register':
        return 'auth';       // CTA de registro/autenticación
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

  // ---------- UX hints (chips, nudge filtros) ----------
  Future<void> _loadUxHints() async {
    try {
      final hints = await UxTuningService.instance.loadHints();
      if (!mounted) return;
      setState(() => _hints = hints);
      _maybeShowFiltersNudge();
    } catch (_) {}
  }

  void _maybeShowFiltersNudge() {
    if (!mounted || _nudgeShown) return;
    if (_hints.autoOpenFiltersAfterNPlainSearches) {
      _nudgeShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tip: usa los filtros para resultados más relevantes.'),
          duration: Duration(seconds: 4),
        ),
      );
      Telemetry.i.click('use_filters_nudge_shown');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctaRearmTimer?.cancel();
    _ctaShowTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------- Bootstrap --------------------
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
      if (mounted) setState(() => _loading = false);
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
    if (!_ctaReady) return null; // ← solo mostrar si ya pasó el tiempo en esta pestaña

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
                        backgroundColor: _primary, foregroundColor: Colors.white,
                      ),
                      child: Text(actionText),
                    ),
                    const SizedBox(width: 8),
                    if (onDismiss != null)
                      TextButton(onPressed: onDismiss, child: const Text('No gracias')),
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
        onRefresh: () async {
          await _bootstrap();
          await _loadUxHints();
          await _loadDwellAndProgramCtas();
        },
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
                      if (dwellCta != null) ...[
                        dwellCta,
                        const SizedBox(height: 12),
                      ],
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

                  final q = _searchCtrl.text.trim();
                  Telemetry.i.searchPerformed(
                    q: q.isEmpty ? null : q,
                    categoryId: _selectedCategoryId,
                    results: _items.length,
                  );

                  if (_selectedCategoryId == null) {
                    _plainSearches++;
                    if (_hints.autoOpenFiltersAfterNPlainSearches &&
                        _plainSearches >= _hints.searchesWithoutFiltersThreshold) {
                      _plainSearches = 0;
                      _maybeShowFiltersNudge();
                      Telemetry.i.click('filters_nudge_after_plain_searches');
                    }
                  } else {
                    _plainSearches = 0;
                  }

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
      onSelected: (isSelected) {
        setState(() => _selectedCategoryId = isSelected ? id : null);
        _applyFilters();

        Telemetry.i.click('filter_category', props: {
          'category_id': id,
          'selected': isSelected,
        });

        if (isSelected && id != null) {
          Telemetry.i.filterUsed(filter: 'category', value: id);
          UxTuningService.instance.recordLocalCategoryUse(id);
        }
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

  Widget _buildListingCard(Map<String, dynamic> it) {
    final id = (it['id'] ?? it['uuid']).toString();
    final centsRaw = it['price_cents'];
    final cents = (centsRaw is int) ? centsRaw : int.tryParse('$centsRaw') ?? 0;
    final priceText = _formatMoney(cents);

    final title = (it['title'] ?? '').toString();
    final brand = (it['brand_name'] ?? it['brand']?['name'] ?? '').toString();
    final cat   = (it['category_name'] ?? it['category']?['name'] ?? '').toString();
    final subtitle = brand.isNotEmpty ? brand : cat;

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
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(priceText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: Offset(0,2))],
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

  String _formatMoney(int cents) {
    final intPart = cents ~/ 100;
    final rem = cents % 100;
    if (rem == 0) return '\$$intPart';
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }
}
