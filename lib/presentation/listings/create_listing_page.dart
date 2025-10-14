import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/api/listings_api.dart';
import '../../data/api/images_api.dart';

class CreateListingPage extends StatefulWidget { const CreateListingPage({super.key}); @override State<CreateListingPage> createState() => _CreateListingPageState(); }
class _CreateListingPageState extends State<CreateListingPage> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  XFile? _picked;
  bool _busy = false; String? _status;

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Listing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
          TextField(controller: _price, decoration: const InputDecoration(labelText: 'Precio (COP)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton(onPressed: _pick, child: const Text('Cámara/Galería')),
            const SizedBox(width: 12),
            if (_picked != null) Text(_picked!.name),
          ]),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Subiendo…' : 'Publicar'),
          ),
          if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!)),
        ]),
      ),
    );
  }

  Future<void> _pick() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (img != null) setState(() => _picked = img);
  }

  Future<void> _submit() async {
    if (_picked == null) return;
    setState(() { _busy = true; _status = 'Creando listing…'; });

    // (Opcional) GPS
    double? lat; double? lon;
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude; lon = pos.longitude;
      }
    } catch (_) {}

    final priceCents = int.tryParse(_price.text.trim()) ?? 0;
    final listing = await ListingsApi().create({
      'title': _title.text.trim(),
      'description': null,
      'category_id': '00000000-0000-0000-0000-000000000000', // Ajusta IDs reales
      'brand_id': null,
      'price_cents': priceCents,
      'currency': 'COP',
      'condition': 'used',
      'quantity': 1,
      'location': (lat != null && lon != null) ? { 'latitude': lat, 'longitude': lon } : null,
      'price_suggestion_used': false,
      'quick_view_enabled': true,
    });

    setState(() { _status = 'Subiendo imagen…'; });

    // 1) Comprimir en memoria
    final original = File(_picked!.path);
    final bytes = await original.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes, minWidth: 1280, minHeight: 1280, quality: 85,
    );

    // 2) Presign + PUT directo a S3
    final imgApi = ImagesApi();
    final (uploadUrl, objectKey) = await imgApi.presign(
      listingId: listing['id'] as String,
      filename: _picked!.name,
      contentType: 'image/jpeg',
    );
    await imgApi.putToPresigned(uploadUrl, compressed, contentType: 'image/jpeg');

    // 3) Confirm
    final preview = await imgApi.confirm(listingId: listing['id'], objectKey: objectKey);

    setState(() { _busy = false; _status = 'Listo ✅'; });
  }
}
