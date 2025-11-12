// lib/presentation/settings/settings_page.dart
import 'package:flutter/material.dart';
import '../../core/storage/storage.dart';
import '../../core/storage/storage_export_service.dart';
import '../../core/theme/settings_provider.dart';

/// Pantalla de configuración de la aplicación
/// 
/// Permite al usuario modificar:
/// - Modo oscuro/claro
/// - Tamaño de fuente
/// - Idioma
/// - Notificaciones
/// - Ahorro de datos
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsService = AppSettingsService();
  AppSettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar configuración: $e')),
        );
      }
    }
  }

  Future<void> _updateSetting(Future<void> Function(SettingsProvider) update) async {
    try {
      // Usar el provider global para que se disparen los cambios
      final provider = SettingsProvider.instance;
      await update(provider);
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Storage',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugStoragePage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
              ? const Center(child: Text('No se pudo cargar la configuración'))
              : RefreshIndicator(
                  onRefresh: _loadSettings,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Apariencia
                      _buildSectionHeader('Apariencia'),
                      _buildDarkModeSwitch(),
                      _buildFontSizeSelector(),
                      const Divider(height: 32),

                      // Idioma
                      _buildSectionHeader('Idioma'),
                      _buildLanguageSelector(),
                      const Divider(height: 32),

                      // Notificaciones
                      _buildSectionHeader('Notificaciones'),
                      _buildNotificationsSwitch(),
                      const Divider(height: 32),

                      // Datos
                      _buildSectionHeader('Datos'),
                      _buildDataSaverSwitch(),
                      const Divider(height: 32),

                      // Información
                      _buildSectionHeader('Información'),
                      _buildInfoCard(),
                      const SizedBox(height: 16),

                      // Resetear
                      _buildResetButton(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
  }

  Widget _buildDarkModeSwitch() {
    return SwitchListTile(
      title: const Text('Modo Oscuro'),
      subtitle: Text(_settings!.isDarkMode ? 'Activado' : 'Desactivado'),
      value: _settings!.isDarkMode,
      onChanged: (value) {
        _updateSetting((provider) => provider.setDarkMode(value));
      },
      secondary: Icon(
        _settings!.isDarkMode ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildFontSizeSelector() {
    return ListTile(
      leading: Icon(Icons.text_fields, color: Theme.of(context).primaryColor),
      title: const Text('Tamaño de Fuente'),
      subtitle: Text(_getFontSizeLabel(_settings!.fontSize)),
      trailing: DropdownButton<FontSize>(
        value: _settings!.fontSize,
        items: FontSize.values.map((size) {
          return DropdownMenuItem(
            value: size,
            child: Text(_getFontSizeLabel(size)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            _updateSetting((provider) => provider.setFontSize(value));
          }
        },
      ),
    );
  }

  String _getFontSizeLabel(FontSize size) {
    switch (size) {
      case FontSize.small:
        return 'Pequeño';
      case FontSize.medium:
        return 'Mediano';
      case FontSize.large:
        return 'Grande';
      case FontSize.extraLarge:
        return 'Muy Grande';
    }
  }

  Widget _buildLanguageSelector() {
    return ListTile(
      leading: Icon(Icons.language, color: Theme.of(context).primaryColor),
      title: const Text('Idioma'),
      subtitle: Text(_getLanguageLabel(_settings!.language)),
      trailing: DropdownButton<String>(
        value: _settings!.language,
        items: const [
          DropdownMenuItem(value: 'es', child: Text('Español')),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
        onChanged: (value) {
          if (value != null) {
            _updateSetting((provider) => provider.setLanguage(value));
          }
        },
      ),
    );
  }

  String _getLanguageLabel(String lang) {
    return lang == 'es' ? 'Español' : 'English';
  }

  Widget _buildNotificationsSwitch() {
    return SwitchListTile(
      title: const Text('Notificaciones'),
      subtitle: Text(_settings!.notificationsEnabled ? 'Activadas' : 'Desactivadas'),
      value: _settings!.notificationsEnabled,
      onChanged: (value) {
        _updateSetting((provider) => provider.setNotificationsEnabled(value));
      },
      secondary: Icon(
        _settings!.notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildDataSaverSwitch() {
    return SwitchListTile(
      title: const Text('Ahorro de Datos'),
      subtitle: Text(_settings!.dataSaverEnabled ? 'Activado' : 'Desactivado'),
      value: _settings!.dataSaverEnabled,
      onChanged: (value) {
        _updateSetting((provider) => provider.setDataSaverEnabled(value));
      },
      secondary: Icon(
        _settings!.dataSaverEnabled ? Icons.data_saver_on : Icons.data_saver_off,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Última modificación', _formatDate(_settings!.lastModified)),
            const SizedBox(height: 8),
            _buildInfoRow('Archivo', 'app_settings.json'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildResetButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Resetear Configuración'),
            content: const Text('¿Estás seguro de que quieres restaurar la configuración por defecto?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Resetear'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _updateSetting((provider) => provider.resetToDefaults());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Configuración reseteada')),
            );
          }
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Resetear a Valores por Defecto'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// Pantalla de Debug para ver archivos de almacenamiento
class DebugStoragePage extends StatefulWidget {
  const DebugStoragePage({super.key});

  @override
  State<DebugStoragePage> createState() => _DebugStoragePageState();
}

class _DebugStoragePageState extends State<DebugStoragePage> {
  final _localDb = LocalDatabaseService();
  final _telemetryStorage = TelemetryStorageService();
  final _settingsService = AppSettingsService();
  final _exportService = StorageExportService();

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      // SQLite stats
      final categoriesCount = (await _localDb.getCategories()).length;
      final brandsCount = (await _localDb.getBrands()).length;
      final listingsCount = await _localDb.getListingsCount();
      final lastSync = await _localDb.getLastSyncTime();

      // Hive stats
      final telemetryStats = await _telemetryStorage.getStats();

      // Settings
      final settings = await _settingsService.getSettings();
      
      // Storage info
      final storageInfo = await _exportService.getStorageInfo();

      setState(() {
        _stats = {
          'storage': {
            'totalSize': storageInfo.totalSizeFormatted,
            'files': storageInfo.fileDetails.length,
          },
          'sqlite': {
            'categories': categoriesCount,
            'brands': brandsCount,
            'listings': listingsCount,
            'lastSync': lastSync?.toString() ?? 'Nunca',
          },
          'hive': {
            'totalEvents': telemetryStats.totalEvents,
            'uniqueUsers': telemetryStats.uniqueUsers,
            'oldestEvent': telemetryStats.oldestEvent?.toString() ?? 'N/A',
            'eventTypes': telemetryStats.eventTypeCount,
          },
          'settings': {
            'darkMode': settings.isDarkMode,
            'fontSize': settings.fontSize.name,
            'language': settings.language,
            'lastModified': settings.lastModified.toString(),
          },
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _stats = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStorageCard(
                  'Almacenamiento Total',
                  Icons.folder,
                  _stats['storage'] ?? {},
                  Colors.purple,
                ),
                const SizedBox(height: 16),
                _buildStorageCard(
                  'SQLite Database',
                  Icons.storage,
                  _stats['sqlite'] ?? {},
                  Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildStorageCard(
                  'Hive (Telemetry)',
                  Icons.analytics,
                  _stats['hive'] ?? {},
                  Colors.green,
                ),
                const SizedBox(height: 16),
                _buildStorageCard(
                  'Settings File',
                  Icons.settings,
                  _stats['settings'] ?? {},
                  Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildActionsCard(),
              ],
            ),
    );
  }

  Widget _buildStorageCard(String title, IconData icon, Map<String, dynamic> data, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(),
            ...data.entries.map((entry) {
              final value = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        value is Map
                            ? value.entries.map((e) => '${e.key}: ${e.value}').join('\n')
                            : value.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Acciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await _localDb.cleanupOldData(maxAgeDays: 30);
                await _loadStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Datos antiguos limpiados')),
                  );
                }
              },
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Limpiar Datos Antiguos (SQLite)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final count = await _telemetryStorage.cleanupOldEvents(maxAgeDays: 7);
                await _loadStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$count eventos antiguos limpiados')),
                  );
                }
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Limpiar Eventos Antiguos (Hive)'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _exportFiles(),
              icon: const Icon(Icons.file_download),
              label: const Text('Exportar Archivos a Downloads'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('¿Limpiar TODO?'),
                    content: const Text('Esto eliminará toda la base de datos local, eventos y configuración.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _localDb.clearAll();
                  await _telemetryStorage.clearAll();
                  await _settingsService.deleteSettings();
                  await _loadStats();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Todo el almacenamiento local limpiado')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.warning),
              label: const Text('Limpiar TODO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportFiles() async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Exportando archivos...'),
              const SizedBox(height: 8),
              Text(
                'Esto puede tardar unos segundos',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );

      // Realizar la exportación
      final exportPath = await _exportService.exportAllFiles();

      // Cerrar diálogo de progreso
      if (mounted) Navigator.pop(context);

      // Mostrar resultado exitoso
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Exportación Exitosa'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Todos los archivos se han exportado correctamente.'),
                const SizedBox(height: 16),
                const Text(
                  'Ubicación:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    exportPath,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Puedes encontrar los archivos en tu app de Archivos o File Manager.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'Contenido exportado:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text('• market_app.db (SQLite)', style: TextStyle(fontSize: 11)),
                      Text('• telemetry_events.hive', style: TextStyle(fontSize: 11)),
                      Text('• app_settings.json', style: TextStyle(fontSize: 11)),
                      Text('• http_cache/ (carpeta)', style: TextStyle(fontSize: 11)),
                      Text('• README.txt (instrucciones)', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de progreso si está abierto
      if (mounted) Navigator.pop(context);

      // Mostrar error
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error al Exportar'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No se pudieron exportar los archivos.'),
                const SizedBox(height: 16),
                const Text(
                  'Error:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Posibles causas:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Sin permisos de almacenamiento\n'
                  '• Espacio insuficiente\n'
                  '• Archivos en uso',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    }
  }
}
