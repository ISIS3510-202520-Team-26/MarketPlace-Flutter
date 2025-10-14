// lib/core/telemetry/telemetry.dart
import 'dart:async';

import '../../data/api/telemetry_api.dart';

/// Pequeño helper para encolar eventos y enviarlos en batch.
/// - No cambia el UI.
/// - Encola y hace flush periódico o cuando supera 20 elementos.
class Telemetry {
  Telemetry._();
  static final Telemetry i = Telemetry._();

  final TelemetryApi _api = TelemetryApi();

  final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];
  Timer? _timer;
  bool _sending = false;

  void _ensureTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => flush());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _enqueue(Map<String, dynamic> ev) {
    _queue.add(ev);
    if (_queue.length >= 20) {
      // umbral de envío inmediato
      unawaited();
    }
    _ensureTimer();
  }

  Future<void> flush() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      await _api.sendBatch(batch);
    } catch (_) {
      // Reencolar el batch fallido para reintento
      _queue.insertAll(0, batch);
    } finally {
      _sending = false;
    }
  }

  // --------- Eventos de conveniencia ---------

  /// ui.click con propiedades {button: <name>}
  void click(
    String button, {
    String? listingId,
    String? orderId,
    String? chatId,
    Map<String, dynamic>? props,
  }) {
    final p = <String, dynamic>{'button': button};
    if (props != null) p.addAll(props);

    final ev = <String, dynamic>{
      'event_type': 'ui.click',
      'properties': p,
    };
    if (listingId != null) ev['listing_id'] = listingId;
    if (orderId != null) ev['order_id'] = orderId;
    if (chatId != null) ev['chat_id'] = chatId;

    _enqueue(ev);
  }

  /// feature.used con propiedades {feature_key: <key>}
  void featureUsed(
    String featureKey, {
    String? listingId,
    Map<String, dynamic>? props,
  }) {
    final p = <String, dynamic>{'feature_key': featureKey};
    if (props != null) p.addAll(props);

    final ev = <String, dynamic>{
      'event_type': 'feature.used',
      'properties': p,
    };
    if (listingId != null) ev['listing_id'] = listingId;

    _enqueue(ev);
  }

  /// search.performed (BQ 2.x) – útil para búsquedas locales
  void searchPerformed({String? q, String? categoryId, int? results}) {
    final p = <String, dynamic>{};
    if (q != null) p['q'] = q;
    if (categoryId != null) p['category_id'] = categoryId;
    if (results != null) p['results'] = results;

    _enqueue(<String, dynamic>{
      'event_type': 'search.performed',
      'properties': p,
    });
  }

  /// screen.view (libre; útil para funnels)
  void view(String screen, {Map<String, dynamic>? props}) {
    final p = <String, dynamic>{'screen': screen};
    if (props != null) p.addAll(props);
    _enqueue(<String, dynamic>{
      'event_type': 'screen.view',
      'properties': p,
    });
  }
}

// ignore: avoid_classes_with_only_static_members
class unawaited {
  static void call(Future<void> f) {}
}
