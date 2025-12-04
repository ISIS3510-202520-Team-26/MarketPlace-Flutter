import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/hive_repository.dart';
import '../../core/net/connectivity_service.dart';

// ============================================================================
// ✨✨✨ SP4 NUEVA VISTA 3/4: FAVORITES PAGE ✨✨✨
// ============================================================================
// 🎯 IMPLEMENTACIONES SP4:
// 
// 📦 PREFERENCES/KEYCHAIN (Hive):
//    - Persistencia de favoritos en Hive key-value storage
//    - Similar a UserDefaults (iOS) / SharedPreferences (Android)
//    - Lectura/escritura ultra-rápida O(1)
//
// 🖼️ NETWORK CACHE IMAGE (CachedNetworkImage):
//    - Equivalente a Glide (Android) / Kingfisher (iOS) / Coil (Kotlin)
//    - Cache automático de imágenes en disco
//    - Placeholder y error handling
//    - Progressive loading con fade-in
//
// 🔒 PROTECCIÓN OFFLINE:
//    - Favoritos disponibles sin conexión (Hive persiste)
//    - Imágenes cacheadas disponibles offline
//    - UI informativa del estado de conexión
//
// 🔍 MARCADORES: "SP4 FAV:" en todos los logs y comentarios
// ============================================================================

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // ========== SP4 FAV: REPOSITORIES Y SERVICIOS ==========
  late final HiveRepository _hiveRepo;
  final _connectivity = ConnectivityService.instance;

  // ========== SP4 FAV: ESTADO ==========
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    print('✨ SP4 FAV: Inicializando Favorites Page...');
    _hiveRepo = HiveRepository(baseUrl: 'http://3.19.208.242:8000/v1');
    _checkConnectivity();
    _loadFavorites();
  }

  // ============================================================================
  // 📡 SP4 FAV: VERIFICAR CONECTIVIDAD
  // ============================================================================
  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.isOnline;
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
    print('✨ SP4 FAV: Estado conectividad - ${isOnline ? "ONLINE" : "OFFLINE"}');
  }

  // ============================================================================
  // 📦 SP4 FAV: CARGAR FAVORITOS DESDE HIVE (PREFERENCES/KEYCHAIN)
  // ============================================================================
  // Equivalente a:
  // - iOS: UserDefaults / Keychain
  // - Android: SharedPreferences / DataStore
  // - Flutter: Hive (key-value storage ultra-rápido)
  // ============================================================================
  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    
    try {
      print('✨ SP4 FAV: 🔍 Cargando favoritos desde Hive (Preferences)...');
      
      // SP4 FAV: Inicializar Hive si es necesario
      await _hiveRepo.initialize();
      
      // SP4 FAV: Obtener favoritos de Hive (key-value storage)
      // Similar a UserDefaults.get("favorites") en iOS
      // Similar a SharedPreferences.get("favorites") en Android
      final favoritesData = _hiveRepo.getFavorites();
      
      print('✨ SP4 FAV: ✅ ${favoritesData.length} favoritos cargados desde Hive');
      print('✨ SP4 FAV: 💾 Persistencia tipo Preferences/UserDefaults funcionando');
      
      if (mounted) {
        setState(() {
          _favorites = favoritesData;
          _loading = false;
        });
      }
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al cargar favoritos: $e');
      if (mounted) {
        setState(() {
          _favorites = [];
          _loading = false;
        });
      }
    }
  }

  // ============================================================================
  // ➕ SP4 FAV: AGREGAR A FAVORITOS (HIVE PREFERENCES)
  // ============================================================================
  Future<void> _addToFavorites(String itemId, String itemName, String imageUrl) async {
    try {
      print('✨ SP4 FAV: ➕ Agregando "$itemName" a favoritos...');
      
      final favorite = {
        'id': itemId,
        'name': itemName,
        'imageUrl': imageUrl,
        'addedAt': DateTime.now().toIso8601String(),
      };
      
      // SP4 FAV: Guardar en Hive (equivalente a UserDefaults/SharedPreferences)
      await _hiveRepo.addFavorite(favorite);
      
      print('✨ SP4 FAV: ✅ Favorito guardado en Hive Preferences');
      
      // Recargar lista
      await _loadFavorites();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$itemName" agregado a favoritos'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al agregar favorito: $e');
    }
  }

  // ============================================================================
  // ➖ SP4 FAV: ELIMINAR DE FAVORITOS (HIVE PREFERENCES)
  // ============================================================================
  Future<void> _removeFromFavorites(String itemId) async {
    try {
      print('✨ SP4 FAV: ➖ Eliminando favorito con ID: $itemId');
      
      // SP4 FAV: Eliminar de Hive (Preferences)
      await _hiveRepo.removeFavorite(itemId);
      
      print('✨ SP4 FAV: ✅ Favorito eliminado de Hive');
      
      // Recargar lista
      await _loadFavorites();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Eliminado de favoritos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('✨ SP4 FAV: ⚠️ Error al eliminar favorito: $e');
    }
  }

  // ============================================================================
  // 🎨 SP4 FAV: BUILD UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F6E5D)),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Mis Favoritos',
              style: TextStyle(
                color: Color(0xFF0F6E5D),
                fontWeight: FontWeight.bold,
              ),
            ),
            // SP4 FAV: Badge de estado offline
            if (!_isOnline) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, size: 12, color: Colors.orange[900]),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          // SP4 FAV: Badge con contador
          if (_favorites.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_favorites.length}',
                  style: TextStyle(
                    color: Colors.red[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFavoriteDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  // ============================================================================
  // 📋 SP4 FAV: LISTA DE FAVORITOS CON CACHED NETWORK IMAGE
  // ============================================================================
  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: Column(
        children: [
          // SP4 FAV: Banner informativo sobre tecnologías
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '💾 Guardado en Hive (Preferences) • 🖼️ Imágenes con cache automático',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final fav = _favorites[index];
                return _buildFavoriteCard(fav);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 🃏 SP4 FAV: CARD DE FAVORITO CON CACHEDNETWORKIMAGE
  // ============================================================================
  // 🖼️ CachedNetworkImage es equivalente a:
  // - Android: Glide, Picasso, Coil
  // - iOS: Kingfisher, SDWebImage
  // - Kotlin: Coil
  // 
  // Características:
  // ✅ Cache automático en disco
  // ✅ Placeholder mientras carga
  // ✅ Error widget si falla
  // ✅ Fade-in animation
  // ✅ Funciona OFFLINE (usa cache)
  // ============================================================================
  Widget _buildFavoriteCard(Map<String, dynamic> fav) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // ✨✨✨ SP4 FAV: CACHEDNETWORKIMAGE (Glide/Kingfisher/Coil) ✨✨✨
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: fav['imageUrl'] ?? 'https://via.placeholder.com/100',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                // SP4 FAV: Placeholder mientras carga (como Glide)
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                // SP4 FAV: Widget de error si falla la carga
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                ),
                // SP4 FAV: Fade-in animation (como Coil)
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 100),
                // SP4 FAV: Cache automático activado (disco + memoria)
                memCacheWidth: 200,
                memCacheHeight: 200,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Información del favorito
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fav['name'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(fav['addedAt']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // SP4 FAV: Badge de tecnologías
                  Row(
                    children: [
                      _buildTechBadge('Hive', Colors.purple),
                      const SizedBox(width: 6),
                      _buildTechBadge('Cache', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
            
            // Botón eliminar
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmRemove(fav['id'], fav['name']),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 🏷️ SP4 FAV: BADGE DE TECNOLOGÍA
  // ============================================================================
  Widget _buildTechBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ============================================================================
  // 📭 SP4 FAV: ESTADO VACÍO
  // ============================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No tienes favoritos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega productos a tu lista de favoritos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFavoriteDialog,
              icon: const Icon(Icons.add),
              label: const Text('Agregar Favorito'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // ➕ SP4 FAV: DIÁLOGO AGREGAR FAVORITO
  // ============================================================================
  void _showAddFavoriteDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController(
      text: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Favorito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL de imagen',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _addToFavorites(
                  DateTime.now().millisecondsSinceEpoch.toString(),
                  nameController.text,
                  urlController.text,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ❌ SP4 FAV: CONFIRMAR ELIMINACIÓN
  // ============================================================================
  void _confirmRemove(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar favorito'),
        content: Text('¿Eliminar "$name" de favoritos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFromFavorites(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 📅 SP4 FAV: FORMATEAR FECHA
  // ============================================================================
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Fecha desconocida';
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) return 'Hoy';
      if (diff.inDays == 1) return 'Ayer';
      if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
