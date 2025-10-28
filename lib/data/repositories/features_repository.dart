import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';
import '../models/feature.dart';

/// Repository for managing feature flags and feature usage tracking.
///
/// Handles:
/// - Feature flag retrieval (enabled/disabled features)
/// - Feature usage registration for analytics
/// - Client-side feature flag caching
///
/// Feature flags are used for:
/// - A/B testing
/// - Gradual feature rollouts
/// - Kill switches for problematic features
/// - Platform-specific features
///
/// Backend integration:
/// - GET /features - Get all feature flags (key -> enabled)
/// - POST /features/use - Register feature usage event
class FeaturesRepository {
  final Dio _dio = DioClient.instance.dio;

  // In-memory cache for feature flags
  Map<String, bool>? _flagsCache;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  // ============================================================================
  // Feature Flag Operations
  // ============================================================================

  /// Gets all feature flags from the backend.
  ///
  /// Returns a map of feature key to enabled status.
  /// Example: {'dark_mode': true, 'new_ui': false, 'chat': true}
  ///
  /// This endpoint is typically public (no auth required) so the app
  /// can check flags before login.
  ///
  /// Results are cached for [_cacheDuration] to reduce API calls.
  Future<Map<String, bool>> getFeatureFlags({bool forceRefresh = false}) async {
    // Return cached flags if still valid
    if (!forceRefresh &&
        _flagsCache != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return Map.from(_flagsCache!);
    }

    try {
      final response = await _dio.get('/features');

      // Backend returns { "feature_key": true/false, ... }
      final Map<String, dynamic> data = response.data;
      _flagsCache = data.map((key, value) => MapEntry(key, value as bool));
      _cacheTimestamp = DateTime.now();

      return Map.from(_flagsCache!);
    } on DioException catch (e) {
      // If request fails but we have cached flags, return them
      if (_flagsCache != null) {
        return Map.from(_flagsCache!);
      }
      throw _handleError(e);
    }
  }

  /// Checks if a specific feature is enabled.
  ///
  /// Returns true if the feature is enabled, false otherwise.
  /// If the feature key doesn't exist, returns [defaultValue] (false by default).
  ///
  /// This is the main method to use in your UI code:
  /// ```dart
  /// if (await featuresRepo.isFeatureEnabled('new_chat_ui')) {
  ///   // Show new chat UI
  /// }
  /// ```
  Future<bool> isFeatureEnabled(
    String featureKey, {
    bool defaultValue = false,
  }) async {
    final flags = await getFeatureFlags();
    return flags[featureKey] ?? defaultValue;
  }

  /// Checks multiple features at once.
  ///
  /// Returns a map of feature key to enabled status.
  /// Useful for checking multiple features in one call.
  Future<Map<String, bool>> checkFeatures(List<String> featureKeys) async {
    final allFlags = await getFeatureFlags();
    return {
      for (var key in featureKeys) key: allFlags[key] ?? false,
    };
  }

  /// Gets a specific feature flag object with metadata.
  ///
  /// Note: The current backend only returns a simple key->bool map.
  /// This method is a placeholder for future enhancement where features
  /// might include metadata like description, rollout percentage, etc.
  Future<Feature?> getFeature(String featureKey) async {
    final flags = await getFeatureFlags();
    final isEnabled = flags[featureKey];

    if (isEnabled == null) return null;

    // For now, create a simple Feature object
    // In the future, backend might return full Feature objects
    return Feature(
      id: featureKey,
      key: featureKey,
      name: featureKey, // Using key as name for now
      deployedAt: isEnabled ? DateTime.now() : null,
    );
  }

  /// Clears the feature flags cache.
  ///
  /// Forces the next [getFeatureFlags] call to fetch from the backend.
  /// Useful after login or when you suspect flags might have changed.
  void clearCache() {
    _flagsCache = null;
    _cacheTimestamp = null;
  }

  // ============================================================================
  // Feature Usage Tracking
  // ============================================================================

  /// Registers that a user has used a feature.
  ///
  /// This is used for analytics to track feature adoption and usage patterns.
  /// The backend records this as a FeatureFlag entry with user and timestamp.
  ///
  /// Call this when a user:
  /// - Opens a feature for the first time
  /// - Uses a key feature action
  /// - Completes a feature flow
  ///
  /// Examples:
  /// ```dart
  /// await featuresRepo.registerFeatureUse('chat'); // User opened chat
  /// await featuresRepo.registerFeatureUse('listing_created'); // Created listing
  /// await featuresRepo.registerFeatureUse('payment_completed'); // Completed payment
  /// ```
  ///
  /// This endpoint returns 202 Accepted (fire-and-forget).
  /// Failures are silently ignored to not disrupt user experience.
  Future<void> registerFeatureUse(String featureKey) async {
    try {
      await _dio.post(
        '/features/use',
        data: {
          'feature_key': featureKey,
        },
      );
    } on DioException catch (e) {
      // Silently ignore errors - feature tracking shouldn't break UX
      // You might want to log this for debugging though
      print('Failed to register feature use: ${e.message}');
    }
  }

  /// Registers multiple feature uses at once.
  ///
  /// Convenience method for tracking multiple features.
  /// Each feature use is registered independently.
  Future<void> registerFeatureUses(List<String> featureKeys) async {
    // Fire all requests in parallel since they're independent
    await Future.wait(
      featureKeys.map((key) => registerFeatureUse(key)),
    );
  }

  // ============================================================================
  // Convenience Methods
  // ============================================================================

  /// Gets all enabled features.
  ///
  /// Returns a list of feature keys that are currently enabled.
  Future<List<String>> getEnabledFeatures() async {
    final flags = await getFeatureFlags();
    return flags.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Gets all disabled features.
  ///
  /// Returns a list of feature keys that are currently disabled.
  Future<List<String>> getDisabledFeatures() async {
    final flags = await getFeatureFlags();
    return flags.entries
        .where((entry) => entry.value == false)
        .map((entry) => entry.key)
        .toList();
  }

  /// Checks if all specified features are enabled.
  ///
  /// Returns true only if ALL features in the list are enabled.
  /// Useful for features that depend on multiple flags.
  Future<bool> areAllFeaturesEnabled(List<String> featureKeys) async {
    final flags = await getFeatureFlags();
    return featureKeys.every((key) => flags[key] == true);
  }

  /// Checks if any of the specified features are enabled.
  ///
  /// Returns true if at least ONE feature in the list is enabled.
  Future<bool> isAnyFeatureEnabled(List<String> featureKeys) async {
    final flags = await getFeatureFlags();
    return featureKeys.any((key) => flags[key] == true);
  }

  // ============================================================================
  // Error Handling
  // ============================================================================

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final message = e.response!.data?['detail'] ?? e.message;

      switch (statusCode) {
        case 400:
          return Exception('Invalid request: $message');
        case 401:
          return Exception('Unauthorized. Please login again.');
        case 404:
          return Exception('Feature not found: $message');
        case 500:
          return Exception('Server error. Please try again later.');
        default:
          return Exception('Error ($statusCode): $message');
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please check your internet.');
    }

    return Exception('Network error: ${e.message}');
  }
}

// ==============================================================================
// Usage Examples
// ==============================================================================

/// Example usage in your app:
///
/// ```dart
/// // At app startup, load feature flags
/// final featuresRepo = FeaturesRepository();
/// await featuresRepo.getFeatureFlags();
///
/// // Check individual feature
/// if (await featuresRepo.isFeatureEnabled('new_chat_ui')) {
///   // Navigate to new chat screen
/// } else {
///   // Navigate to old chat screen
/// }
///
/// // Track feature usage
/// await featuresRepo.registerFeatureUse('chat_opened');
///
/// // Check multiple features
/// final features = await featuresRepo.checkFeatures([
///   'dark_mode',
///   'push_notifications',
///   'location_services',
/// ]);
///
/// // Get all enabled features
/// final enabled = await featuresRepo.getEnabledFeatures();
/// print('Enabled features: $enabled');
/// ```
