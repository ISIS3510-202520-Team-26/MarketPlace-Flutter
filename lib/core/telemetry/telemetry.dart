// lib/core/telemetry/telemetry.dart
import 'dart:async';
import '../../data/api/telemetry_api.dart';

class Telemetry {
  Telemetry._();
  static final Telemetry i = Telemetry._();

  final _api = TelemetryApi();
  final List<Map<String, dynamic>> _buf = [];
  Timer? _timer;

  static const int _maxBatch = 20;
  static const Duration _maxDelay = Duration(seconds: 2);

  void _enqueue(Map<String, dynamic> ev) {
    _buf.add(ev);
    _scheduleFlush();
    if (_buf.length >= _maxBatch) {
      _flush();
    }
  }

  void _scheduleFlush() {
    _timer?.cancel();
    _timer = Timer(_maxDelay, _flush);
  }

  Future<void> _flush() async {
    if (_buf.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_buf);
    _buf.clear();
    _timer?.cancel();
    _timer = null;

    try {
      await _api.sendBatch(batch);
    } catch (_) {
      // Best-effort: si falla, reinsertamos (limitamos para no crecer infinito)
      _buf.insertAll(0, batch.take(200));
    }
  }

  /// Forzar envío inmediato (por ejemplo, al cerrar sesión).
  Future<void> flush() => _flush();

  // ----------------- Eventos públicos -----------------

  /// Vista de pantalla
  void view(String screen, {Map<String, dynamic>? props}) {
    _enqueue({
      'event_type': 'screen.view',
      'properties': {
        'screen': screen,
        if (props != null) ...props,
      },
    });
  }

  /// Click genérico de UI
  void click(
    String button, {
    String? listingId,
    String? orderId,
    String? chatId,
    Map<String, dynamic>? props,
  }) {
    _enqueue({
      'event_type': 'ui.click',
      if (listingId != null) 'listing_id': listingId,
      if (orderId != null) 'order_id': orderId,
      if (chatId != null) 'chat_id': chatId,
      'properties': {
        'button': button,
        if (props != null) ...props,
      },
    });
  }

  /// Búsqueda ejecutada (para BQ 2.1)
  void searchPerformed({String? q, String? categoryId, int? results}) {
    _enqueue({
      'event_type': 'search.performed',
      'properties': {
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoryId != null) 'category_id': categoryId,
        if (results != null) 'results': results,
      },
    });
  }

  /// Filtro realmente aplicado (para BQ 2.2)
  /// filter: 'category' | 'brand' | 'price' | 'availability' | ...
  /// value: valor textual (p.ej. 'laptops' o '0-500k')
  void filterUsed({required String filter, String? value}) {
    _enqueue({
      'event_type': 'search.filter.used',
      'properties': {
        'filter': filter,
        if (value != null) 'value': value,
      },
    });
  }

  /// Paso de checkout (por si haces el funnel detallado)
  void checkoutStep(String step, {Map<String, dynamic>? props}) {
    _enqueue({
      'event_type': 'checkout.step',
      'step': step,
      'properties': props ?? const {},
    });
  }
}
