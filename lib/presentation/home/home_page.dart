import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/listings_api.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map> _items = [];
  bool _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ListingsApi().list();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listings'),
        actions: [
          IconButton(
            onPressed: () => context.push('/listings/create'), // ✅ GoRouter
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (c, i) {
                  final it = _items[i];
                  final title = (it['title'] ?? 'Item').toString();
                  final price = ((it['price_cents'] ?? 0) as num) / 100.0;
                  final photos = (it['photos'] as List?)?.cast<Map>() ?? const [];
                  final img = photos.isNotEmpty ? photos.first['image_url'] as String? : null;
                  return ListTile(
                    leading: img != null
                        ? CachedNetworkImage(
                            imageUrl: img,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.image_not_supported),
                    title: Text(title),
                    subtitle: Text('COP ${price.toStringAsFixed(0)}'),
                  );
                },
              ),
      ),
    );
  }
}
