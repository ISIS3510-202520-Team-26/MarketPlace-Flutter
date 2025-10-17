import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/api/listings_api.dart';
import '../../data/api/images_api.dart';
import '../../data/api/catalog_api.dart';
import '../../core/telemetry/telemetry.dart';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});
  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  // UI
  static const _primary = Color(0xFF0F6E5D);
  static const _cardBg = Color(0xFFF7F8FA);

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

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadCategories();
    Telemetry.i.view('create_listing'); // Telemetría: pantalla
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

  // ---------------------- CARGA CAT/BRAND ----------------------
  Future<void> _loadCategories() async {
    setState(() => _catsBusy = true);
    try {
      final cats = _uniqById(await CatalogApi().categories());
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
      final bs = _uniqById(await CatalogApi().brands(categoryId: categoryId));
      final ids = bs.map((b) => b['id'] as String).toSet();
      String? sel = _brandId;
      if (sel == null || !ids.contains(sel)) {
        sel = bs.isNotEmpty ? bs.first['id'] as String : null;
      }
      setState(() {
        _brands = bs;
        _brandId = sel;
      });
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _primary),
        title: const Text(
          'Crear Listing',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
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
          const SizedBox(height: 16),

          _sectionTitle('Foto'),
          const SizedBox(height: 8),
          Row(
            children: [
              _pillButton(
                icon: Icons.photo_camera_outlined,
                label: 'Cámara/Galería',
                onTap: () {
                  Telemetry.i.click('pick_image');
                  _pick();
                },
              ),
              const SizedBox(width: 12),
              if (_picked != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _cardBg,
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
            },
            decoration: _inputDecoration('Categoría').copyWith(
              suffixIcon: IconButton(
                tooltip: 'Crear categoría',
                icon: const Icon(Icons.add_circle_outline, color: _primary),
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
                },
                decoration: _inputDecoration('Marca').copyWith(
                  suffixIcon: IconButton(
                    tooltip: 'Crear marca',
                    icon: const Icon(Icons.add_circle_outline, color: _primary),
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
              color: _cardBg,
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
                  },
                  title: const Text('Adjuntar mi ubicación'),
                  subtitle: _locBusy
                      ? const Text('Obteniendo ubicación…')
                      : Text(_locMsg ?? (_lat != null ? 'Ubicación lista' : 'Sin ubicación')),
                  activeColor: _primary,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(coordsText, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _locBusy ? null : () {
                        Telemetry.i.click('refresh_location');
                        _initLocation();
                      },
                      tooltip: 'Reintentar',
                      icon: const Icon(Icons.my_location, size: 20, color: _primary),
                    ),
                    TextButton(
                      onPressed: () {
                        Telemetry.i.click('open_location_settings');
                        Geolocator.openLocationSettings();
                      },
                      child: const Text('Ajustes de ubicación'),
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
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelStyle: const TextStyle(color: _primary, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.6),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _primary,
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
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
      final cat = await CatalogApi().createCategory(name: name);
      final newId = (cat['id'] ?? cat['uuid']) as String;

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
      final brand = await CatalogApi().createBrand(name: name, categoryId: selectedCat!);

      if (_categoryId != selectedCat) {
        setState(() => _categoryId = selectedCat);
      }
      await _loadBrandsForCategory(selectedCat!);

      setState(() => _brandId = brand['id'] as String);
      Telemetry.i.click('create_brand', props: {'name': name, 'brand_id': _brandId, 'category_id': selectedCat});
    } catch (e) {
      setState(() => _err = 'No se pudo crear la marca: $e');
    } finally {
      if (mounted) setState(() => _brandsBusy = false);
    }
  }

  // ---------------------- SUBMIT ----------------------
  Future<void> _pick() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (img != null) setState(() => _picked = img);
  }

  Future<void> _submit() async {
    if (_picked == null) { setState(() => _err = 'Selecciona una imagen.'); return; }
    if (_title.text.trim().isEmpty) { setState(() => _err = 'Escribe un título.'); return; }
    if (_categoryId == null) { setState(() => _err = 'Selecciona o crea una categoría.'); return; }
    if (_brandId == null) { setState(() => _err = 'Selecciona o crea una marca.'); return; }

    setState(() { _busy = true; _status = 'Creando listing…'; _err = null; });

    try {
      final units = int.tryParse(_price.text.trim()) ?? 0;
      final priceCents = units * 100;

      final payload = <String, dynamic>{
        'title': _title.text.trim(),
        'description': null,
        'category_id': _categoryId,
        'brand_id': _brandId,
        'price_cents': priceCents,
        'currency': 'COP',
        'condition': 'used',
        'quantity': 1,
        if (_useLocation && _lat != null && _lon != null) 'latitude': _lat,
        if (_useLocation && _lat != null && _lon != null) 'longitude': _lon,
        'price_suggestion_used': false,
        'quick_view_enabled': true,
      };

      final listing = await ListingsApi().create(payload);

      setState(() => _status = 'Comprimiendo imagen…');

      final original = File(_picked!.path);
      final bytes = await original.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes, minWidth: 1280, minHeight: 1280, quality: 85, format: CompressFormat.jpeg,
      );

      setState(() => _status = 'Subiendo imagen…');

      final imgApi = ImagesApi();
      final (uploadUrl, objectKey) = await imgApi.presign(
        listingId: listing['id'] as String,
        filename: _picked!.name,
        contentType: 'image/jpeg',
      );
      await imgApi.putToPresigned(uploadUrl, compressed, contentType: 'image/jpeg');
      await imgApi.confirm(listingId: listing['id'], objectKey: objectKey);

      setState(() { _busy = false; _status = 'Listo ✅'; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing publicado')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _busy = false; _status = null; _err = 'Error al publicar: $e'; });
    }
  }
}
