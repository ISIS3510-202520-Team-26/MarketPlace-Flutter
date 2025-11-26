import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/listings_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/models/listing.dart';
import '../../data/models/price_suggestion.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/services/image_processing_isolate.dart';
import '../../core/services/offline_listing_queue.dart';
import '../../core/net/connectivity_service.dart';
import '../../core/storage/storage_helper.dart';
import '../../core/theme/theme_helper.dart';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});
  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  // Repositories
  final _listingsRepo = ListingsRepository();
  final _catalogRepo = CatalogRepository();
  
  // Services
  final _offlineQueue = OfflineListingQueue.instance;
  final _connectivity = ConnectivityService.instance;
  final _storage = StorageHelper.instance;

  // UI
  final _title = TextEditingController();
  final _price = TextEditingController();
  XFile? _picked;

  bool _busy = false;
  String? _status;
  String? _err;

  // Ubicación
  bool _useLocation = true;
  bool _locBusy = false;
  double? _lat, _lon;
  String? _locMsg;

  // Cat/Brand
  bool _catsBusy = false, _brandsBusy = false;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  String? _categoryId;
  String? _brandId;

  // Price Suggestion
  PriceSuggestion? _priceSuggestion;
  bool _priceSuggestionApplied = false;
  bool _priceSuggestionBusy = false;
  
  // Telemetry tracking
  DateTime? _formStartTime;
  bool _formCompletedTracked = false;
  bool _hadDraftOnLoad = false;

  @override
  void initState() {
    super.initState();
    _price.addListener(_onPriceChanged);
    _title.addListener(_saveDraftDebounced);
    _price.addListener(_saveDraftDebounced);
    _loadDraft();
    _initLocation();
    _loadCategories();
    Telemetry.i.view('create_listing');
    _formStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _trackFormAbandonmentIfNeeded();
    _price.removeListener(_onPriceChanged);
    _title.removeListener(_saveDraftDebounced);
    _price.removeListener(_saveDraftDebounced);
    _title.dispose();
    _price.dispose();
    super.dispose();
  }
  
  void _trackFormAbandonmentIfNeeded() {
    if (_formCompletedTracked) {
      return;
    }

    final hasTitle = _title.text.trim().isNotEmpty;
    final hasPrice = _price.text.trim().isNotEmpty;
    final hasImage = _picked != null;
    final hasCategory = _categoryId != null;
    final hasBrand = _brandId != null;

    final hasAnyContent = hasTitle || hasPrice || hasImage || hasCategory || hasBrand;

    String formState;
    if (!hasAnyContent) {
      formState = 'empty';
    } else if (hasTitle && hasPrice && hasImage && hasCategory && hasBrand) {
      formState = 'complete';
    } else {
      formState = 'partial';
    }

    final timeSpent = _formStartTime != null
        ? DateTime.now().difference(_formStartTime!).inSeconds
        : null;

    Telemetry.i.formAbandoned(
      formState: formState,
      hasTitle: hasTitle,
      hasPrice: hasPrice,
      hasImage: hasImage,
      hasCategory: hasCategory,
      hasBrand: hasBrand,
      timeSpentSeconds: timeSpent,
    );

    print('[CreateListing] Form abandoned - State: $formState, Time: ${timeSpent}s');
  }
  
  Future<void> _loadDraft() async {
    try {
      final draft = await _storage.loadDraft();
      if (draft == null) {
        _hadDraftOnLoad = false;
        Telemetry.i.formStarted();
        return;
      }
      
      _hadDraftOnLoad = true;
      print('[CreateListing] Cargando borrador guardado...');
      
      if (mounted) {
        setState(() {
          if (draft['title'] != null) _title.text = draft['title'] as String;
          if (draft['price'] != null) _price.text = draft['price'] as String;
          if (draft['categoryId'] != null) _categoryId = draft['categoryId'] as String;
          if (draft['brandId'] != null) _brandId = draft['brandId'] as String;
          if (draft['useLocation'] != null) _useLocation = draft['useLocation'] as bool;
          
          // Cargar imagen guardada
          if (draft['imagePath'] != null) {
            final imagePath = draft['imagePath'] as String;
            final imageFile = File(imagePath);
            if (imageFile.existsSync()) {
              _picked = XFile(imagePath);
              print('[CreateListing] Imagen del borrador cargada: $imagePath');
            } else {
              print('[CreateListing] Imagen del borrador no existe en disco');
            }
          }
        });
        
        print('[CreateListing] Borrador cargado exitosamente');
      }
    } catch (e) {
      print('[CreateListing] Error al cargar borrador: $e');
    }
  }
  
  void _saveDraftDebounced() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _saveDraft();
      }
    });
  }
  
  Future<void> _saveDraft() async {
    try {
      final title = _title.text.trim();
      final price = _price.text.trim();
      
      if (title.isEmpty && price.isEmpty && _picked == null) return;
      
      await _storage.saveDraft(
        title: title,
        price: price,
        categoryId: _categoryId,
        brandId: _brandId,
        imagePath: _picked?.path,
        useLocation: _useLocation,
      );
      
      print('[CreateListing] Borrador guardado automaticamente');
    } catch (e) {
      print('[CreateListing] Error al guardar borrador: $e');
    }
  }
  
  Future<void> _clearDraft() async {
    try {
      await _storage.clearDraft();
      print('[CreateListing] Borrador eliminado');
    } catch (e) {
      print('[CreateListing] Error al eliminar borrador: $e');
    }
  }
  
  Future<void> _resetForm() async {
    try {
      await _clearDraft();
      
      if (mounted) {
        setState(() {
          _title.clear();
          _price.clear();
          _picked = null;
          _categoryId = null;
          _brandId = null;
          _useLocation = true;
          _lat = null;
          _lon = null;
          _locMsg = null;
          _priceSuggestion = null;
          _priceSuggestionApplied = false;
          _err = null;
          _status = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formulario restaurado'),
            duration: Duration(seconds: 2),
          ),
        );
        
        print('[CreateListing] Formulario restaurado a valores por defecto');
      }
    } catch (e) {
      print('[CreateListing] Error al restaurar formulario: $e');
    }
  }

  // ---------- Helpers ----------
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

  String _formatMoney(int cents) {
    final units = cents ~/ 100;
    return '\$${units.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} COP';
  }

  void _onPriceChanged() {
    // Si el usuario edita manualmente el precio, marcamos que no usó la sugerencia
    if (_priceSuggestionApplied) {
      setState(() => _priceSuggestionApplied = false);
    }
  }

  Future<void> _maybeSuggestPrice() async {
    if (_categoryId == null) return;
    
    setState(() {
      _priceSuggestionBusy = true;
      _priceSuggestion = null;
    });

    try {
      final suggestion = await _listingsRepo.suggestPrice(
        categoryId: _categoryId!,
        brandId: _brandId,
      );
      
      if (mounted) {
        setState(() => _priceSuggestion = suggestion);
        if (suggestion != null) {
          Telemetry.i.click('price_suggestion_shown', props: {
            'category_id': _categoryId,
            'brand_id': _brandId,
            'suggested_price_cents': suggestion.suggestedPriceCents,
            'algorithm': suggestion.algorithm,
            'n': suggestion.n,
          });
        }
      }
    } catch (e) {
      print('[CreateListing] Error al obtener sugerencia de precio: $e');
      // No mostramos error al usuario, simplemente no hay sugerencia
    } finally {
      if (mounted) setState(() => _priceSuggestionBusy = false);
    }
  }

  void _usePriceSuggestion() {
    if (_priceSuggestion == null) return;
    
    final units = _priceSuggestion!.suggestedPriceCents ~/ 100;
    _price.text = units.toString();
    
    setState(() => _priceSuggestionApplied = true);
    
    Telemetry.i.click('use_price_suggestion', props: {
      'category_id': _categoryId,
      'brand_id': _brandId,
      'suggested_price_cents': _priceSuggestion!.suggestedPriceCents,
      'algorithm': _priceSuggestion!.algorithm,
    });
  }

  // ---------------------- CARGA CAT/BRAND ----------------------
  Future<void> _loadCategories() async {
    setState(() => _catsBusy = true);
    try {
      final catsModels = await _catalogRepo.getCategories();
      final cats = _uniqById(catsModels.map((c) => {
        'id': c.id,
        'uuid': c.id,
        'name': c.name,
        'slug': c.slug,
      }).toList());
      final ids = cats.map((c) => c['id'] as String).toSet();
      String? selected = _categoryId;
      if (selected == null || !ids.contains(selected)) {
        selected = cats.isNotEmpty ? cats.first['id'] as String : null;
      }
      setState(() {
        _categories = cats;
        _categoryId = selected;
      });
      if (selected != null) {
        await _loadBrandsForCategory(selected);
      } else {
        setState(() {
          _brands = [];
          _brandId = null;
        });
      }
    } catch (e) {
      setState(() => _err = 'No se pudieron cargar categorías: $e');
    } finally {
      if (mounted) setState(() => _catsBusy = false);
    }
  }

  Future<void> _loadBrandsForCategory(String categoryId) async {
    setState(() {
      _brandsBusy = true;
      _brands = [];
      _brandId = null;
    });
    try {
      final brandsModels = await _catalogRepo.getBrands(categoryId: categoryId);
      final bs = _uniqById(brandsModels.map((b) => {
        'id': b.id,
        'uuid': b.id,
        'name': b.name,
        'slug': b.slug,
        'category_id': b.categoryId,
      }).toList());
      final ids = bs.map((b) => b['id'] as String).toSet();
      String? sel = _brandId;
      if (sel == null || !ids.contains(sel)) {
        sel = bs.isNotEmpty ? bs.first['id'] as String : null;
      }
      setState(() {
        _brands = bs;
        _brandId = sel;
      });
      // Sugerir precio cuando cambia la categoría
      await _maybeSuggestPrice();
    } catch (e) {
      setState(() => _err = 'No se pudieron cargar marcas: $e');
    } finally {
      if (mounted) setState(() => _brandsBusy = false);
    }
  }

  // ---------------------- UBICACIÓN ----------------------
  Future<void> _initLocation() async {
    if (!_useLocation) return;
    setState(() { _locBusy = true; _locMsg = 'Obteniendo ubicación…'; });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _locMsg = 'GPS desactivado'); return; }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) { setState(() => _locMsg = 'Permiso denegado permanentemente'); return; }
      if (perm == LocationPermission.denied) { setState(() => _locMsg = 'Permiso denegado'); return; }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) { _lat = last.latitude; _lon = last.longitude; }

      final cur = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 6),
      );
      _lat = cur.latitude; _lon = cur.longitude;
      setState(() => _locMsg = 'Ubicación lista (${_lat?.toStringAsFixed(5)}, ${_lon?.toStringAsFixed(5)})');
    } catch (e) {
      setState(() => _locMsg = 'No se pudo obtener ubicación: $e');
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    final coordsText = (_lat != null && _lon != null)
        ? '(${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)})'
        : '(—, —)';

    // Garantiza value válido en dropdowns
    final catItems = _uniqById(_categories);
    String? catValue = _categoryId;
    if (catValue == null || !catItems.any((c) => c['id'] == catValue)) {
      catValue = catItems.isNotEmpty ? catItems.first['id'] as String : null;
    }

    final brandItems = _uniqById(_brands);
    String? brandValue = _brandId;
    if (brandValue == null || !brandItems.any((b) => b['id'] == brandValue)) {
      brandValue = brandItems.isNotEmpty ? brandItems.first['id'] as String : null;
    }

    final colors = context.colors;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.primary),
        title: Text(
          'Crear Listing',
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restaurar formulario',
            onPressed: _busy ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Restaurar formulario'),
                  content: const Text('Se perderán todos los datos del formulario. ¿Continuar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Restaurar'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await _resetForm();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_err != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_err!, style: const TextStyle(color: Colors.red)),
            ),

          _sectionTitle('Información básica'),
          const SizedBox(height: 8),
          _textField(
            controller: _title,
            label: 'Título',
            hint: 'Ej. MacBook Pro 13” M1',
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _price,
            label: 'Precio (COP)',
            hint: 'Solo números',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          // Price Suggestion UI
          if (_priceSuggestionBusy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_priceSuggestion != null && !_priceSuggestionBusy)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _priceSuggestionApplied ? Colors.green.shade50 : colors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _priceSuggestionApplied ? Colors.green : Colors.grey.shade300,
                  width: _priceSuggestionApplied ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _priceSuggestionApplied ? Icons.check_circle : Icons.lightbulb_outline,
                        color: _priceSuggestionApplied ? Colors.green : colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _priceSuggestionApplied ? 'Sugerencia aplicada' : 'Precio sugerido',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _priceSuggestionApplied ? Colors.green.shade700 : colors.primary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatMoney(_priceSuggestion!.suggestedPriceCents),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  if (_priceSuggestion!.p25 != null && _priceSuggestion!.p75 != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Rango: ${_formatMoney(_priceSuggestion!.p25!)} - ${_formatMoney(_priceSuggestion!.p75!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Basado en ${_priceSuggestion!.n ?? 0} listings (${_priceSuggestion!.source ?? _priceSuggestion!.algorithm})',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (!_priceSuggestionApplied)
                    const SizedBox(height: 12),
                  if (!_priceSuggestionApplied)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _usePriceSuggestion,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Usar sugerencia'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          side: BorderSide(color: colors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          _sectionTitle('Foto'),
          const SizedBox(height: 8),
          Row(
            children: [
              _pillButton(
                icon: Icons.photo_camera_outlined,
                label: 'Agregar Foto',
                onTap: () {
                  Telemetry.i.click('open_image_picker');
                  _showImageSourceDialog();
                },
              ),
              const SizedBox(width: 12),
              if (_picked != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _picked!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          _sectionTitle('Categoría y marca'),
          const SizedBox(height: 8),
          if (_catsBusy) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: catValue,
            items: catItems.map((c) {
              final id = c['id'] as String;
              final name = (c['name'] ?? '').toString();
              return DropdownMenuItem(value: id, child: Text(name));
            }).toList(),
            onChanged: _catsBusy ? null : (v) {
              Telemetry.i.click('change_category', props: {'category_id': v});
              setState(() => _categoryId = v);
              if (v != null) _loadBrandsForCategory(v);
              _saveDraft();
            },
            decoration: _inputDecoration('Categoría').copyWith(
              suffixIcon: IconButton(
                tooltip: 'Crear categoría',
                icon: Icon(Icons.add_circle_outline, color: colors.primary),
                onPressed: _catsBusy ? null : () async {
                  Telemetry.i.click('open_create_category');
                  await _createCategoryDialog();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: _brandsBusy,
            child: Opacity(
              opacity: _brandsBusy ? 0.6 : 1,
              child: DropdownButtonFormField<String>(
                value: brandValue,
                items: brandItems.map((b) {
                  final id = b['id'] as String;
                  final name = (b['name'] ?? '').toString();
                  return DropdownMenuItem(value: id, child: Text(name));
                }).toList(),
                onChanged: (v) {
                  Telemetry.i.click('change_brand', props: {'brand_id': v});
                  setState(() => _brandId = v);
                  _maybeSuggestPrice();
                  _saveDraft();
                },
                decoration: _inputDecoration('Marca').copyWith(
                  suffixIcon: IconButton(
                    tooltip: 'Crear marca',
                    icon: Icon(Icons.add_circle_outline, color: colors.primary),
                    onPressed: _brandsBusy ? null : () async {
                      Telemetry.i.click('open_create_brand');
                      await _createBrandDialog();
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_brandsBusy) const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(minHeight: 3),
          ),

          const SizedBox(height: 20),
          _sectionTitle('Ubicación'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SwitchListTile(
                  value: _useLocation,
                  onChanged: (v) {
                    Telemetry.i.click('toggle_location', props: {'enabled': v});
                    setState(() => _useLocation = v);
                    if (v) _initLocation();
                    _saveDraft();
                  },
                  title: const Text('Adjuntar mi ubicación'),
                  subtitle: _locBusy
                      ? const Text('Obteniendo ubicación…')
                      : Text(_locMsg ?? (_lat != null ? 'Ubicación lista' : 'Sin ubicación')),
                  activeColor: colors.primary,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        coordsText,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _locBusy ? null : () {
                        Telemetry.i.click('refresh_location');
                        _initLocation();
                      },
                      tooltip: 'Reintentar',
                      icon: Icon(Icons.my_location, size: 20, color: colors.primary),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: () {
                          Telemetry.i.click('open_location_settings');
                          Geolocator.openLocationSettings();
                        },
                        child: const Text(
                          'Ajustes de ubicación',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _primaryButton(
            text: _busy ? 'Subiendo…' : 'Publicar',
            onTap: _busy ? null : () {
              Telemetry.i.click('publish');
              _submit();
            },
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_status!, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ---------- UI helpers (solo estilo) ----------
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    final colors = context.colors;
    
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelStyle: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final colors = context.colors;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({required String text, VoidCallback? onTap}) {
    final colors = context.colors;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ---------------------- DIALOGS CREACIÓN ----------------------
  Future<void> _createCategoryDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Nombre de categoría')),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Crear')),
        ],
      ),
    );
    if (ok != true) return;

    final name = ctrl.text.trim();
    if (name.isEmpty) return;

    try {
      setState(() => _catsBusy = true);
      final catModel = await _catalogRepo.createCategory(name: name);
      final cat = {
        'id': catModel.id,
        'uuid': catModel.id,
        'name': catModel.name,
        'slug': catModel.slug,
      };
      final newId = catModel.id;

      final next = _uniqById([..._categories, cat]);
      setState(() {
        _categories = next;
        _categoryId = newId;
      });
      Telemetry.i.click('create_category', props: {'name': name, 'category_id': newId});
      await _loadBrandsForCategory(newId);
    } catch (e) {
      setState(() => _err = 'No se pudo crear la categoría: $e');
    } finally {
      if (mounted) setState(() => _catsBusy = false);
    }
  }

  Future<void> _createBrandDialog() async {
    if (_categories.isEmpty) await _loadCategories();

    String? selectedCat = _categoryId;
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setLocal) => AlertDialog(
            title: const Text('Nueva marca'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'Nombre de marca'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCat ?? (_categories.isNotEmpty ? _categories.first['id'] as String : null),
                  items: _uniqById(_categories).map((cat) {
                    final id = cat['id'] as String;
                    final name = (cat['name'] ?? '').toString();
                    return DropdownMenuItem(value: id, child: Text('Categoría: $name'));
                  }).toList(),
                  onChanged: (v) => setLocal(() => selectedCat = v),
                  decoration: const InputDecoration(labelText: 'Asociar a categoría'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Crear')),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    selectedCat ??= _categoryId ?? (_categories.isNotEmpty ? _categories.first['id'] as String : null);

    final name = nameCtrl.text.trim();
    if (name.isEmpty || selectedCat == null) {
      setState(() => _err = 'Completa nombre y categoría.');
      return;
    }

    try {
      setState(() => _brandsBusy = true);
      final brandModel = await _catalogRepo.createBrand(
        name: name,
        categoryId: selectedCat!,
      );

      if (_categoryId != selectedCat) {
        setState(() => _categoryId = selectedCat);
      }
      await _loadBrandsForCategory(selectedCat!);

      setState(() => _brandId = brandModel.id);
      Telemetry.i.click('create_brand', props: {'name': name, 'brand_id': _brandId, 'category_id': selectedCat});
    } catch (e) {
      setState(() => _err = 'No se pudo crear la marca: $e');
    } finally {
      if (mounted) setState(() => _brandsBusy = false);
    }
  }

  // ---------------------- IMAGE PICKER ----------------------
  Future<void> _showImageSourceDialog() async {
    final colors = context.colors;
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: colors.primary),
              title: const Text('Cámara'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: colors.primary),
              title: const Text('Galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      Telemetry.i.click('pick_image', props: {'source': source == ImageSource.camera ? 'camera' : 'gallery'});
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (img != null) {
      setState(() => _picked = img);
      _saveDraft();
    }
  }

  // ---------------------- SUBMIT ----------------------

  Future<void> _submit() async {
    if (_picked == null) { setState(() => _err = 'Selecciona una imagen.'); return; }
    if (_title.text.trim().isEmpty) { setState(() => _err = 'Escribe un título.'); return; }
    if (_categoryId == null) { setState(() => _err = 'Selecciona o crea una categoría.'); return; }
    if (_brandId == null) { setState(() => _err = 'Selecciona o crea una marca.'); return; }

    setState(() { _busy = true; _status = 'Preparando publicación…'; _err = null; });

    try {
      final units = int.tryParse(_price.text.trim()) ?? 0;
      final priceCents = units * 100;

      // Comprimir imagen primero
      setState(() => _status = 'Comprimiendo imagen en segundo plano…');
      
      final original = File(_picked!.path);
      final bytes = await original.readAsBytes();
      
      print('[CreateListing] Tamaño original: ${bytes.length} bytes');
      
      List<int> compressed;
      try {
        final compressedResult = await ImageProcessingService.instance.compressImageInIsolate(
          imageBytes: bytes,
          quality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        
        if (compressedResult != null && compressedResult.isNotEmpty) {
          compressed = compressedResult;
          print('[CreateListing] Tamaño comprimido: ${compressed.length} bytes');
        } else {
          print('[CreateListing] Compresión falló, usando imagen original');
          compressed = bytes;
        }
      } catch (e) {
        print('[CreateListing] Error al comprimir ($e), usando imagen original');
        compressed = bytes;
      }

      // Verificar conectividad
      final isOnline = await _connectivity.isOnline;

      if (isOnline) {
        print('[CreateListing] Conexión detectada, subiendo directamente...');
        setState(() => _status = 'Subiendo publicación…');
        
        try {
          await _uploadDirectly(
            title: _title.text.trim(),
            categoryId: _categoryId!,
            brandId: _brandId,
            priceCents: priceCents,
            compressed: compressed,
          );
          
          // Éxito - Telemetría y limpieza
          _formCompletedTracked = true;
          final timeSpent = _formStartTime != null
              ? DateTime.now().difference(_formStartTime!).inSeconds
              : null;
          Telemetry.i.formCompleted(
            hadDraft: _hadDraftOnLoad,
            timeSpentSeconds: timeSpent,
          );
          
          await _clearDraft();
          setState(() { _busy = false; _status = 'Listo'; });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Publicación subida exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
          return;
          
        } catch (e) {
          print('[CreateListing] Error al subir directamente: $e');
          print('[CreateListing] Guardando en cola offline...');
          setState(() => _status = 'Error de conexión, guardando para subir después…');
        }
      } else {
        print('[CreateListing] Sin conexión, guardando en cola offline...');
        setState(() => _status = 'Sin conexión, guardando para subir después…');
      }

      // Guardar en cola offline
      final queueId = await _offlineQueue.enqueue(
        title: _title.text.trim(),
        categoryId: _categoryId!,
        brandId: _brandId,
        priceCents: priceCents,
        latitude: _useLocation ? _lat : null,
        longitude: _useLocation ? _lon : null,
        priceSuggestionUsed: _priceSuggestionApplied,
        imageBytes: compressed,
        imageName: _picked!.name,
        imageContentType: 'image/jpeg',
      );

      print('[CreateListing] Publicación guardada en cola: $queueId');

      _formCompletedTracked = true;
      final timeSpent = _formStartTime != null
          ? DateTime.now().difference(_formStartTime!).inSeconds
          : null;
      Telemetry.i.formCompleted(
        hadDraft: _hadDraftOnLoad,
        timeSpentSeconds: timeSpent,
      );

      await _clearDraft();
      setState(() { _busy = false; _status = null; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Publicación guardada. Se subirá automáticamente cuando haya conexión.'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _busy = false; _status = null; _err = 'Error al procesar: $e'; });
    }
  }
  
  Future<void> _uploadDirectly({
    required String title,
    required String categoryId,
    String? brandId,
    required int priceCents,
    required List<int> compressed,
  }) async {
    final newListing = Listing(
      id: '', 
      sellerId: '', 
      title: title,
      description: null,
      categoryId: categoryId,
      brandId: brandId,
      priceCents: priceCents,
      currency: 'COP',
      condition: 'used',
      quantity: 1,
      isActive: true, 
      latitude: _useLocation ? _lat : null,
      longitude: _useLocation ? _lon : null,
      priceSuggestionUsed: _priceSuggestionApplied,
      quickViewEnabled: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final listing = await _listingsRepo.createListing(newListing);
    
    setState(() => _status = 'Subiendo imagen…');

    await _listingsRepo.uploadListingImage(
      listingId: listing.id,
      imageBytes: compressed,
      filename: _picked!.name,
      contentType: 'image/jpeg',
    );
  }
}



