import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'core/net/dio_client.dart';
import 'core/security/token_storage.dart';
import 'core/security/session_id.dart';


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
}
}