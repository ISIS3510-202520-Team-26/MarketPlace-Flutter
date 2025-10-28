import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';
import '../models/event.dart';

/// Repository for managing telemetry events and analytics.
///
/// This is one of the most critical repositories as it handles:
/// - Event ingestion (telemetry tracking from the app)
/// - Analytics queries (business intelligence dashboards)
/// - Event batching for performance
/// - Integration with all other domains (listings, orders, chats, etc.)
///
/// Backend integration:
/// - POST /events - Ingest batch of telemetry events
/// - GET /analytics/bq/* - Various analytics queries for dashboards
class TelemetryRepository {
  final Dio _dio = DioClient.instance.dio;

  // Event buffer for batching
  final List<Map<String, dynamic>> _eventBuffer = [];
  static const _maxBufferSize = 10;
  static const _flushIntervalSeconds = 30;
  DateTime? _lastFlushTime;

  // Session tracking
  String? _currentSessionId;
  String? _currentScreen;

  // ============================================================================
  // Event Ingestion
  // ============================================================================

  /// Ingests a batch of events to the backend.
  ///
  /// Events are sent as a batch for efficiency. The backend automatically
  /// assigns the authenticated user_id to all events.
  ///
  /// Returns the IDs of inserted events (first 5 only).
  ///
  /// This endpoint returns 202 Accepted (fire-and-forget).
  Future<List<String>> ingestEvents(List<Event> events) async {
    if (events.isEmpty) return [];

    try {
      final response = await _dio.post(
        '/events',
        data: {
          'events': events.map((e) => e.toJson()).toList(),
        },
      );

      final data = response.data;
      final List<dynamic> ids = data['ids'] ?? [];
      return ids.map((id) => id.toString()).toList();
    } on DioException catch (e) {
      // Silently ignore errors - telemetry shouldn't break UX
      print('Failed to ingest events: ${e.message}');
      return [];
    }
  }

  /// Tracks a single event.
  ///
  /// The event is buffered and sent in batches for efficiency.
  /// Call [flush] to force send buffered events immediately.
  ///
  /// Common event types:
  /// - `screen.view` - User viewed a screen
  /// - `ui.click` - User clicked a button
  /// - `listing.viewed` - User viewed a listing
  /// - `search.performed` - User performed a search
  /// - `feature.used` - User used a feature
  /// - `error.occurred` - An error occurred
  Future<void> trackEvent({
    required String eventType,
    String? listingId,
    String? orderId,
    String? chatId,
    String? step,
    Map<String, dynamic>? properties,
    DateTime? occurredAt,
  }) async {
    final event = Event(
      id: '', // Backend assigns ID
      eventType: eventType,
      userId: null, // Backend assigns from auth token
      sessionId: _currentSessionId ?? 'unknown',
      listingId: listingId,
      orderId: orderId,
      chatId: chatId,
      step: step,
      properties: properties ?? {},
      occurredAt: occurredAt ?? DateTime.now(),
    );

    _eventBuffer.add(event.toJson());

    // Auto-flush if buffer is full or enough time has passed
    if (_eventBuffer.length >= _maxBufferSize ||
        (_lastFlushTime != null &&
            DateTime.now().difference(_lastFlushTime!) >
                const Duration(seconds: _flushIntervalSeconds))) {
      await flush();
    }
  }

  /// Flushes buffered events to the backend immediately.
  ///
  /// This is called automatically when the buffer is full or after
  /// [_flushIntervalSeconds], but you can call it manually when needed
  /// (e.g., before app goes to background).
  Future<void> flush() async {
    if (_eventBuffer.isEmpty) return;

    final eventsToSend = List<Map<String, dynamic>>.from(_eventBuffer);
    _eventBuffer.clear();
    _lastFlushTime = DateTime.now();

    final events = eventsToSend
        .map((json) => Event.fromJson(json))
        .toList();

    await ingestEvents(events);
  }

  /// Initializes a new session.
  ///
  /// Call this when the app starts or user logs in.
  /// The session ID will be included in all subsequent events.
  void startSession(String sessionId) {
    _currentSessionId = sessionId;
    trackEvent(
      eventType: 'session.started',
      properties: {'session_id': sessionId},
    );
  }

  /// Ends the current session.
  ///
  /// Call this when the app goes to background or user logs out.
  Future<void> endSession() async {
    if (_currentSessionId != null) {
      await trackEvent(
        eventType: 'session.ended',
        properties: {'session_id': _currentSessionId},
      );
      await flush();
      _currentSessionId = null;
    }
  }

  // ============================================================================
  // Common Event Helpers
  // ============================================================================

  /// Tracks a screen view event.
  ///
  /// Call this whenever a user navigates to a new screen.
  /// The backend uses this to calculate time spent per screen (BQ 2.4).
  Future<void> trackScreenView(String screenName) async {
    _currentScreen = screenName;
    await trackEvent(
      eventType: 'screen.view',
      properties: {'screen': screenName},
    );
  }

  /// Tracks a button click event.
  ///
  /// The backend uses this for click analytics (BQ 2.2).
  Future<void> trackClick(String buttonName) async {
    await trackEvent(
      eventType: 'ui.click',
      properties: {
        'button': buttonName,
        'screen': _currentScreen,
      },
    );
  }

  /// Tracks a listing view event.
  Future<void> trackListingView(String listingId) async {
    await trackEvent(
      eventType: 'listing.viewed',
      listingId: listingId,
    );
  }

  /// Tracks a search performed event.
  ///
  /// Note: The ListingsRepository already tracks searches automatically
  /// via the backend's search_with_telemetry service, so you typically
  /// don't need to call this manually.
  Future<void> trackSearch({
    String? query,
    String? categoryId,
    String? brandId,
    int? minPrice,
    int? maxPrice,
    int? resultsCount,
    int? durationMs,
  }) async {
    await trackEvent(
      eventType: 'search.performed',
      properties: {
        if (query != null) 'q': query,
        if (categoryId != null) 'category_id': categoryId,
        if (brandId != null) 'brand_id': brandId,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (resultsCount != null) 'total': resultsCount,
        if (durationMs != null) 'duration_ms': durationMs,
      },
    );
  }

  /// Tracks an error event.
  ///
  /// Call this when an error occurs in the app that you want to track.
  Future<void> trackError({
    required String errorType,
    required String message,
    String? stackTrace,
    String? screen,
  }) async {
    await trackEvent(
      eventType: 'error.occurred',
      properties: {
        'error_type': errorType,
        'message': message,
        if (stackTrace != null) 'stack_trace': stackTrace,
        if (screen != null) 'screen': screen ?? _currentScreen,
      },
    );
  }

  /// Tracks feature usage.
  ///
  /// Note: FeaturesRepository.registerFeatureUse() already does this,
  /// so you typically don't need to call this directly.
  Future<void> trackFeatureUse(String featureKey) async {
    await trackEvent(
      eventType: 'feature.used',
      properties: {'feature_key': featureKey},
    );
  }

  // ============================================================================
  // Analytics Queries (Business Intelligence)
  // ============================================================================

  // ---------- BQ 1.x: Listings & Escrow Analytics ----------

  /// BQ 1.1: Listings created per day by category.
  ///
  /// Returns daily listing creation counts grouped by category.
  /// Used for understanding listing volume trends.
  Future<List<ListingsPerDayByCategory>> getListingsPerDayByCategory({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/1_1',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => ListingsPerDayByCategory.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// BQ 1.2: Escrow cancellation rate by step.
  ///
  /// Returns cancellation statistics per escrow step.
  /// Used for identifying friction points in the escrow process.
  Future<List<EscrowCancelRate>> getEscrowCancelRate({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/1_2',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => EscrowCancelRate.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ---------- BQ 2.x: User Behavior Analytics ----------

  /// BQ 2.1: Events per type by day.
  ///
  /// Returns daily event counts grouped by event type.
  /// Used for understanding overall user activity patterns.
  Future<List<EventsPerTypeByDay>> getEventsPerTypeByDay({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/2_1',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => EventsPerTypeByDay.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// BQ 2.2: Clicks by button by day.
  ///
  /// Returns daily click counts grouped by button name.
  /// Used for understanding which UI elements users interact with most.
  Future<List<ClicksByButtonByDay>> getClicksByButtonByDay({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/2_2',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => ClicksByButtonByDay.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// BQ 2.4: Time spent per screen.
  ///
  /// Returns dwell time statistics per screen using screen.view events.
  /// Calculates time between consecutive screen views per session.
  ///
  /// [maxIdleSeconds]: Cap for time spent (default 300s = 5min).
  /// If no next screen view, assumes user left and caps at this value.
  Future<List<TimeByScreen>> getTimeByScreen({
    required DateTime start,
    required DateTime end,
    int maxIdleSeconds = 300,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/2_4',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
          'max_idle_sec': maxIdleSeconds,
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => TimeByScreen.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ---------- BQ 3.x: User Engagement Metrics ----------

  /// BQ 3.1: Daily Active Users (DAU).
  ///
  /// Returns count of unique users per day.
  /// Core metric for measuring app engagement.
  Future<List<DailyActiveUsers>> getDailyActiveUsers({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/3_1',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => DailyActiveUsers.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// BQ 3.2: Sessions per day.
  ///
  /// Returns count of unique sessions per day.
  /// Used with DAU to calculate sessions per user.
  Future<List<SessionsByDay>> getSessionsByDay({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/3_2',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => SessionsByDay.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ---------- BQ 4.x: Revenue & Orders Analytics ----------

  /// BQ 4.1: Orders by status by day.
  ///
  /// Returns daily order counts grouped by status.
  /// Used for monitoring order flow and conversion.
  Future<List<OrdersByStatusByDay>> getOrdersByStatusByDay({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/4_1',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => OrdersByStatusByDay.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// BQ 4.2: Gross Merchandise Value (GMV) by day.
  ///
  /// Returns daily revenue from paid/completed orders.
  /// Core metric for business performance.
  Future<List<GmvByDay>> getGmvByDay({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/4_2',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => GmvByDay.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ---------- BQ 5.x: Feature Usage Analytics ----------

  /// BQ 5.1: Quick view usage by category by day.
  ///
  /// Returns daily quick view feature usage grouped by listing category.
  /// Used for measuring feature adoption.
  Future<List<QuickViewByCategory>> getQuickViewByCategory({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/bq/5_1',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final List<dynamic> data = response.data;
      return data.map((json) => QuickViewByCategory.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
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
          return Exception('Analytics data not found: $message');
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
// Analytics Response Models
// ==============================================================================

/// BQ 1.1: Listings created per day by category
class ListingsPerDayByCategory {
  final String day;
  final String? categoryId;
  final int count;

  ListingsPerDayByCategory({
    required this.day,
    this.categoryId,
    required this.count,
  });

  factory ListingsPerDayByCategory.fromJson(Map<String, dynamic> json) {
    return ListingsPerDayByCategory(
      day: json['day'] as String,
      categoryId: json['category_id'] as String?,
      count: json['count'] as int,
    );
  }
}

/// BQ 1.2: Escrow cancellation rate by step
class EscrowCancelRate {
  final String step;
  final int total;
  final int cancelled;
  final double pctCancelled;

  EscrowCancelRate({
    required this.step,
    required this.total,
    required this.cancelled,
    required this.pctCancelled,
  });

  factory EscrowCancelRate.fromJson(Map<String, dynamic> json) {
    return EscrowCancelRate(
      step: json['step'] as String,
      total: json['total'] as int,
      cancelled: json['cancelled'] as int,
      pctCancelled: (json['pct_cancelled'] as num).toDouble(),
    );
  }
}

/// BQ 2.1: Events per type by day
class EventsPerTypeByDay {
  final String day;
  final String? eventType;
  final int count;

  EventsPerTypeByDay({
    required this.day,
    this.eventType,
    required this.count,
  });

  factory EventsPerTypeByDay.fromJson(Map<String, dynamic> json) {
    return EventsPerTypeByDay(
      day: json['day'] as String,
      eventType: json['event_type'] as String?,
      count: json['count'] as int,
    );
  }
}

/// BQ 2.2: Clicks by button by day
class ClicksByButtonByDay {
  final String day;
  final String? button;
  final int count;

  ClicksByButtonByDay({
    required this.day,
    this.button,
    required this.count,
  });

  factory ClicksByButtonByDay.fromJson(Map<String, dynamic> json) {
    return ClicksByButtonByDay(
      day: json['day'] as String,
      button: json['button'] as String?,
      count: json['count'] as int,
    );
  }
}

/// BQ 2.4: Time spent per screen
class TimeByScreen {
  final String? screen;
  final int totalSeconds;
  final int views;
  final int avgSeconds;

  TimeByScreen({
    this.screen,
    required this.totalSeconds,
    required this.views,
    required this.avgSeconds,
  });

  factory TimeByScreen.fromJson(Map<String, dynamic> json) {
    return TimeByScreen(
      screen: json['screen'] as String?,
      totalSeconds: json['total_seconds'] as int,
      views: json['views'] as int,
      avgSeconds: json['avg_seconds'] as int,
    );
  }

  /// Average time in minutes
  double get avgMinutes => avgSeconds / 60.0;

  /// Total time in minutes
  double get totalMinutes => totalSeconds / 60.0;
}

/// BQ 3.1: Daily Active Users
class DailyActiveUsers {
  final String day;
  final int dau;

  DailyActiveUsers({
    required this.day,
    required this.dau,
  });

  factory DailyActiveUsers.fromJson(Map<String, dynamic> json) {
    return DailyActiveUsers(
      day: json['day'] as String,
      dau: json['dau'] as int,
    );
  }
}

/// BQ 3.2: Sessions by day
class SessionsByDay {
  final String day;
  final int sessions;

  SessionsByDay({
    required this.day,
    required this.sessions,
  });

  factory SessionsByDay.fromJson(Map<String, dynamic> json) {
    return SessionsByDay(
      day: json['day'] as String,
      sessions: json['sessions'] as int,
    );
  }
}

/// BQ 4.1: Orders by status by day
class OrdersByStatusByDay {
  final String day;
  final String status;
  final int count;

  OrdersByStatusByDay({
    required this.day,
    required this.status,
    required this.count,
  });

  factory OrdersByStatusByDay.fromJson(Map<String, dynamic> json) {
    return OrdersByStatusByDay(
      day: json['day'] as String,
      status: json['status'] as String,
      count: json['count'] as int,
    );
  }
}

/// BQ 4.2: Gross Merchandise Value by day
class GmvByDay {
  final String day;
  final int gmvCents;
  final int ordersPaid;

  GmvByDay({
    required this.day,
    required this.gmvCents,
    required this.ordersPaid,
  });

  factory GmvByDay.fromJson(Map<String, dynamic> json) {
    return GmvByDay(
      day: json['day'] as String,
      gmvCents: json['gmv_cents'] as int,
      ordersPaid: json['orders_paid'] as int,
    );
  }

  /// GMV in dollars (or main currency unit)
  double get gmvDollars => gmvCents / 100.0;

  /// Average order value in dollars
  double get averageOrderValue =>
      ordersPaid > 0 ? gmvDollars / ordersPaid : 0.0;
}

/// BQ 5.1: Quick view usage by category by day
class QuickViewByCategory {
  final String day;
  final String? categoryId;
  final int count;

  QuickViewByCategory({
    required this.day,
    this.categoryId,
    required this.count,
  });

  factory QuickViewByCategory.fromJson(Map<String, dynamic> json) {
    return QuickViewByCategory(
      day: json['day'] as String,
      categoryId: json['category_id'] as String?,
      count: json['count'] as int,
    );
  }
}

// ==============================================================================
// Usage Examples
// ==============================================================================

/// Example usage for event tracking:
///
/// ```dart
/// final telemetry = TelemetryRepository();
///
/// // Initialize session at app start
/// telemetry.startSession('session-uuid-123');
///
/// // Track screen views
/// await telemetry.trackScreenView('home');
/// await telemetry.trackScreenView('listing_details');
///
/// // Track user interactions
/// await telemetry.trackClick('add_to_cart_button');
/// await telemetry.trackListingView('listing-id-456');
///
/// // Track errors
/// try {
///   // Some operation
/// } catch (e) {
///   await telemetry.trackError(
///     errorType: 'network_error',
///     message: e.toString(),
///     screen: 'checkout',
///   );
/// }
///
/// // Flush events before app goes to background
/// await telemetry.flush();
/// await telemetry.endSession();
/// ```
///
/// Example usage for analytics:
///
/// ```dart
/// final telemetry = TelemetryRepository();
///
/// // Get DAU for last 30 days
/// final dau = await telemetry.getDailyActiveUsers(
///   start: DateTime.now().subtract(Duration(days: 30)),
///   end: DateTime.now(),
/// );
///
/// // Get revenue metrics
/// final gmv = await telemetry.getGmvByDay(
///   start: DateTime.now().subtract(Duration(days: 7)),
///   end: DateTime.now(),
/// );
///
/// print('Total GMV: \$${gmv.fold(0.0, (sum, day) => sum + day.gmvDollars)}');
/// ```
