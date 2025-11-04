// lib/core/analytics/category_analytics.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// [BQ1] Business Question: "¿Qué categorías son más populares entre los usuarios?"
/// 
/// Este servicio mantiene estadísticas locales de las categorías más clicadas
/// por el usuario actual, permitiendo:
/// 1. Personalización de la UI mostrando categorías favoritas primero
/// 2. Análisis local del comportamiento del usuario
/// 3. Complementa los datos de telemetría enviados al backend
/// 
/// Los datos se almacenan localmente en SharedPreferences y se sincronizan
/// con telemetría para análisis agregado en BigQuery.
class CategoryAnalytics {
  CategoryAnalytics._();
  static final CategoryAnalytics instance = CategoryAnalytics._();

  static const String _keyClickCounts = 'analytics_category_clicks';
  static const String _keyLastClicked = 'analytics_category_last_clicked';
  static const String _keyViewDuration = 'analytics_category_view_duration';

  /// Registra un clic en una categoría
  Future<void> recordCategoryClick(String categoryId, String categoryName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Actualizar contadores de clics
    final clicksJson = prefs.getString(_keyClickCounts) ?? '{}';
    final clicks = Map<String, dynamic>.from(jsonDecode(clicksJson));
    
    clicks[categoryId] = {
      'id': categoryId,
      'name': categoryName,
      'clicks': ((clicks[categoryId]?['clicks'] as int?) ?? 0) + 1,
    };
    
    await prefs.setString(_keyClickCounts, jsonEncode(clicks));
    
    // Actualizar timestamp del último clic
    final lastClickedJson = prefs.getString(_keyLastClicked) ?? '{}';
    final lastClicked = Map<String, dynamic>.from(jsonDecode(lastClickedJson));
    
    lastClicked[categoryId] = DateTime.now().toIso8601String();
    
    await prefs.setString(_keyLastClicked, jsonEncode(lastClicked));
  }

  /// Registra tiempo de visualización en una categoría
  Future<void> recordCategoryViewDuration(
    String categoryId, 
    String categoryName, 
    int durationSeconds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    
    final durationJson = prefs.getString(_keyViewDuration) ?? '{}';
    final durations = Map<String, dynamic>.from(jsonDecode(durationJson));
    
    durations[categoryId] = {
      'id': categoryId,
      'name': categoryName,
      'total_seconds': ((durations[categoryId]?['total_seconds'] as int?) ?? 0) + durationSeconds,
      'views': ((durations[categoryId]?['views'] as int?) ?? 0) + 1,
    };
    
    await prefs.setString(_keyViewDuration, jsonEncode(durations));
  }

  /// Obtiene las categorías más clicadas (top N)
  Future<List<CategoryStats>> getTopCategories({int limit = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    
    final clicksJson = prefs.getString(_keyClickCounts) ?? '{}';
    final clicks = Map<String, dynamic>.from(jsonDecode(clicksJson));
    
    final durationJson = prefs.getString(_keyViewDuration) ?? '{}';
    final durations = Map<String, dynamic>.from(jsonDecode(durationJson));
    
    final lastClickedJson = prefs.getString(_keyLastClicked) ?? '{}';
    final lastClicked = Map<String, dynamic>.from(jsonDecode(lastClickedJson));
    
    final stats = <CategoryStats>[];
    
    for (final entry in clicks.entries) {
      final categoryId = entry.key;
      final data = entry.value as Map<String, dynamic>;
      
      final durationData = durations[categoryId] as Map<String, dynamic>?;
      final lastClickedStr = lastClicked[categoryId] as String?;
      
      stats.add(CategoryStats(
        categoryId: categoryId,
        categoryName: data['name'] as String,
        clicks: data['clicks'] as int,
        totalViewSeconds: durationData?['total_seconds'] as int? ?? 0,
        viewCount: durationData?['views'] as int? ?? 0,
        lastClicked: lastClickedStr != null 
          ? DateTime.parse(lastClickedStr) 
          : null,
      ));
    }
    
    // Ordenar por número de clics (descendente)
    stats.sort((a, b) => b.clicks.compareTo(a.clicks));
    
    return stats.take(limit).toList();
  }

  /// Obtiene estadísticas completas de todas las categorías
  Future<List<CategoryStats>> getAllCategoryStats() async {
    return getTopCategories(limit: 1000);
  }

  /// Limpia todas las estadísticas
  Future<void> clearAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyClickCounts);
    await prefs.remove(_keyLastClicked);
    await prefs.remove(_keyViewDuration);
  }

  /// Obtiene el total de categorías únicas exploradas
  Future<int> getTotalCategoriesExplored() async {
    final prefs = await SharedPreferences.getInstance();
    final clicksJson = prefs.getString(_keyClickCounts) ?? '{}';
    final clicks = Map<String, dynamic>.from(jsonDecode(clicksJson));
    return clicks.length;
  }
}

/// Modelo de datos para estadísticas de categoría
class CategoryStats {
  final String categoryId;
  final String categoryName;
  final int clicks;
  final int totalViewSeconds;
  final int viewCount;
  final DateTime? lastClicked;

  const CategoryStats({
    required this.categoryId,
    required this.categoryName,
    required this.clicks,
    required this.totalViewSeconds,
    required this.viewCount,
    this.lastClicked,
  });

  /// Tiempo promedio de visualización por visita (en segundos)
  double get averageViewSeconds {
    if (viewCount == 0) return 0.0;
    return totalViewSeconds / viewCount;
  }

  /// Score de popularidad (combinación de clics y tiempo de visualización)
  double get popularityScore {
    // Fórmula: clicks * 2 + (avg view time * 0.5)
    return (clicks * 2.0) + (averageViewSeconds * 0.5);
  }

  @override
  String toString() {
    return 'CategoryStats(name: $categoryName, clicks: $clicks, avgView: ${averageViewSeconds.toStringAsFixed(1)}s)';
  }
}
