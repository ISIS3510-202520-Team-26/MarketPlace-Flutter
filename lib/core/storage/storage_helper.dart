// lib/core/storage/storage_helper.dart
//
// Helper que combina CacheService y UserPreferencesService
// para casos de uso comunes en la aplicación.
//
import 'cache_service.dart';
import 'user_preferences_service.dart';

/// Helper class that combines both storage services for common use cases.
///
/// Provides high-level methods that abstract away the complexity of
/// managing cache and user preferences separately.
class StorageHelper {
  StorageHelper._();
  static final StorageHelper instance = StorageHelper._();

  final _cache = CacheService.instance;
  final _prefs = UserPreferencesService.instance;

  // ==================== Search Management ====================

  /// Performs a search and automatically saves it to recent searches.
  Future<void> recordSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _prefs.addRecentSearch(query.trim());
  }

  /// Gets recent searches and combines them with cached suggestions.
  Future<List<String>> getSearchSuggestions() async {
    final recents = await _prefs.getRecentSearches();
    final cached = await _cache.get('search_suggestions');

    if (cached != null && cached is List) {
      final suggestions = List<String>.from(cached);
      // Combine and deduplicate
      final combined = {...recents, ...suggestions}.toList();
      return combined.take(10).toList();
    }

    return recents;
  }

  /// Caches search results with automatic key generation.
  Future<void> cacheSearchResults({
    required String query,
    required List<Map<String, dynamic>> results,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final key = _generateSearchCacheKey(
      query: query,
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );

    await _cache.set(key, results, ttl: const Duration(minutes: 10));
  }

  /// Retrieves cached search results if available.
  Future<List<Map<String, dynamic>>?> getCachedSearchResults({
    required String query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final key = _generateSearchCacheKey(
      query: query,
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );

    final cached = await _cache.get(key);
    if (cached != null && cached is List) {
      return List<Map<String, dynamic>>.from(cached);
    }
    return null;
  }

  String _generateSearchCacheKey({
    required String query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
  }) {
    final parts = ['search', query.toLowerCase().replaceAll(' ', '_')];
    if (categoryId != null) parts.add('cat_$categoryId');
    if (minPrice != null) parts.add('min_${minPrice.toInt()}');
    if (maxPrice != null) parts.add('max_${maxPrice.toInt()}');
    return parts.join('_');
  }

  // ==================== Listings Management ====================

  /// Caches listings data with smart TTL based on data freshness.
  Future<void> cacheListings(
    List<Map<String, dynamic>> listings, {
    String key = 'listings_home',
    Duration? ttl,
  }) async {
    // Default TTL: 15 minutes for listings
    final effectiveTtl = ttl ?? const Duration(minutes: 15);
    await _cache.set(key, listings, ttl: effectiveTtl);
  }

  /// Gets cached listings if available and not expired.
  Future<List<Map<String, dynamic>>?> getCachedListings({
    String key = 'listings_home',
  }) async {
    final cached = await _cache.get(key);
    if (cached != null && cached is List) {
      return List<Map<String, dynamic>>.from(cached);
    }
    return null;
  }

  /// Invalidates all listing caches (use on refresh or after creating listing).
  Future<void> invalidateListingsCache() async {
    final keys = await _cache.getAllKeys();
    final listingKeys = keys.where((k) => k.startsWith('listings_') || k.startsWith('search_'));
    
    for (final key in listingKeys) {
      await _cache.remove(key);
    }
  }

  // ==================== Listing Detail Management ====================

  /// Cachea los detalles completos de un listing individual
  /// 
  /// [listingId] ID del listing
  /// [listingData] Datos completos del listing incluyendo fotos, marca, categoría
  /// [brandName] Nombre de la marca (opcional)
  /// [categoryName] Nombre de la categoría (opcional)
  /// [imageUrl] URL de la imagen principal (opcional)
  /// TTL: 30 minutos (los detalles pueden cambiar si el vendedor edita)
  Future<void> cacheListingDetail({
    required String listingId,
    required Map<String, dynamic> listingData,
    String? brandName,
    String? categoryName,
    String? imageUrl,
  }) async {
    final detailData = {
      ...listingData,
      'cached_brand_name': brandName,
      'cached_category_name': categoryName,
      'cached_image_url': imageUrl,
      'cached_at': DateTime.now().toIso8601String(),
    };
    
    await _cache.set(
      'listing_detail_$listingId',
      detailData,
      ttl: const Duration(minutes: 30),
    );
  }

  /// Obtiene los detalles cacheados de un listing
  /// 
  /// Retorna null si no existe en cache o está expirado
  Future<Map<String, dynamic>?> getCachedListingDetail(String listingId) async {
    final cached = await _cache.get('listing_detail_$listingId');
    if (cached != null && cached is Map) {
      return Map<String, dynamic>.from(cached);
    }
    return null;
  }

  /// Cachea múltiples detalles de listings (usado en Home para precarga)
  /// 
  /// [listingsDetails] Lista de detalles completos de listings
  /// Limpia los detalles cacheados previamente antes de guardar los nuevos
  Future<void> cacheMultipleListingDetails(
    List<Map<String, dynamic>> listingsDetails,
  ) async {
    // Primero, limpiar todos los detalles cacheados anteriormente
    await clearAllListingDetails();
    
    // Cachear cada listing individual
    for (final detail in listingsDetails) {
      final listingId = detail['id']?.toString() ?? detail['uuid']?.toString();
      if (listingId != null) {
        await cacheListingDetail(
          listingId: listingId,
          listingData: detail,
          brandName: detail['cached_brand_name']?.toString(),
          categoryName: detail['cached_category_name']?.toString(),
          imageUrl: detail['cached_image_url']?.toString(),
        );
      }
    }
    
    print('[StorageHelper] ✅ Cacheados ${listingsDetails.length} detalles de listings');
  }

  /// Limpia todos los detalles de listings cacheados
  /// 
  /// Se ejecuta antes de cachear nuevos detalles para evitar acumulación
  Future<void> clearAllListingDetails() async {
    final keys = await _cache.getAllKeys();
    final detailKeys = keys.where((k) => k.startsWith('listing_detail_'));
    
    for (final key in detailKeys) {
      await _cache.remove(key);
    }
    
    print('[StorageHelper] 🗑️ Limpiados ${detailKeys.length} detalles de listings del cache');
  }

  /// Verifica si existe un listing cacheado
  Future<bool> hasListingDetail(String listingId) async {
    return await _cache.has('listing_detail_$listingId');
  }

  // ==================== Category Management ====================

  /// Caches categories with long TTL (they don't change often).
  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    await _cache.set('categories', categories, ttl: const Duration(hours: 24));
  }

  /// Gets cached categories.
  Future<List<Map<String, dynamic>>?> getCachedCategories() async {
    final cached = await _cache.get('categories');
    if (cached != null && cached is List) {
      return List<Map<String, dynamic>>.from(cached);
    }
    return null;
  }

  /// Toggles a category as favorite and returns new state.
  Future<bool> toggleFavoriteCategory(String categoryId) async {
    final isFav = await _prefs.isFavoriteCategory(categoryId);
    if (isFav) {
      await _prefs.removeFavoriteCategory(categoryId);
      return false;
    } else {
      await _prefs.addFavoriteCategory(categoryId);
      return true;
    }
  }

  /// Gets favorite categories with their cached data.
  Future<List<Map<String, dynamic>>> getFavoriteCategoriesWithData() async {
    final favoriteIds = await _prefs.getFavoriteCategories();
    final allCategories = await getCachedCategories();
    
    if (allCategories == null) return [];

    return allCategories.where((cat) {
      final id = cat['id']?.toString() ?? cat['uuid']?.toString();
      return id != null && favoriteIds.contains(id);
    }).toList();
  }

  // ==================== Draft Management ====================

  /// Saves a listing draft automatically.
  Future<void> saveDraft({
    required String title,
    required String price,
    String? categoryId,
    String? brandId,
    String? description,
    String? condition,
    Map<String, dynamic>? location,
  }) async {
    final draft = {
      'title': title,
      'price': price,
      'categoryId': categoryId,
      'brandId': brandId,
      'description': description,
      'condition': condition,
      'location': location,
      'savedAt': DateTime.now().toIso8601String(),
    };

    // Save draft without expiration
    await _cache.set('listing_draft', draft);
  }

  /// Loads the saved draft.
  Future<Map<String, dynamic>?> loadDraft() async {
    final draft = await _cache.get('listing_draft');
    if (draft != null && draft is Map) {
      return Map<String, dynamic>.from(draft);
    }
    return null;
  }

  /// Checks if a draft exists.
  Future<bool> hasDraft() async {
    return await _cache.has('listing_draft');
  }

  /// Clears the draft after successful publication.
  Future<void> clearDraft() async {
    await _cache.remove('listing_draft');
  }

  // ==================== Filter Management ====================

  /// Gets default filter settings from user preferences.
  Future<FilterSettings> getDefaultFilters() async {
    final sortBy = await _prefs.getDefaultSortBy();
    final priceRange = await _prefs.getDefaultPriceRange();
    final conditions = await _prefs.getDefaultConditions();
    final radius = await _prefs.getDefaultRadius();
    final locationEnabled = await _prefs.isLocationEnabled();

    return FilterSettings(
      sortBy: sortBy,
      minPrice: priceRange?.min,
      maxPrice: priceRange?.max,
      conditions: conditions,
      radius: radius,
      locationEnabled: locationEnabled,
    );
  }

  /// Saves current filters as default.
  Future<void> saveFiltersAsDefault(FilterSettings settings) async {
    await _prefs.setDefaultSortBy(settings.sortBy);
    
    if (settings.minPrice != null || settings.maxPrice != null) {
      await _prefs.setDefaultPriceRange(
        min: settings.minPrice,
        max: settings.maxPrice,
      );
    }
    
    if (settings.conditions.isNotEmpty) {
      await _prefs.setDefaultConditions(settings.conditions);
    }
    
    if (settings.radius != null) {
      await _prefs.setDefaultRadius(settings.radius!);
    }
    
    await _prefs.setLocationEnabled(settings.locationEnabled);
  }

  // ==================== App Lifecycle Management ====================

  /// Initializes storage on app start.
  Future<void> initialize() async {
    // Clean expired cache entries
    await _cache.cleanExpired();
    
    // Could load initial preferences here
  }

  /// Cleans up storage on app termination.
  Future<void> cleanup() async {
    // Clean expired cache
    await _cache.cleanExpired();
    
    // Could perform other cleanup tasks
  }

  /// Performs logout cleanup.
  Future<void> clearOnLogout() async {
    // Clear all cache
    await _cache.clearAll();
    
    // Keep some preferences but clear sensitive ones
    await _prefs.clearRecentSearches();
    // Don't clear theme, language, etc.
  }

  /// Full reset (use for testing or account deletion).
  Future<void> fullReset() async {
    await _cache.clearAll();
    await _prefs.clearAll();
  }

  // ==================== Analytics & Diagnostics ====================

  /// Gets storage usage statistics.
  Future<StorageStats> getStorageStats() async {
    final cacheStats = await _cache.getStats();
    final recentSearches = await _prefs.getRecentSearches();
    final favoriteCategories = await _prefs.getFavoriteCategories();
    final hasDraft = await this.hasDraft();

    return StorageStats(
      cacheEntries: cacheStats.totalEntries,
      activeCacheEntries: cacheStats.activeEntries,
      expiredCacheEntries: cacheStats.expiredEntries,
      recentSearchCount: recentSearches.length,
      favoriteCategoryCount: favoriteCategories.length,
      hasDraft: hasDraft,
    );
  }

  /// Optimizes storage by removing expired and redundant data.
  Future<OptimizationResult> optimize() async {
    final removedCache = await _cache.cleanExpired();
    
    // Could add more optimization logic here
    // For example, trimming old searches beyond a certain date
    
    return OptimizationResult(
      removedCacheEntries: removedCache,
      success: true,
    );
  }

  // ==================== User Profile Management ====================

  /// Caches user profile data for offline access.
  /// 
  /// [userProfile] Use `user.toFullJson()` to cache complete profile data
  /// TTL: 7 days (profile data doesn't change frequently unless user updates it)
  Future<void> cacheUserProfile(Map<String, dynamic> userProfile) async {
    await _cache.set(
      'user_profile',
      userProfile,
      ttl: const Duration(days: 7),
    );
  }

  /// Gets cached user profile if available.
  /// 
  /// Returns null if no cached profile exists or if it has expired.
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    final cached = await _cache.get('user_profile');
    if (cached != null && cached is Map) {
      return Map<String, dynamic>.from(cached);
    }
    return null;
  }

  /// Checks if there's a cached user profile available.
  Future<bool> hasCachedUserProfile() async {
    return await _cache.has('user_profile');
  }

  /// Invalidates the cached user profile.
  /// 
  /// Use this after user updates their profile or logs out.
  Future<void> invalidateUserProfile() async {
    await _cache.remove('user_profile');
  }

  /// Gets the timestamp of when the profile was last cached.
  Future<DateTime?> getProfileCacheTimestamp() async {
    final ttl = await _cache.getRemainingTtl('user_profile');
    if (ttl == null) return null;
    
    // Calculate when it was cached (7 days - remaining TTL)
    final fullTtl = const Duration(days: 7);
    final elapsed = fullTtl - ttl;
    return DateTime.now().subtract(elapsed);
  }
}

/// Filter settings for listings.
class FilterSettings {
  final String sortBy;
  final double? minPrice;
  final double? maxPrice;
  final List<String> conditions;
  final double? radius;
  final bool locationEnabled;

  const FilterSettings({
    required this.sortBy,
    this.minPrice,
    this.maxPrice,
    this.conditions = const [],
    this.radius,
    this.locationEnabled = true,
  });

  FilterSettings copyWith({
    String? sortBy,
    double? minPrice,
    double? maxPrice,
    List<String>? conditions,
    double? radius,
    bool? locationEnabled,
  }) {
    return FilterSettings(
      sortBy: sortBy ?? this.sortBy,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      conditions: conditions ?? this.conditions,
      radius: radius ?? this.radius,
      locationEnabled: locationEnabled ?? this.locationEnabled,
    );
  }
}

/// Statistics about storage usage.
class StorageStats {
  final int cacheEntries;
  final int activeCacheEntries;
  final int expiredCacheEntries;
  final int recentSearchCount;
  final int favoriteCategoryCount;
  final bool hasDraft;

  const StorageStats({
    required this.cacheEntries,
    required this.activeCacheEntries,
    required this.expiredCacheEntries,
    required this.recentSearchCount,
    required this.favoriteCategoryCount,
    required this.hasDraft,
  });

  @override
  String toString() {
    return 'StorageStats(\n'
        '  cache: $cacheEntries (active: $activeCacheEntries, expired: $expiredCacheEntries)\n'
        '  searches: $recentSearchCount\n'
        '  favorites: $favoriteCategoryCount\n'
        '  draft: ${hasDraft ? "yes" : "no"}\n'
        ')';
  }
}

/// Result of storage optimization.
class OptimizationResult {
  final int removedCacheEntries;
  final bool success;

  const OptimizationResult({
    required this.removedCacheEntries,
    required this.success,
  });

  @override
  String toString() {
    return 'OptimizationResult(removed: $removedCacheEntries, success: $success)';
  }
}
