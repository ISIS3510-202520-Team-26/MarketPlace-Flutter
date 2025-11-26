import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'core/net/dio_client.dart';
import 'core/security/token_storage.dart';
import 'core/security/session_id.dart';
import 'core/storage/storage.dart';
import 'core/telemetry/telemetry.dart';
import 'core/services/offline_listing_queue.dart';


class Bootstrap {
static Future<void> init() async {
// Rutas para cache HTTP (Hive store)
final Directory dir = await getApplicationDocumentsDirectory();
final cacheDir = Directory('${dir.path}/http_cache');
if (!await cacheDir.exists()) await cacheDir.create(recursive: true);


// Inicializar servicios singleton
await TokenStorage.instance.init();
await SessionId.instance.ensure();
await DioClient.instance.init(cachePath: cacheDir.path);

// Inicializar almacenamiento local
await _initLocalStorage();
}

/// Inicializa servicios de almacenamiento local
static Future<void> _initLocalStorage() async {
  // 1. Inicializar Telemetry Storage (Hive) para eventos
  await TelemetryStorageService().initialize();
  
  // 2. Inicializar Telemetry con sesión
  await Telemetry.i.initialize();
  
  // 3. Inicializar App Settings (JSON en archivos)
  await AppSettingsService().initialize();
  
  // 4. Inicializar OfflineListingQueue para publicaciones sin conexión
  await OfflineListingQueue.instance.initialize();
  
  // 5. Base de datos local SQLite se inicializa automáticamente en primera consulta
  // LocalDatabaseService() - lazy initialization
  
  print('[Bootstrap] ✅ Almacenamiento local inicializado');
}
}