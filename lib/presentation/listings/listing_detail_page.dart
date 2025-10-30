import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/listings_repository.dart';

class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, this.listing, this.listingId});
  final Listing? listing;
  final String? listingId;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  final _repo = ListingsRepository();
  Listing? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      _data = widget.listing ?? await _repo.getListingById(widget.listingId!);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(int cents, String cur) =>
      NumberFormat.simpleCurrency(name: cur).format(cents / 100);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Hero(
                        tag: 'listing-photo-${_data!.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _data!.photos?.isNotEmpty == true
                              ? Image.network(
                                  _data!.photos!.first.imageUrl ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Center(child: Icon(Icons.broken_image_outlined)),
                                )
                              : Container(
                                  color: cs.surfaceVariant,
                                  child: const Center(child: Icon(Icons.image_not_supported_outlined)),
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
                    _MetaRow(icon: Icons.sell_outlined, label: 'Marca', value: _data!.brandId  ?? '—'),
                    _MetaRow(icon: Icons.category_outlined, label: 'Categoría', value: _data!.categoryId ?? '—'),
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
