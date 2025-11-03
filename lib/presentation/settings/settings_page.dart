// lib/presentation/settings/settings_page.dart
//
// Página de configuración que demuestra el uso completo de UserPreferencesService
//
import 'package:flutter/material.dart';
import '../../core/storage/user_preferences_service.dart';
import '../../core/storage/cache_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _prefs = UserPreferencesService.instance;
  final _cache = CacheService.instance;

  static const _primary = Color(0xFF0F6E5D);

  // Estado local
  String _themeMode = 'system';
  String _sortBy = 'recent';
  String _gridMode = 'grid';
  String _imageQuality = 'medium';
  bool _locationEnabled = true;
  bool _notificationsEnabled = true;
  bool _autoPlayVideos = false;
  double _defaultRadius = 5.0;
  PriceRange? _priceRange;
  List<String> _recentSearches = [];
  List<String> _favoriteCategories = [];
  CacheStats? _cacheStats;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    try {
      final theme = await _prefs.getThemeMode();
      final sort = await _prefs.getDefaultSortBy();
      final grid = await _prefs.getGridViewMode();
      final image = await _prefs.getImageQuality();
      final location = await _prefs.isLocationEnabled();
      final notifications = await _prefs.areNotificationsEnabled();
      final autoPlay = await _prefs.shouldAutoPlayVideos();
      final radius = await _prefs.getDefaultRadius() ?? 5.0;
      final price = await _prefs.getDefaultPriceRange();
      final searches = await _prefs.getRecentSearches();
      final favorites = await _prefs.getFavoriteCategories();
      final stats = await _cache.getStats();

      setState(() {
        _themeMode = theme;
        _sortBy = sort;
        _gridMode = grid;
        _imageQuality = image;
        _locationEnabled = location;
        _notificationsEnabled = notifications;
        _autoPlayVideos = autoPlay;
        _defaultRadius = radius;
        _priceRange = price;
        _recentSearches = searches;
        _favoriteCategories = favorites;
        _cacheStats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error al cargar configuración');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Apariencia', [
                  _buildThemeSelector(),
                  _buildGridModeSelector(),
                  _buildImageQualitySelector(),
                ]),
                const SizedBox(height: 24),
                _buildSection('Búsqueda', [
                  _buildSortBySelector(),
                  _buildRadiusSlider(),
                  _buildPriceRangeInput(),
                ]),
                const SizedBox(height: 24),
                _buildSection('Permisos', [
                  _buildSwitch(
                    'Usar ubicación',
                    _locationEnabled,
                    (v) async {
                      await _prefs.setLocationEnabled(v);
                      setState(() => _locationEnabled = v);
                      _showSuccess('Preferencia de ubicación actualizada');
                    },
                  ),
                  _buildSwitch(
                    'Notificaciones',
                    _notificationsEnabled,
                    (v) async {
                      await _prefs.setNotificationsEnabled(v);
                      setState(() => _notificationsEnabled = v);
                      _showSuccess('Preferencia de notificaciones actualizada');
                    },
                  ),
                  _buildSwitch(
                    'Auto-reproducir videos',
                    _autoPlayVideos,
                    (v) async {
                      await _prefs.setAutoPlayVideos(v);
                      setState(() => _autoPlayVideos = v);
                      _showSuccess('Auto-reproducción actualizada');
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection('Datos', [
                  _buildRecentSearches(),
                  _buildFavoriteCategories(),
                  _buildCacheStats(),
                ]),
                const SizedBox(height: 24),
                _buildSection('Acciones', [
                  _buildActionButton(
                    'Limpiar búsquedas recientes',
                    Icons.history,
                    () async {
                      await _prefs.clearRecentSearches();
                      _loadSettings();
                      _showSuccess('Búsquedas recientes eliminadas');
                    },
                  ),
                  _buildActionButton(
                    'Limpiar cache expirado',
                    Icons.cleaning_services,
                    () async {
                      final removed = await _cache.cleanExpired();
                      _loadSettings();
                      _showSuccess('$removed entradas eliminadas');
                    },
                  ),
                  _buildActionButton(
                    'Limpiar todo el cache',
                    Icons.delete_sweep,
                    () async {
                      await _cache.clearAll();
                      _loadSettings();
                      _showSuccess('Cache limpiado completamente');
                    },
                    isDestructive: true,
                  ),
                  _buildActionButton(
                    'Restablecer configuración',
                    Icons.restore,
                    () async {
                      await _prefs.clearAll();
                      _loadSettings();
                      _showSuccess('Configuración restablecida');
                    },
                    isDestructive: true,
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _primary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildThemeSelector() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tema', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'system', label: Text('Sistema')),
                ButtonSegment(value: 'light', label: Text('Claro')),
                ButtonSegment(value: 'dark', label: Text('Oscuro')),
              ],
              selected: {_themeMode},
              onSelectionChanged: (Set<String> selected) async {
                final mode = selected.first;
                await _prefs.setThemeMode(mode);
                setState(() => _themeMode = mode);
                _showSuccess('Tema actualizado');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridModeSelector() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vista de listados', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'grid', label: Text('Cuadrícula'), icon: Icon(Icons.grid_view)),
                ButtonSegment(value: 'list', label: Text('Lista'), icon: Icon(Icons.list)),
              ],
              selected: {_gridMode},
              onSelectionChanged: (Set<String> selected) async {
                final mode = selected.first;
                await _prefs.setGridViewMode(mode);
                setState(() => _gridMode = mode);
                _showSuccess('Vista actualizada');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageQualitySelector() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calidad de imagen', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Baja')),
                ButtonSegment(value: 'medium', label: Text('Media')),
                ButtonSegment(value: 'high', label: Text('Alta')),
              ],
              selected: {_imageQuality},
              onSelectionChanged: (Set<String> selected) async {
                final quality = selected.first;
                await _prefs.setImageQuality(quality);
                setState(() => _imageQuality = quality);
                _showSuccess('Calidad actualizada');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBySelector() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Orden predeterminado', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _sortBy,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'recent', child: Text('Más recientes')),
                DropdownMenuItem(value: 'price_asc', child: Text('Precio: menor a mayor')),
                DropdownMenuItem(value: 'price_desc', child: Text('Precio: mayor a menor')),
                DropdownMenuItem(value: 'distance', child: Text('Distancia')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  await _prefs.setDefaultSortBy(value);
                  setState(() => _sortBy = value);
                  _showSuccess('Orden actualizado');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Radio de búsqueda: ${_defaultRadius.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _defaultRadius,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_defaultRadius.toStringAsFixed(1)} km',
              onChanged: (value) {
                setState(() => _defaultRadius = value);
              },
              onChangeEnd: (value) async {
                await _prefs.setDefaultRadius(value);
                _showSuccess('Radio actualizado');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRangeInput() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rango de precio predeterminado', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _priceRange != null
                  ? 'Min: \$${_priceRange!.min?.toStringAsFixed(0) ?? "N/A"} - Max: \$${_priceRange!.max?.toStringAsFixed(0) ?? "N/A"}'
                  : 'No configurado',
            ),
            TextButton(
              onPressed: () {
                // Aquí podrías abrir un diálogo para configurar el rango
                _showSuccess('Función de configuración de rango de precio');
              },
              child: const Text('Configurar rango'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, Function(bool) onChanged) {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        activeColor: _primary,
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Búsquedas recientes', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('${_recentSearches.length} búsquedas guardadas'),
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _recentSearches.take(5).map((search) {
                  return Chip(label: Text(search), backgroundColor: Colors.white);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCategories() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Categorías favoritas', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('${_favoriteCategories.length} categorías guardadas'),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStats() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estadísticas de cache', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_cacheStats != null) ...[
              Text('Total: ${_cacheStats!.totalEntries} entradas'),
              Text('Activas: ${_cacheStats!.activeEntries}'),
              Text('Expiradas: ${_cacheStats!.expiredEntries}'),
            ] else
              const Text('No disponible'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : _primary),
        title: Text(
          title,
          style: TextStyle(color: isDestructive ? Colors.red : Colors.black),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}
