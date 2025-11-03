// lib/core/storage/cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching API responses and data in local storage.
///
/// Provides a simple key-value cache with TTL (time-to-live) support.
/// Useful for offline mode and reducing API calls.
///
/// Example usage:
/// ```dart
/// final cache = CacheService.instance;
/// await cache.set('listings', listingsData, ttl: Duration(minutes: 30));
/// final cached = await cache.get('listings');
/// ```
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const _kPrefix = 'cache_';
  static const _kTimestampSuffix = '_ts';

  /// Stores data in cache with an optional time-to-live.
  ///
  /// [key]: Unique identifier for the cached data
  /// [value]: Data to cache (will be JSON encoded)
  /// [ttl]: Time-to-live duration. If null, cache never expires.
  Future<void> set(String key, dynamic value, {Duration? ttl}) async {
    final sp = await SharedPreferences.getInstance();
    final cacheKey = _kPrefix + key;
    final timestampKey = cacheKey + _kTimestampSuffix;

    // Store the value
    await sp.setString(cacheKey, jsonEncode(value));

    // Store the timestamp if TTL is specified
    if (ttl != null) {
      final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
      await sp.setInt(timestampKey, expiresAt);
    } else {
      // Remove timestamp if no TTL (永久缓存)
      await sp.remove(timestampKey);
    }
  }

  /// Retrieves data from cache.
  ///
  /// Returns null if:
  /// - Key doesn't exist
  /// - Data has expired (based on TTL)
  /// - Data is corrupted
  Future<dynamic> get(String key) async {
    final sp = await SharedPreferences.getInstance();
    final cacheKey = _kPrefix + key;
    final timestampKey = cacheKey + _kTimestampSuffix;

    // Check if cache exists
    final raw = sp.getString(cacheKey);
    if (raw == null) return null;

    // Check if cache has expired
    final expiresAt = sp.getInt(timestampKey);
    if (expiresAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > expiresAt) {
        // Cache expired, remove it
        await sp.remove(cacheKey);
        await sp.remove(timestampKey);
        return null;
      }
    }

    try {
      return jsonDecode(raw);
    } catch (e) {
      // Corrupted data, remove it
      await sp.remove(cacheKey);
      await sp.remove(timestampKey);
      return null;
    }
  }

  /// Gets a typed value from cache.
  ///
  /// Returns null if cache miss or type mismatch.
  Future<T?> getTyped<T>(String key) async {
    final value = await get(key);
    return value is T ? value : null;
  }

  /// Checks if a key exists and is not expired.
  Future<bool> has(String key) async {
    final value = await get(key);
    return value != null;
  }

  /// Removes a specific cache entry.
  Future<void> remove(String key) async {
    final sp = await SharedPreferences.getInstance();
    final cacheKey = _kPrefix + key;
    final timestampKey = cacheKey + _kTimestampSuffix;

    await sp.remove(cacheKey);
    await sp.remove(timestampKey);
  }

  /// Clears all cache entries (doesn't affect other SharedPreferences data).
  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys();
    final cacheKeys = keys.where((k) => k.startsWith(_kPrefix));

    for (final key in cacheKeys) {
      await sp.remove(key);
    }
  }

  /// Gets all cache keys (without the prefix).
  Future<List<String>> getAllKeys() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys();
    return keys
        .where((k) => k.startsWith(_kPrefix) && !k.endsWith(_kTimestampSuffix))
        .map((k) => k.substring(_kPrefix.length))
        .toList();
  }

  /// Gets cache statistics (total entries, expired entries).
  Future<CacheStats> getStats() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys();
    final cacheKeys = keys
        .where((k) => k.startsWith(_kPrefix) && !k.endsWith(_kTimestampSuffix))
        .toList();

    int total = cacheKeys.length;
    int expired = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final key in cacheKeys) {
      final timestampKey = key + _kTimestampSuffix;
      final expiresAt = sp.getInt(timestampKey);
      if (expiresAt != null && now > expiresAt) {
        expired++;
      }
    }

    return CacheStats(
      totalEntries: total,
      expiredEntries: expired,
      activeEntries: total - expired,
    );
  }

  /// Removes all expired cache entries.
  Future<int> cleanExpired() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys();
    final cacheKeys = keys
        .where((k) => k.startsWith(_kPrefix) && !k.endsWith(_kTimestampSuffix))
        .toList();

    int removed = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final key in cacheKeys) {
      final timestampKey = key + _kTimestampSuffix;
      final expiresAt = sp.getInt(timestampKey);
      if (expiresAt != null && now > expiresAt) {
        await sp.remove(key);
        await sp.remove(timestampKey);
        removed++;
      }
    }

    return removed;
  }

  /// Updates the TTL of an existing cache entry without changing its value.
  Future<bool> updateTtl(String key, Duration ttl) async {
    final sp = await SharedPreferences.getInstance();
    final cacheKey = _kPrefix + key;
    final timestampKey = cacheKey + _kTimestampSuffix;

    // Check if cache exists
    if (!sp.containsKey(cacheKey)) return false;

    final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await sp.setInt(timestampKey, expiresAt);
    return true;
  }

  /// Gets the remaining TTL for a cache entry.
  ///
  /// Returns null if:
  /// - Entry doesn't exist
  /// - Entry has no TTL (permanent cache)
  /// - Entry has expired
  Future<Duration?> getRemainingTtl(String key) async {
    final sp = await SharedPreferences.getInstance();
    final cacheKey = _kPrefix + key;
    final timestampKey = cacheKey + _kTimestampSuffix;

    if (!sp.containsKey(cacheKey)) return null;

    final expiresAt = sp.getInt(timestampKey);
    if (expiresAt == null) return null; // No TTL

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > expiresAt) return null; // Expired

    return Duration(milliseconds: expiresAt - now);
  }
}

/// Statistics about the cache state.
class CacheStats {
  final int totalEntries;
  final int expiredEntries;
  final int activeEntries;

  const CacheStats({
    required this.totalEntries,
    required this.expiredEntries,
    required this.activeEntries,
  });

  @override
  String toString() {
    return 'CacheStats(total: $totalEntries, expired: $expiredEntries, active: $activeEntries)';
  }
}
