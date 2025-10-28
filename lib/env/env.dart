class Env {
  // ========== CONFIGURACIÓN DE AMBIENTES ==========
  
  // 🔧 DEV LOCAL (celular físico conectado a tu PC por WiFi)
  static const String _devLocalUrl = 'http://192.168.2.86:8000/v1';
  
  // 🔧 DEV EMULADOR (Android Emulator)
  static const String _devEmulatorUrl = 'http://10.0.2.2:8000/v1';
  
  // 🚀 PRODUCCIÓN AWS (IP pública de tu servidor)
  static const String _prodUrl = 'http://3.19.208.242:8000/v1';
  
  // ============ AMBIENTE ACTIVO ============
  // Cambia el defaultValue según necesites:
  // - _devLocalUrl para celular físico
  // - _devEmulatorUrl para emulador
  // - _prodUrl para producción AWS
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: _prodUrl, // 🚀 Usando producción por defecto
  );
  
  static const bool enableLogs = bool.fromEnvironment(
    'ENABLE_LOGS', 
    defaultValue: true,
  );
  
  // Helpers para acceder a URLs por ambiente
  static String get devLocal => _devLocalUrl;
  static String get devEmulator => _devEmulatorUrl;
  static String get prod => _prodUrl;
}