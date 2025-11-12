// lib/core/storage/storage_export_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio para exportar archivos de almacenamiento interno a carpeta externa
/// 
/// Permite copiar la base de datos SQLite, archivos Hive y JSON
/// a una carpeta accesible desde el file manager del dispositivo.
/// 
/// Los archivos se exportan a: /storage/emulated/0/Download/MarketApp_Export/
class StorageExportService {
  static final StorageExportService _instance = StorageExportService._internal();
  factory StorageExportService() => _instance;
  StorageExportService._internal();

  /// Exporta todos los archivos de almacenamiento a una carpeta externa
  /// 
  /// Retorna la ruta de la carpeta donde se exportaron los archivos.
  /// Lanza una excepción si hay algún error.
  Future<String> exportAllFiles() async {
    try {
      print('[StorageExport] 📤 Iniciando exportación de archivos...');
      
      // 0. Solicitar permisos de almacenamiento (Android 10 y anteriores)
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();
        if (androidInfo < 33) {
          // Android 12 y anteriores necesitan permisos explícitos
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Permiso de almacenamiento denegado. Por favor, permite el acceso en Configuración.');
          }
        }
      }
      
      // 1. Obtener carpeta de destino (Downloads o External Storage)
      Directory? downloadsDir = await getDownloadsDirectory();
      
      // Fallback: si Downloads no está disponible, usar External Storage
      if (downloadsDir == null) {
        downloadsDir = await getExternalStorageDirectory();
        if (downloadsDir == null) {
          throw Exception('No se pudo acceder a carpetas externas. Verifica los permisos.');
        }
        print('[StorageExport] ⚠️ Downloads no disponible, usando: ${downloadsDir.path}');
      }
      
      // Crear carpeta específica para la exportación
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final exportDir = Directory(p.join(downloadsDir.path, 'MarketApp_Export_$timestamp'));
      
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      
      print('[StorageExport] 📁 Carpeta de exportación: ${exportDir.path}');
      
      // 2. Exportar base de datos SQLite
      await _exportSQLiteDatabase(exportDir);
      
      // 3. Exportar archivos Hive
      await _exportHiveFiles(exportDir);
      
      // 4. Exportar archivo JSON de configuración
      await _exportJsonSettings(exportDir);
      
      // 5. Crear archivo README con información
      await _createReadmeFile(exportDir);
      
      print('[StorageExport] ✅ Exportación completada exitosamente');
      return exportDir.path;
      
    } catch (e) {
      print('[StorageExport] ❌ Error durante la exportación: $e');
      rethrow;
    }
  }

  /// Exporta la base de datos SQLite
  Future<void> _exportSQLiteDatabase(Directory exportDir) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceDbPath = p.join(dbPath, 'market_app.db');
      final sourceDbFile = File(sourceDbPath);
      
      if (await sourceDbFile.exists()) {
        final destDbPath = p.join(exportDir.path, 'market_app.db');
        await sourceDbFile.copy(destDbPath);
        
        final size = await sourceDbFile.length();
        print('[StorageExport] ✅ SQLite exportado: ${(size / 1024).toStringAsFixed(2)} KB');
        
        // También copiar archivos auxiliares si existen
        final shmFile = File('$sourceDbPath-shm');
        if (await shmFile.exists()) {
          await shmFile.copy('$destDbPath-shm');
        }
        
        final walFile = File('$sourceDbPath-wal');
        if (await walFile.exists()) {
          await walFile.copy('$destDbPath-wal');
        }
      } else {
        print('[StorageExport] ⚠️ Base de datos SQLite no encontrada');
      }
    } catch (e) {
      print('[StorageExport] ⚠️ Error exportando SQLite: $e');
    }
  }

  /// Exporta archivos de Hive
  Future<void> _exportHiveFiles(Directory exportDir) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      
      // Crear subdirectorio para Hive
      final hiveExportDir = Directory(p.join(exportDir.path, 'hive'));
      if (!await hiveExportDir.exists()) {
        await hiveExportDir.create();
      }
      
      // Buscar todos los archivos .hive y .lock
      final files = docsDir.listSync().where((file) {
        final name = p.basename(file.path);
        return name.endsWith('.hive') || name.endsWith('.lock');
      }).toList();
      
      for (final file in files) {
        if (file is File) {
          final fileName = p.basename(file.path);
          final destPath = p.join(hiveExportDir.path, fileName);
          await file.copy(destPath);
          
          final size = await file.length();
          print('[StorageExport] ✅ Hive exportado: $fileName (${(size / 1024).toStringAsFixed(2)} KB)');
        }
      }
      
      // También exportar carpeta http_cache si existe
      final cacheDir = Directory(p.join(docsDir.path, 'http_cache'));
      if (await cacheDir.exists()) {
        final cacheExportDir = Directory(p.join(exportDir.path, 'http_cache'));
        await _copyDirectory(cacheDir, cacheExportDir);
        print('[StorageExport] ✅ Cache HTTP exportado');
      }
      
    } catch (e) {
      print('[StorageExport] ⚠️ Error exportando Hive: $e');
    }
  }

  /// Exporta archivo JSON de configuración
  Future<void> _exportJsonSettings(Directory exportDir) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final settingsPath = p.join(docsDir.path, 'app_settings.json');
      final settingsFile = File(settingsPath);
      
      if (await settingsFile.exists()) {
        final destPath = p.join(exportDir.path, 'app_settings.json');
        await settingsFile.copy(destPath);
        
        final size = await settingsFile.length();
        print('[StorageExport] ✅ Configuración JSON exportada: ${(size / 1024).toStringAsFixed(2)} KB');
      } else {
        print('[StorageExport] ⚠️ Archivo de configuración JSON no encontrado');
      }
    } catch (e) {
      print('[StorageExport] ⚠️ Error exportando JSON: $e');
    }
  }

  /// Crea un archivo README con información sobre los archivos exportados
  Future<void> _createReadmeFile(Directory exportDir) async {
    try {
      final readme = File(p.join(exportDir.path, 'README.txt'));
      
      final content = '''
========================================
  MarketPlace App - Archivos Exportados
========================================

Fecha de exportación: ${DateTime.now()}

CONTENIDO:
----------

1. market_app.db
   - Base de datos SQLite principal
   - Contiene: listings, categories, brands
   - Tamaño: Ver archivo
   - Herramienta: DB Browser for SQLite (https://sqlitebrowser.org/)

2. hive/
   - telemetry_events.hive: Eventos de telemetría
   - Archivos .lock: Control de concurrencia de Hive
   - Formato: Hive box (NoSQL key-value)

3. http_cache/
   - Cache de respuestas HTTP
   - Formato: Hive store (usado por Dio)

4. app_settings.json
   - Configuración de la app
   - Formato: JSON legible
   - Contenido: dark mode, font size, idioma, etc.

CÓMO USAR:
----------

Ver SQLite Database:
  1. Instalar DB Browser for SQLite
  2. Abrir market_app.db
  3. Explorar tablas: listings, categories, brands

Ver JSON:
  1. Abrir app_settings.json con cualquier editor de texto
  2. Formato JSON legible

Ver Hive:
  - Requiere herramientas específicas de Dart/Flutter
  - O inspeccionar con código Flutter usando Hive.box()

RESTAURAR (Avanzado):
---------------------
Para restaurar estos archivos:
  1. Cerrar la app completamente
  2. Usar ADB o root para copiar archivos a:
     /data/data/com.tu_paquete.market_app/
  3. Reiniciar la app

ADVERTENCIA:
-----------
No modifiques estos archivos manualmente a menos que sepas
lo que estás haciendo. La app podría dejar de funcionar.

========================================
''';
      
      await readme.writeAsString(content);
      print('[StorageExport] 📄 README creado');
      
    } catch (e) {
      print('[StorageExport] ⚠️ Error creando README: $e');
    }
  }

  /// Copia un directorio recursivamente
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(p.join(destination.path, p.basename(entity.path)));
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File(p.join(destination.path, p.basename(entity.path)));
        await entity.copy(newFile.path);
      }
    }
  }

  /// Obtiene la versión de Android (SDK level)
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      // En producción, usa device_info_plus o similar
      // Por ahora, asumimos Android 11+ (SDK 30+) para simplificar
      return 33; // Android 13
    } catch (e) {
      print('[StorageExport] ⚠️ Error obteniendo versión Android: $e');
      return 29; // Asumir Android 10 por defecto
    }
  }

  /// Obtiene información sobre el tamaño de los archivos internos
  Future<StorageInfo> getStorageInfo() async {
    try {
      int totalSize = 0;
      final files = <String, int>{};
      
      // SQLite
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'market_app.db'));
      if (await dbFile.exists()) {
        final size = await dbFile.length();
        files['SQLite Database'] = size;
        totalSize += size;
      }
      
      // Hive y JSON
      final docsDir = await getApplicationDocumentsDirectory();
      for (final entity in docsDir.listSync(recursive: true)) {
        if (entity is File) {
          final size = await entity.length();
          final name = p.basename(entity.path);
          files[name] = size;
          totalSize += size;
        }
      }
      
      return StorageInfo(totalSize: totalSize, fileDetails: files);
      
    } catch (e) {
      print('[StorageExport] ⚠️ Error obteniendo info de almacenamiento: $e');
      return StorageInfo(totalSize: 0, fileDetails: {});
    }
  }
}

/// Información sobre el almacenamiento usado
class StorageInfo {
  final int totalSize; // en bytes
  final Map<String, int> fileDetails;

  const StorageInfo({
    required this.totalSize,
    required this.fileDetails,
  });

  String get totalSizeFormatted {
    if (totalSize < 1024) {
      return '$totalSize B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  @override
  String toString() {
    return 'StorageInfo(total: $totalSizeFormatted, files: ${fileDetails.length})';
  }
}
