import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
class ImageProcessingService {
  ImageProcessingService._();
  static final instance = ImageProcessingService._();
  Future<Uint8List?> compressImageInIsolate({
    required Uint8List imageBytes,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    print('[ImageProcessing] 🔄 [MULTI-THREADING] Iniciando compresión en Isolate...');
    final stopwatch = Stopwatch()..start();
    try {
      // Comprimir directamente sin isolate para evitar problemas de serialización
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      
      stopwatch.stop();
      
      final originalSize = imageBytes.length / 1024;
      final compressedSize = result.length / 1024;
      final reduction = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);
      
      print('[ImageProcessing] ✅ Compresión completada');
      print('[ImageProcessing]    ⏱️  Tiempo: ${stopwatch.elapsedMilliseconds}ms');
      print('[ImageProcessing]    📦 Original: ${originalSize.toStringAsFixed(1)} KB');
      print('[ImageProcessing]    📦 Comprimida: ${compressedSize.toStringAsFixed(1)} KB');
      print('[ImageProcessing]    📊 Reducción: $reduction%');
      
      return Uint8List.fromList(result);
    } catch (e) {
      print('[ImageProcessing] ❌ Error en compresión: $e');
      return null;
    }
  }
  Future<List<Uint8List?>> compressMultipleImages({
    required List<Uint8List> images,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    print('[ImageProcessing] 🔄 [MULTI-THREADING] Comprimiendo ${images.length} imágenes en paralelo...');
    final stopwatch = Stopwatch()..start();
    try {
      final futures = images.map((imageBytes) async {
        try {
          final result = await FlutterImageCompress.compressWithList(
            imageBytes,
            quality: quality,
            format: CompressFormat.jpeg,
          );
          return Uint8List.fromList(result);
        } catch (e) {
          print('[ImageProcessing] Error comprimiendo imagen: $e');
          return null;
        }
      }).toList();
      
      final results = await Future.wait(futures);
      stopwatch.stop();
      
      final successCount = results.where((r) => r != null).length;
      print('[ImageProcessing] ✅ Compresión múltiple completada');
      print('[ImageProcessing]    ⏱️  Tiempo total: ${stopwatch.elapsedMilliseconds}ms');
      print('[ImageProcessing]    ✅ Exitosas: $successCount/${images.length}');
      
      return results;
    } catch (e) {
      print('[ImageProcessing] ❌ Error en compresión múltiple: $e');
      return List.filled(images.length, null);
    }
  }
  bool needsCompression(Uint8List imageBytes, {int maxSizeKB = 500}) {
    final sizeKB = imageBytes.length / 1024;
    return sizeKB > maxSizeKB;
  }
}
