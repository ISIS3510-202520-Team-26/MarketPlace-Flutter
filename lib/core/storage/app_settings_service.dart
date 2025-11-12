// lib/core/storage/app_settings_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Servicio de configuración de la aplicación usando archivos locales
/// 
/// Guarda las preferencias del usuario en un archivo JSON local:
/// - Modo oscuro (dark mode)
/// - Tamaño de fuente
/// - Idioma preferido
/// - Otras preferencias de UI
/// 
/// El archivo se almacena en el directorio de documentos de la app.
class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  AppSettings? _settings;
  File? _settingsFile;

  /// Obtiene la ruta del archivo de configuración
  Future<File> _getSettingsFile() async {
    if (_settingsFile != null) return _settingsFile!;
    
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'app_settings.json');
    _settingsFile = File(path);
    
    print('[AppSettings] 📁 Archivo de configuración: $path');
    return _settingsFile!;
  }

  /// Inicializa el servicio y carga la configuración
  Future<void> initialize() async {
    try {
      print('[AppSettings] 📦 Inicializando servicio de configuración...');
      
      final file = await _getSettingsFile();
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
        print('[AppSettings] ✅ Configuración cargada: ${_settings!}');
      } else {
        // Crear configuración por defecto
        _settings = AppSettings.defaultSettings();
        await _saveSettings();
        print('[AppSettings] 🆕 Configuración por defecto creada');
      }
    } catch (e) {
      print('[AppSettings] ⚠️ Error al cargar configuración, usando defaults: $e');
      _settings = AppSettings.defaultSettings();
    }
  }

  /// Guarda la configuración actual en el archivo
  Future<void> _saveSettings() async {
    if (_settings == null) return;
    
    try {
      final file = await _getSettingsFile();
      final json = jsonEncode(_settings!.toJson());
      await file.writeAsString(json);
      print('[AppSettings] 💾 Configuración guardada');
    } catch (e) {
      print('[AppSettings] ❌ Error al guardar configuración: $e');
    }
  }

  /// Obtiene la configuración actual
  Future<AppSettings> getSettings() async {
    if (_settings == null) {
      await initialize();
    }
    return _settings!;
  }

  // ==================== GETTERS ====================

  /// Obtiene si el modo oscuro está habilitado
  Future<bool> isDarkMode() async {
    final settings = await getSettings();
    return settings.isDarkMode;
  }

  /// Obtiene el tamaño de fuente
  Future<FontSize> getFontSize() async {
    final settings = await getSettings();
    return settings.fontSize;
  }

  /// Obtiene el idioma preferido
  Future<String> getLanguage() async {
    final settings = await getSettings();
    return settings.language;
  }

  /// Obtiene si las notificaciones están habilitadas
  Future<bool> areNotificationsEnabled() async {
    final settings = await getSettings();
    return settings.notificationsEnabled;
  }

  /// Obtiene si el modo de ahorro de datos está habilitado
  Future<bool> isDataSaverEnabled() async {
    final settings = await getSettings();
    return settings.dataSaverEnabled;
  }

  // ==================== SETTERS ====================

  /// Activa o desactiva el modo oscuro
  Future<void> setDarkMode(bool enabled) async {
    final settings = await getSettings();
    _settings = settings.copyWith(isDarkMode: enabled);
    await _saveSettings();
    print('[AppSettings] 🌙 Modo oscuro: ${enabled ? 'ON' : 'OFF'}');
  }

  /// Cambia el tamaño de fuente
  Future<void> setFontSize(FontSize size) async {
    final settings = await getSettings();
    _settings = settings.copyWith(fontSize: size);
    await _saveSettings();
    print('[AppSettings] 🔤 Tamaño de fuente: ${size.name}');
  }

  /// Cambia el idioma
  Future<void> setLanguage(String language) async {
    final settings = await getSettings();
    _settings = settings.copyWith(language: language);
    await _saveSettings();
    print('[AppSettings] 🌍 Idioma: $language');
  }

  /// Activa o desactiva las notificaciones
  Future<void> setNotificationsEnabled(bool enabled) async {
    final settings = await getSettings();
    _settings = settings.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
    print('[AppSettings] 🔔 Notificaciones: ${enabled ? 'ON' : 'OFF'}');
  }

  /// Activa o desactiva el modo de ahorro de datos
  Future<void> setDataSaverEnabled(bool enabled) async {
    final settings = await getSettings();
    _settings = settings.copyWith(dataSaverEnabled: enabled);
    await _saveSettings();
    print('[AppSettings] 📶 Ahorro de datos: ${enabled ? 'ON' : 'OFF'}');
  }

  /// Actualiza múltiples configuraciones a la vez
  Future<void> updateSettings({
    bool? isDarkMode,
    FontSize? fontSize,
    String? language,
    bool? notificationsEnabled,
    bool? dataSaverEnabled,
  }) async {
    final settings = await getSettings();
    _settings = settings.copyWith(
      isDarkMode: isDarkMode,
      fontSize: fontSize,
      language: language,
      notificationsEnabled: notificationsEnabled,
      dataSaverEnabled: dataSaverEnabled,
    );
    await _saveSettings();
    print('[AppSettings] 📝 Configuración actualizada');
  }

  /// Resetea la configuración a los valores por defecto
  Future<void> resetToDefaults() async {
    _settings = AppSettings.defaultSettings();
    await _saveSettings();
    print('[AppSettings] 🔄 Configuración reseteada a defaults');
  }

  /// Elimina el archivo de configuración
  Future<void> deleteSettings() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        await file.delete();
        print('[AppSettings] 🗑️ Archivo de configuración eliminado');
      }
      _settings = null;
      _settingsFile = null;
    } catch (e) {
      print('[AppSettings] ❌ Error al eliminar configuración: $e');
    }
  }
}

/// Enumeración para los tamaños de fuente
enum FontSize {
  small,
  medium,
  large,
  extraLarge;

  /// Obtiene el factor de escala para el tamaño
  double get scaleFactor {
    switch (this) {
      case FontSize.small:
        return 0.9;
      case FontSize.medium:
        return 1.0;
      case FontSize.large:
        return 1.15;
      case FontSize.extraLarge:
        return 1.3;
    }
  }

  /// Convierte desde string
  static FontSize fromString(String value) {
    switch (value) {
      case 'small':
        return FontSize.small;
      case 'medium':
        return FontSize.medium;
      case 'large':
        return FontSize.large;
      case 'extraLarge':
        return FontSize.extraLarge;
      default:
        return FontSize.medium;
    }
  }
}

/// Modelo de configuración de la aplicación
class AppSettings {
  final bool isDarkMode;
  final FontSize fontSize;
  final String language;
  final bool notificationsEnabled;
  final bool dataSaverEnabled;
  final DateTime lastModified;

  const AppSettings({
    required this.isDarkMode,
    required this.fontSize,
    required this.language,
    required this.notificationsEnabled,
    required this.dataSaverEnabled,
    required this.lastModified,
  });

  /// Configuración por defecto
  factory AppSettings.defaultSettings() {
    return AppSettings(
      isDarkMode: false,
      fontSize: FontSize.medium,
      language: 'es',
      notificationsEnabled: true,
      dataSaverEnabled: false,
      lastModified: DateTime.now(),
    );
  }

  /// Crea desde JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      fontSize: FontSize.fromString(json['fontSize'] as String? ?? 'medium'),
      language: json['language'] as String? ?? 'es',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      dataSaverEnabled: json['dataSaverEnabled'] as bool? ?? false,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'isDarkMode': isDarkMode,
      'fontSize': fontSize.name,
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'dataSaverEnabled': dataSaverEnabled,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  /// Copia con modificaciones
  AppSettings copyWith({
    bool? isDarkMode,
    FontSize? fontSize,
    String? language,
    bool? notificationsEnabled,
    bool? dataSaverEnabled,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      fontSize: fontSize ?? this.fontSize,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dataSaverEnabled: dataSaverEnabled ?? this.dataSaverEnabled,
      lastModified: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AppSettings(darkMode: $isDarkMode, fontSize: ${fontSize.name}, lang: $language, notifications: $notificationsEnabled, dataSaver: $dataSaverEnabled)';
  }
}
