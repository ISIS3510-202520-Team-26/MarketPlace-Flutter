// lib/core/ux/ux_tunning_service.dart
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../net/dio_client.dart';
import 'ux_hints.dart';

class UxTuningService {
  UxTuningService._();
  static final UxTuningService instance = UxTuningService._();

  final Dio _dio = DioClient.instance.dio;

  static const _kCacheKey = 'ux_hints_cache_v1';
  static const _kRecentsKey = 'ux_recent_categories_v1';

  Future<UxHints> loadHints({Duration window = const Duration(hours: 24)}) async {
    final end = DateTime.now().toUtc();
    final start = end.subtract(window);
    String iso(DateTime d) => d.toIso8601String();

    try {
      final r21 = await _dio.get('/analytics/bq/2_1', queryParameters: {
        'start': iso(start), 'end': iso(end),
      });
      final r22 = await _dio.get('/analytics/bq/2_2', queryParameters: {
        'start': iso(start), 'end': iso(end),
      });
      // ← NUEVO: dwell por pantalla
      final r24 = await _dio.get('/analytics/bq/2_4', queryParameters: {
        'start': iso(start), 'end': iso(end),
      });

      final List<Map<String, dynamic>> bq21 = (r21.data as List).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> bq22 = (r22.data as List).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> bq24 = (r24.data as List).cast<Map<String, dynamic>>();

      final hints = await _computeHints(bq21, bq22, bq24);

      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kCacheKey, jsonEncode(hints.toJson()));

      return hints;
    } catch (_) {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kCacheKey);
      if (raw != null) {
        return UxHints.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      return const UxHints();
    }
  }

  Future<void> recordLocalCategoryUse(String categoryId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRecentsKey);
    final Map<String, int> m = raw == null
        ? <String, int>{}
        : Map<String, int>.from(
            (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', v as int)));

    m.update(categoryId, (old) => old + 1, ifAbsent: () => 1);

    final sorted = m.entries.sorted((a, b) => b.value.compareTo(a.value)).toList();
    final trimmed = Map.fromEntries(sorted.take(12));
    await sp.setString(_kRecentsKey, jsonEncode(trimmed));
  }

  // ------------------ Internals ------------------

  Future<UxHints> _computeHints(
    List<Map<String, dynamic>> bq21,
    List<Map<String, dynamic>> bq22,
    List<Map<String, dynamic>> bq24, // ← NUEVO
  ) async {
    int _sum(List<Map<String, dynamic>> list, bool Function(Map) pred, String key) {
      return list.where(pred).map((e) => (e[key] as num?)?.toInt() ?? 0).fold(0, (a, b) => a + b);
    }

    final searches = _sum(bq21, (e) => e['event_type'] == 'search.performed', 'count');
    final filterUsedEvent = _sum(bq21, (e) => e['event_type'] == 'search.filter.used', 'count');
    final filterOpenClicks = _sum(bq22, (e) => e['button'] == 'filter', 'count');
    final filterCategoryClicks = _sum(bq22, (e) => e['button'] == 'filter_category', 'count');

    final effectiveFilterUse = filterUsedEvent + filterOpenClicks + filterCategoryClicks;
    final lowFilterRatio = searches > 0 && (effectiveFilterUse / searches) < 0.25;

    final toggleLocation = _sum(bq22, (e) => e['button'] == 'toggle_location', 'count');
    final defaultByDistance = toggleLocation >= 10;

    // Recencia local → recomendación de categorías
    final recents = await _loadLocalRecents();
    final topIds = recents.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .map((e) => e.key)
        .take(8)
        .toList();

    // === NUEVO: CTAs por dwell (BQ 2.4) ===
    // bq24 = [{screen, total_seconds, views, avg_seconds}, ...]
    final dwellSorted = bq24.toList()
      ..sort((a, b) => (b['total_seconds'] as num).compareTo(a['total_seconds'] as num));

    // Mapea pantallas -> CTAs candidatas en orden.
    // login/register => 'auth'; home => 'search' (primero) y 'publish' (segundo); create_listing => 'publish'
    final List<String> ctas = [];
    void addCta(String key) { if (!ctas.contains(key)) ctas.add(key); }

    for (final row in dwellSorted) {
      final s = (row['screen'] ?? '').toString();
      switch (s) {
        case 'login':
        case 'register':
          addCta('auth');
          break;
        case 'home':
          addCta('search');
          addCta('publish');
          break;
        case 'create_listing':
          addCta('publish');
          break;
        default:
          // otras pantallas no mapeadas → sin CTA
          break;
      }
    }

    // Fallback razonable si no vino nada:
    if (ctas.isEmpty) {
      ctas.addAll(['search', 'publish', 'auth']);
    }

    return UxHints(
      recommendedCategoryIds: topIds,
      autoOpenFiltersAfterNPlainSearches: lowFilterRatio,
      searchesWithoutFiltersThreshold: 2,
      defaultSortByDistance: defaultByDistance,
      ctaPriority: ctas,
      highlightSearchCta: ctas.contains('search'),
      highlightPublishCta: ctas.contains('publish'),
      highlightAuthCta: ctas.contains('auth'),
    );
  }

  Future<Map<String, int>> _loadLocalRecents() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRecentsKey);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
}
