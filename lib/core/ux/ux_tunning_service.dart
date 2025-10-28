// lib/core/ux/ux_tunning_service.dart
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/telemetry_repository.dart';
import 'ux_hints.dart';

/// Service for UX tuning based on analytics data.
///
/// Uses TelemetryRepository to fetch analytics (BQ 2.1, 2.2, 2.4) and
/// computes personalized UX hints like:
/// - Recommended categories (based on local usage)
/// - Whether to auto-open filters (if users don't use them)
/// - Default sort by distance (if users toggle location often)
/// - CTA priority based on dwell time per screen
class UxTuningService {
  UxTuningService._();
  static final UxTuningService instance = UxTuningService._();

  final _telemetry = TelemetryRepository();

  static const _kCacheKey = 'ux_hints_cache_v1';
  static const _kRecentsKey = 'ux_recent_categories_v1';

  /// Loads UX hints based on analytics data from the last [window].
  ///
  /// Fetches BQ 2.1 (events per type), BQ 2.2 (clicks), and BQ 2.4 (dwell time)
  /// to compute intelligent hints. Results are cached in SharedPreferences.
  ///
  /// Falls back to cached hints if the network request fails.
  Future<UxHints> loadHints({Duration window = const Duration(hours: 24)}) async {
    final end = DateTime.now().toUtc();
    final start = end.subtract(window);

    try {
      // Fetch analytics data using TelemetryRepository
      final bq21 = await _telemetry.getEventsPerTypeByDay(start: start, end: end);
      final bq22 = await _telemetry.getClicksByButtonByDay(start: start, end: end);
      final bq24 = await _telemetry.getTimeByScreen(start: start, end: end);

      // Convert to maps for compatibility with existing _computeHints logic
      final bq21Maps = bq21.map((e) => {
        'event_type': e.eventType,
        'count': e.count,
      }).toList();

      final bq22Maps = bq22.map((e) => {
        'button': e.button,
        'count': e.count,
      }).toList();

      final bq24Maps = bq24.map((e) => {
        'screen': e.screen,
        'total_seconds': e.totalSeconds,
        'views': e.views,
        'avg_seconds': e.avgSeconds,
      }).toList();

      final hints = await _computeHints(bq21Maps, bq22Maps, bq24Maps);

      // Cache for offline use
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kCacheKey, jsonEncode(hints.toJson()));

      return hints;
    } catch (_) {
      // Fallback to cached hints
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
