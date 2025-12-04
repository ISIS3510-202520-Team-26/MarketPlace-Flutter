// ============================================================================
// SP4 KV: SETTINGS PAGE - CONFIGURACION CON HIVE
// ============================================================================
// Esta página usa HiveRepository para gestionar preferencias del usuario.
// 
// IMPLEMENTACIONES SP4:
// - Hive boxes para preferencias (theme, language, notifications, campus)
// - Sincronización de feature flags desde Backend
// - Cache statistics desde Hive
// - Persistencia automática entre sesiones
//
// MARCADORES: "SP4 KV SETTINGS:" para visibilidad en logs
// ============================================================================
import 'package:flutter/material.dart';
import '../../data/repositories/hive_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // SP4 KV SETTINGS: HiveRepository para preferencias
  late final HiveRepository _hiveRepo;

  static const _primary = Color(0xFF0F6E5D);

  // SP4 KV SETTINGS: Estado local de preferencias
  String _themeMode = 'system';
  String _language = 'es';
  String _campus = '';
  bool _notificationsEnabled = true;
  bool _hasActiveSession = false;
  Map<String, bool> _featureFlags = {};
  Map<String, dynamic> _storageStats = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // SP4 KV SETTINGS: Inicializa HiveRepository
    _hiveRepo = HiveRepository(baseUrl: 'http://3.19.208.242:8000/v1');
    _loadSettings();
  }

  // ============================================================================
  // SP4 KV SETTINGS: CARGAR CONFIGURACION DESDE HIVE
  // ============================================================================
  Future<void> _loadSettings() async {
    print('SP4 KV SETTINGS: Cargando configuración desde Hive...');
    setState(() => _loading = true);

    try {
      // SP4 KV SETTINGS: Inicializa Hive si es necesario
      await _hiveRepo.initialize();

      // SP4 KV SETTINGS: Obtiene configuracion de usuario
      final settings = _hiveRepo.getUserSettings();

      // SP4 KV SETTINGS: Sincroniza feature flags desde Backend
      final flags = await _hiveRepo.syncFeatureFlagsFromBackend();

      // SP4 KV SETTINGS: Obtiene estadisticas de storage
      final stats = _hiveRepo.getStorageStatistics();

      setState(() {
        _themeMode = settings['theme_mode'] ?? 'system';
        _language = settings['language'] ?? 'es';
        _notificationsEnabled = settings['notifications_enabled'] ?? true;
        _campus = settings['preferred_campus'] ?? '';
        _hasActiveSession = settings['has_active_session'] ?? false;
        _featureFlags = flags;
        _storageStats = stats;
        _loading = false;
      });

      print('SP4 KV SETTINGS: Configuración cargada exitosamente');
      print('SP4 KV SETTINGS: Theme=$_themeMode, Language=$_language, Campus=$_campus');
    } catch (e) {
      print('SP4 KV SETTINGS: Error al cargar configuración: $e');
      setState(() => _loading = false);
      _showError('Error al cargar configuración: $e');
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
                // SP4 KV SETTINGS: Header informativo
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.key, color: Colors.teal),
                            const SizedBox(width: 8),
                            Text(
                              'SP4 KV: Preferencias con Hive',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configuración persistente usando Hive boxes.\n'
                          'Sincroniza feature flags desde Backend.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // SP4 KV SETTINGS: Seccion Apariencia
                _buildSection('Apariencia', [
                  _buildThemeSelector(),
                  _buildLanguageSelector(),
                ]),
                const SizedBox(height: 24),

                // SP4 KV SETTINGS: Seccion Campus
                _buildSection('Universidad', [
                  _buildCampusSelector(),
                ]),
                const SizedBox(height: 24),

                // SP4 KV SETTINGS: Seccion Notificaciones
                _buildSection('Notificaciones', [
                  _buildSwitch(
                    'Notificaciones activadas',
                    _notificationsEnabled,
                    (v) async {
                      print('SP4 KV SETTINGS: Cambiando notificaciones a: $v');
                      await _hiveRepo.toggleNotifications(v);
                      setState(() => _notificationsEnabled = v);
                      _showSuccess('Notificaciones ${v ? "activadas" : "desactivadas"}');
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // SP4 KV SETTINGS: Seccion Feature Flags
                _buildSection('Feature Flags (Backend)', [
                  _buildFeatureFlagsList(),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _syncFeatureFlags,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sincronizar desde Backend'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // SP4 KV SETTINGS: Estadisticas de Hive
                _buildSection('Estadísticas de Storage', [
                  _buildStorageStats(),
                ]),
                const SizedBox(height: 24),

                // SP4 KV SETTINGS: Acciones
                _buildSection('Acciones', [
                  _buildActionButton(
                    'Limpiar cache de Hive',
                    Icons.delete_sweep,
                    () async {
                      print('SP4 KV SETTINGS: Limpiando cache...');
                      await _hiveRepo.clearCache();
                      _showSuccess('Cache limpiado');
                      _loadSettings();
                    },
                  ),
                  _buildActionButton(
                    'Sincronizar configuración',
                    Icons.sync,
                    () async {
                      print('SP4 KV SETTINGS: Sincronizando desde Backend...');
                      await _loadSettings();
                      _showSuccess('Configuración sincronizada');
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSection('Acciones adicionales', [
                  _buildActionButton(
                    'Limpiar cache de Hive',
                    Icons.delete_sweep,
                    () async {
                      print('SP4 KV SETTINGS: Limpiando cache...');
                      await _hiveRepo.clearCache();
                      _loadSettings();
                      _showSuccess('Cache limpiado');
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

  // ============================================================================
  // SP4 KV SETTINGS: SELECTOR DE TEMA (HIVE)
  // ============================================================================
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
                print('SP4 KV SETTINGS: Cambiando tema a: $mode');
                await _hiveRepo.updateTheme(mode);
                setState(() => _themeMode = mode);
                _showSuccess('Tema actualizado a $mode');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SP4 KV SETTINGS: SELECTOR DE IDIOMA (HIVE)
  // ============================================================================
  Widget _buildLanguageSelector() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Idioma', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'es', label: Text('Español')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {_language},
              onSelectionChanged: (Set<String> selected) async {
                final lang = selected.first;
                print('SP4 KV SETTINGS: Cambiando idioma a: $lang');
                await _hiveRepo.updateLanguage(lang);
                setState(() => _language = lang);
                _showSuccess('Idioma actualizado');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SP4 KV SETTINGS: SELECTOR DE CAMPUS (HIVE)
  // ============================================================================
  Widget _buildCampusSelector() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Campus preferido', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _campus.isEmpty ? null : _campus,
              hint: const Text('Selecciona tu campus'),
              items: const [
                DropdownMenuItem(value: 'Bogotá', child: Text('Bogotá')),
                DropdownMenuItem(value: 'Cali', child: Text('Cali')),
                DropdownMenuItem(value: 'Cartagena', child: Text('Cartagena')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  print('SP4 KV SETTINGS: Cambiando campus a: $value');
                  await _hiveRepo.setupUserProfile(
                    campus: value,
                    theme: _themeMode,
                    language: _language,
                    notifications: _notificationsEnabled,
                  );
                  setState(() => _campus = value);
                  _showSuccess('Campus actualizado a $value');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SP4 KV SETTINGS: LISTA DE FEATURE FLAGS (BACKEND)
  // ============================================================================
  Widget _buildFeatureFlagsList() {
    if (_featureFlags.isEmpty) {
      return const Card(
        color: Color(0xFFF7F8FA),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay feature flags disponibles'),
        ),
      );
    }

    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feature Flags activos:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._featureFlags.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      entry.value ? Icons.check_circle : Icons.cancel,
                      color: entry.value ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(entry.key),
                    const Spacer(),
                    Text(
                      entry.value ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: entry.value ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SP4 KV SETTINGS: SINCRONIZAR FEATURE FLAGS
  // ============================================================================
  Future<void> _syncFeatureFlags() async {
    print('SP4 KV SETTINGS: Sincronizando feature flags...');
    
    try {
      final flags = await _hiveRepo.syncFeatureFlagsFromBackend();
      setState(() => _featureFlags = flags);
      _showSuccess('${flags.length} feature flags sincronizados');
      print('SP4 KV SETTINGS: Feature flags sincronizados: ${flags.length}');
    } catch (e) {
      print('SP4 KV SETTINGS: Error al sincronizar: $e');
      _showError('Error al sincronizar feature flags');
    }
  }

  // ============================================================================
  // SP4 KV SETTINGS: ESTADISTICAS DE STORAGE
  // ============================================================================
  Widget _buildStorageStats() {
    return Card(
      color: const Color(0xFFF7F8FA),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hive Storage:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Total boxes: ${_storageStats['total_boxes'] ?? 0}'),
            Text('Total keys: ${_storageStats['total_keys'] ?? 0}'),
            Text('Sesión activa: ${_hasActiveSession ? "Sí" : "No"}'),
            const SizedBox(height: 8),
            Text(
              'Backend: ${_storageStats['backend_url'] ?? "N/A"}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SP4 KV SETTINGS: WIDGET SWITCH REUTILIZABLE
  // ============================================================================
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

  // ============================================================================
  // SP4 KV SETTINGS: BOTON DE ACCION REUTILIZABLE
  // ============================================================================
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
