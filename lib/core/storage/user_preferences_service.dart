// lib/core/storage/user_preferences_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user preferences and app settings.
///
/// Stores user-specific configurations like:
/// - Theme preferences (dark/light mode)
/// - Language selection
/// - Search filters defaults
/// - Sorting preferences
/// - Notification settings
/// - UI customizations
///
/// All preferences are persisted using SharedPreferences.
class UserPreferencesService {
  UserPreferencesService._();
  static final UserPreferencesService instance = UserPreferencesService._();

  // Keys for preferences
  static const _kThemeMode = 'pref_theme_mode';
  static const _kLanguageCode = 'pref_language_code';
  static const _kDefaultSortBy = 'pref_default_sort_by';
  static const _kDefaultPriceMin = 'pref_default_price_min';
  static const _kDefaultPriceMax = 'pref_default_price_max';
  static const _kDefaultConditions = 'pref_default_conditions';
  static const _kDefaultRadius = 'pref_default_radius';
  static const _kLocationEnabled = 'pref_location_enabled';
  static const _kNotificationsEnabled = 'pref_notifications_enabled';
  static const _kSavedSearches = 'pref_saved_searches';
  static const _kFavoriteCategories = 'pref_favorite_categories';
  static const _kRecentSearches = 'pref_recent_searches';
  static const _kShowOnboarding = 'pref_show_onboarding';
  static const _kGridViewMode = 'pref_grid_view_mode';
  static const _kAutoPlayVideos = 'pref_auto_play_videos';
  static const _kImageQuality = 'pref_image_quality';
  static const _kMaxRecentSearches = 10;

  // ==================== Theme ====================

  /// Gets the user's theme mode preference.
  ///
  /// Returns 'system', 'light', or 'dark'. Defaults to 'system'.
  Future<String> getThemeMode() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kThemeMode) ?? 'system';
  }

  /// Sets the user's theme mode preference.
  Future<void> setThemeMode(String mode) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kThemeMode, mode);
  }

  // ==================== Language ====================

  /// Gets the user's language preference.
  ///
  /// Returns language code like 'en', 'es', etc. Returns null if not set (use system default).
  Future<String?> getLanguageCode() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLanguageCode);
  }

  /// Sets the user's language preference.
  Future<void> setLanguageCode(String code) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLanguageCode, code);
  }

  // ==================== Search Preferences ====================

  /// Gets default sort preference for listings.
  ///
  /// Returns 'recent', 'price_asc', 'price_desc', 'distance'. Defaults to 'recent'.
  Future<String> getDefaultSortBy() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kDefaultSortBy) ?? 'recent';
  }

  /// Sets default sort preference.
  Future<void> setDefaultSortBy(String sortBy) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDefaultSortBy, sortBy);
  }

  /// Gets default price range for filters.
  Future<PriceRange?> getDefaultPriceRange() async {
    final sp = await SharedPreferences.getInstance();
    final min = sp.getDouble(_kDefaultPriceMin);
    final max = sp.getDouble(_kDefaultPriceMax);
    if (min == null && max == null) return null;
    return PriceRange(min: min, max: max);
  }

  /// Sets default price range for filters.
  Future<void> setDefaultPriceRange({double? min, double? max}) async {
    final sp = await SharedPreferences.getInstance();
    if (min != null) {
      await sp.setDouble(_kDefaultPriceMin, min);
    } else {
      await sp.remove(_kDefaultPriceMin);
    }
    if (max != null) {
      await sp.setDouble(_kDefaultPriceMax, max);
    } else {
      await sp.remove(_kDefaultPriceMax);
    }
  }

  /// Gets default conditions filter (new, used, refurbished).
  Future<List<String>> getDefaultConditions() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kDefaultConditions);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  /// Sets default conditions filter.
  Future<void> setDefaultConditions(List<String> conditions) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDefaultConditions, jsonEncode(conditions));
  }

  /// Gets default search radius in kilometers.
  Future<double?> getDefaultRadius() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getDouble(_kDefaultRadius);
  }

  /// Sets default search radius.
  Future<void> setDefaultRadius(double radius) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kDefaultRadius, radius);
  }

  // ==================== Location & Notifications ====================

  /// Checks if location services are enabled by user preference.
  Future<bool> isLocationEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLocationEnabled) ?? true; // Default: enabled
  }

  /// Sets location services preference.
  Future<void> setLocationEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLocationEnabled, enabled);
  }

  /// Checks if notifications are enabled.
  Future<bool> areNotificationsEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kNotificationsEnabled) ?? true; // Default: enabled
  }

  /// Sets notification preference.
  Future<void> setNotificationsEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kNotificationsEnabled, enabled);
  }

  // ==================== Saved Searches ====================

  /// Gets all saved searches.
  Future<List<SavedSearch>> getSavedSearches() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSavedSearches);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => SavedSearch.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds a saved search.
  Future<void> addSavedSearch(SavedSearch search) async {
    final searches = await getSavedSearches();
    // Remove duplicate if exists
    searches.removeWhere((s) => s.query == search.query);
    searches.insert(0, search);
    await _saveSavedSearches(searches);
  }

  /// Removes a saved search.
  Future<void> removeSavedSearch(String query) async {
    final searches = await getSavedSearches();
    searches.removeWhere((s) => s.query == query);
    await _saveSavedSearches(searches);
  }

  Future<void> _saveSavedSearches(List<SavedSearch> searches) async {
    final sp = await SharedPreferences.getInstance();
    final json = searches.map((e) => e.toJson()).toList();
    await sp.setString(_kSavedSearches, jsonEncode(json));
  }

  // ==================== Recent Searches ====================

  /// Gets recent search queries.
  Future<List<String>> getRecentSearches() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRecentSearches);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  /// Adds a recent search query.
  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final searches = await getRecentSearches();
    // Remove duplicate if exists
    searches.remove(query);
    searches.insert(0, query);
    // Keep only last N searches
    if (searches.length > _kMaxRecentSearches) {
      searches.removeRange(_kMaxRecentSearches, searches.length);
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRecentSearches, jsonEncode(searches));
  }

  /// Clears all recent searches.
  Future<void> clearRecentSearches() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRecentSearches);
  }

  // ==================== Favorite Categories ====================

  /// Gets favorite category IDs.
  Future<List<String>> getFavoriteCategories() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kFavoriteCategories);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  /// Adds a category to favorites.
  Future<void> addFavoriteCategory(String categoryId) async {
    final favorites = await getFavoriteCategories();
    if (!favorites.contains(categoryId)) {
      favorites.add(categoryId);
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kFavoriteCategories, jsonEncode(favorites));
    }
  }

  /// Removes a category from favorites.
  Future<void> removeFavoriteCategory(String categoryId) async {
    final favorites = await getFavoriteCategories();
    favorites.remove(categoryId);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFavoriteCategories, jsonEncode(favorites));
  }

  /// Checks if a category is in favorites.
  Future<bool> isFavoriteCategory(String categoryId) async {
    final favorites = await getFavoriteCategories();
    return favorites.contains(categoryId);
  }

  // ==================== UI Preferences ====================

  /// Checks if onboarding should be shown.
  Future<bool> shouldShowOnboarding() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kShowOnboarding) ?? true; // Default: show
  }

  /// Marks onboarding as completed.
  Future<void> completeOnboarding() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kShowOnboarding, false);
  }

  /// Gets view mode for listings (grid or list).
  Future<String> getGridViewMode() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kGridViewMode) ?? 'grid'; // Default: grid
  }

  /// Sets view mode for listings.
  Future<void> setGridViewMode(String mode) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kGridViewMode, mode);
  }

  /// Checks if videos should auto-play.
  Future<bool> shouldAutoPlayVideos() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAutoPlayVideos) ?? false; // Default: disabled
  }

  /// Sets auto-play videos preference.
  Future<void> setAutoPlayVideos(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoPlayVideos, enabled);
  }

  /// Gets image quality preference.
  ///
  /// Returns 'low', 'medium', or 'high'. Defaults to 'medium'.
  Future<String> getImageQuality() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kImageQuality) ?? 'medium';
  }

  /// Sets image quality preference.
  Future<void> setImageQuality(String quality) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kImageQuality, quality);
  }

  // ==================== Reset ====================

  /// Clears all user preferences (useful for logout or reset).
  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    final keys = [
      _kThemeMode,
      _kLanguageCode,
      _kDefaultSortBy,
      _kDefaultPriceMin,
      _kDefaultPriceMax,
      _kDefaultConditions,
      _kDefaultRadius,
      _kLocationEnabled,
      _kNotificationsEnabled,
      _kSavedSearches,
      _kFavoriteCategories,
      _kRecentSearches,
      _kShowOnboarding,
      _kGridViewMode,
      _kAutoPlayVideos,
      _kImageQuality,
    ];
    for (final key in keys) {
      await sp.remove(key);
    }
  }
}

/// Represents a saved search with filters.
class SavedSearch {
  final String query;
  final String? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final List<String>? conditions;
  final DateTime savedAt;

  const SavedSearch({
    required this.query,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.conditions,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'categoryId': categoryId,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'conditions': conditions,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      query: json['query'] as String,
      categoryId: json['categoryId'] as String?,
      minPrice: json['minPrice'] as double?,
      maxPrice: json['maxPrice'] as double?,
      conditions: json['conditions'] != null
          ? List<String>.from(json['conditions'] as List)
          : null,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}

/// Represents a price range filter.
class PriceRange {
  final double? min;
  final double? max;

  const PriceRange({this.min, this.max});

  @override
  String toString() => 'PriceRange(min: $min, max: $max)';
}
