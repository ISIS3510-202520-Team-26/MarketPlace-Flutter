// lib/core/theme/settings_provider.dart
import 'package:flutter/material.dart';
import '../storage/storage.dart';

/// Provider para manejar configuración de la app en tiempo real
/// 
/// Permite que los cambios de settings (dark mode, fontSize) se reflejen
/// automáticamente en toda la UI sin reiniciar la app.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider._();
  static final instance = SettingsProvider._();
  
  final _settingsService = AppSettingsService();
  AppSettings? _settings;
  
  AppSettings get settings => _settings ?? AppSettings(
    isDarkMode: false,
    fontSize: FontSize.medium,
    language: 'es',
    notificationsEnabled: true,
    dataSaverEnabled: false,
    lastModified: DateTime.now(),
  );
  bool get isDarkMode => settings.isDarkMode;
  FontSize get fontSize => settings.fontSize;
  String get language => settings.language;

  /// Inicializa el provider cargando settings del storage
  Future<void> initialize() async {
    try {
      _settings = await _settingsService.getSettings();
      notifyListeners();
    } catch (e) {
      print('[SettingsProvider] Error inicializando: $e');
      _settings = AppSettings(
        isDarkMode: false,
        fontSize: FontSize.medium,
        language: 'es',
        notificationsEnabled: true,
        dataSaverEnabled: false,
        lastModified: DateTime.now(),
      );
    }
  }

  /// Actualiza el modo oscuro
  Future<void> setDarkMode(bool value) async {
    await _settingsService.setDarkMode(value);
    _settings = await _settingsService.getSettings();
    notifyListeners();
  }

  /// Actualiza el tamaño de fuente
  Future<void> setFontSize(FontSize value) async {
    await _settingsService.setFontSize(value);
    _settings = await _settingsService.getSettings();
    notifyListeners();
  }

  /// Actualiza el idioma
  Future<void> setLanguage(String value) async {
    await _settingsService.setLanguage(value);
    _settings = await _settingsService.getSettings();
    notifyListeners();
  }

  /// Actualiza notificaciones
  Future<void> setNotificationsEnabled(bool value) async {
    await _settingsService.setNotificationsEnabled(value);
    _settings = await _settingsService.getSettings();
    notifyListeners();
  }

  /// Actualiza ahorro de datos
  Future<void> setDataSaverEnabled(bool value) async {
    await _settingsService.setDataSaverEnabled(value);
    _settings = await _settingsService.getSettings();
    notifyListeners();
  }

  /// Resetea a configuración por defecto
  Future<void> resetToDefaults() async {
    await _settingsService.resetToDefaults();
    _settings = await _settingsService.getSettings();
    notifyListeners();
  }
}
