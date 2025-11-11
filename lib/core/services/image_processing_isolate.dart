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
      final result = await compute(
        _compressImageInBackground,
        _ImageCompressionParams(
          imageBytes: imageBytes,
          quality: quality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
      );
      stopwatch.stop();
      if (result != null) {
        final originalSize = imageBytes.length / 1024;
        final compressedSize = result.length / 1024;
        final reduction = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);
        print('[ImageProcessing] ✅ Compresión completada en Isolate');
        print('[ImageProcessing]    ⏱️  Tiempo: ${stopwatch.elapsedMilliseconds}ms');
        print('[ImageProcessing]    📦 Original: ${originalSize.toStringAsFixed(1)} KB');
        print('[ImageProcessing]    📦 Comprimida: ${compressedSize.toStringAsFixed(1)} KB');
        print('[ImageProcessing]    📊 Reducción: $reduction%');
      }
      return result;
    } catch (e) {
      print('[ImageProcessing] ❌ Error en Isolate: $e');
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
      final futures = images.map((imageBytes) {
        return compute(
          _compressImageInBackground,
          _ImageCompressionParams(
            imageBytes: imageBytes,
            quality: quality,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
        );
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
Future<Uint8List?> _compressImageInBackground(_ImageCompressionParams params) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      params.imageBytes,
      quality: params.quality,
      minWidth: params.maxWidth,
      minHeight: params.maxHeight,
    );
    return Uint8List.fromList(result);
  } catch (e) {
    print('[ImageProcessing] Error en worker: $e');
    return null;
  }
}
class _ImageCompressionParams {
  final Uint8List imageBytes;
  final int quality;
  final int maxWidth;
  final int maxHeight;
  _ImageCompressionParams({
    required this.imageBytes,
    required this.quality,
    required this.maxWidth,
    required this.maxHeight,
  });
}
