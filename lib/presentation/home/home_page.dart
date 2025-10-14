import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/listings_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  String? _err;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final res = await ListingsApi().list(); // asume GET /listings
      setState(() => _items = List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _err != null
                ? ListView(children: [Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_err!, style: const TextStyle(color: Colors.red)),
                  )])
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      final title = (it['title'] ?? '').toString();

                      // 👇 price_cents (int) → pesos (int)
                      final cents = (it['price_cents'] ?? 0) as int;
                      final price = cents ~/ 100;

                      return ListTile(
                        title: Text(title),
                        subtitle: Text('\$ $price'),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/listings/create'),
        label: const Text('Publicar'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
