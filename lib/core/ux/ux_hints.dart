// lib/core/ux/ux_hints.dart
class UxHints {
  /// IDs de categoría recomendadas para ordenar chips (personales / recientes).
  final List<String> recommendedCategoryIds;

  /// Si true, auto-abrimos filtros tras N búsquedas sin filtros.
  final bool autoOpenFiltersAfterNPlainSearches;

  /// N búsquedas “planas” antes de abrir filtros.
  final int searchesWithoutFiltersThreshold;

  /// Si true, usar orden por distancia/cerca-de-mí por defecto.
  final bool defaultSortByDistance;

  /// Prioridad de CTAs según dwell (valores posibles: 'search', 'publish', 'auth').
  final List<String> ctaPriority;

  /// Banderas de conveniencia (compatibilidad con código existente).
  final bool highlightSearchCta;
  final bool highlightPublishCta;
  final bool highlightAuthCta;

  const UxHints({
    this.recommendedCategoryIds = const [],
    this.autoOpenFiltersAfterNPlainSearches = false,
    this.searchesWithoutFiltersThreshold = 2,
    this.defaultSortByDistance = false,
    this.ctaPriority = const [],
    this.highlightSearchCta = false,
    this.highlightPublishCta = false,
    this.highlightAuthCta = false,
  });

  Map<String, dynamic> toJson() => {
        'recommendedCategoryIds': recommendedCategoryIds,
        'autoOpenFiltersAfterNPlainSearches': autoOpenFiltersAfterNPlainSearches,
        'searchesWithoutFiltersThreshold': searchesWithoutFiltersThreshold,
        'defaultSortByDistance': defaultSortByDistance,
        'ctaPriority': ctaPriority,
        'highlightSearchCta': highlightSearchCta,
        'highlightPublishCta': highlightPublishCta,
        'highlightAuthCta': highlightAuthCta,
      };

  factory UxHints.fromJson(Map<String, dynamic> m) => UxHints(
        recommendedCategoryIds:
            (m['recommendedCategoryIds'] as List?)?.cast<String>() ?? const [],
        autoOpenFiltersAfterNPlainSearches:
            (m['autoOpenFiltersAfterNPlainSearches'] as bool?) ?? false,
        searchesWithoutFiltersThreshold:
            (m['searchesWithoutFiltersThreshold'] as int?) ?? 2,
        defaultSortByDistance:
            (m['defaultSortByDistance'] as bool?) ?? false,
        ctaPriority: (m['ctaPriority'] as List?)?.cast<String>() ?? const [],
        highlightSearchCta: (m['highlightSearchCta'] as bool?) ?? false,
        highlightPublishCta: (m['highlightPublishCta'] as bool?) ?? false,
        highlightAuthCta: (m['highlightAuthCta'] as bool?) ?? false,
      );
}
