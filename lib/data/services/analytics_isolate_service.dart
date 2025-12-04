import 'dart:isolate';
import 'package:dio/dio.dart';
import '../../core/net/dio_client.dart';

/// ============================================================================
/// SP4: SERVICIO DE ANALYTICS CON ISOLATES
/// ============================================================================
/// 
/// Este servicio implementa Isolates de Dart para procesar datos pesados
/// de analytics del Backend sin bloquear la UI principal.
/// 
/// Casos de uso:
/// - Procesamiento de grandes volumenes de datos de analytics
/// - Calculos agregados complejos (promedios, tendencias, conversiones)
/// - Transformaciones de datos en background
/// 
/// Isolates implementados:
/// 1. processOrdersAnalyticsInIsolate() - BQ 4.1 con calculos pesados
/// 2. processListingsAnalyticsInIsolate() - BQ 1.1 con agregaciones
/// 3. processEventsAnalyticsInIsolate() - BQ 2.1 con filtros complejos
/// 4. calculateGMVTrendsInIsolate() - BQ 4.2 con calculos de tendencias
/// ============================================================================

/// Modelo para datos de ordenes por status (BQ 4.1)
class OrdersAnalyticsData {
  final String day;
  final String status;
  final int count;

  OrdersAnalyticsData({
    required this.day,
    required this.status,
    required this.count,
  });

  factory OrdersAnalyticsData.fromJson(Map<String, dynamic> json) {
    return OrdersAnalyticsData(
      day: json['day'] as String,
      status: json['status'] as String,
      count: json['count'] as int,
    );
  }
}

/// Modelo para resultado procesado de ordenes
class ProcessedOrdersAnalytics {
  final int totalOrders;
  final Map<String, int> ordersByStatus;
  final double conversionRate;
  final double cancellationRate;
  final List<OrdersAnalyticsData> dailyTrends;

  ProcessedOrdersAnalytics({
    required this.totalOrders,
    required this.ordersByStatus,
    required this.conversionRate,
    required this.cancellationRate,
    required this.dailyTrends,
  });
}

/// Modelo para datos de listings (BQ 1.1)
class ListingsAnalyticsData {
  final String day;
  final String? categoryId;
  final int count;

  ListingsAnalyticsData({
    required this.day,
    this.categoryId,
    required this.count,
  });

  factory ListingsAnalyticsData.fromJson(Map<String, dynamic> json) {
    return ListingsAnalyticsData(
      day: json['day'] as String,
      categoryId: json['category_id'] as String?,
      count: json['count'] as int,
    );
  }
}

/// Modelo para resultado procesado de listings
class ProcessedListingsAnalytics {
  final int totalListings;
  final Map<String, int> listingsByCategory;
  final String topCategory;
  final double averageListingsPerDay;

  ProcessedListingsAnalytics({
    required this.totalListings,
    required this.listingsByCategory,
    required this.topCategory,
    required this.averageListingsPerDay,
  });
}

/// Modelo para datos de eventos (BQ 2.1)
class EventsAnalyticsData {
  final String day;
  final String? eventType;
  final int count;

  EventsAnalyticsData({
    required this.day,
    this.eventType,
    required this.count,
  });

  factory EventsAnalyticsData.fromJson(Map<String, dynamic> json) {
    return EventsAnalyticsData(
      day: json['day'] as String,
      eventType: json['event_type'] as String?,
      count: json['count'] as int,
    );
  }
}

/// Modelo para resultado procesado de eventos
class ProcessedEventsAnalytics {
  final int totalEvents;
  final Map<String, int> eventsByType;
  final String mostFrequentEvent;
  final double averageEventsPerDay;

  ProcessedEventsAnalytics({
    required this.totalEvents,
    required this.eventsByType,
    required this.mostFrequentEvent,
    required this.averageEventsPerDay,
  });
}

/// Modelo para datos de GMV (BQ 4.2)
class GMVAnalyticsData {
  final String day;
  final int gmvCents;
  final int ordersPaid;

  GMVAnalyticsData({
    required this.day,
    required this.gmvCents,
    required this.ordersPaid,
  });

  factory GMVAnalyticsData.fromJson(Map<String, dynamic> json) {
    return GMVAnalyticsData(
      day: json['day'] as String,
      gmvCents: json['gmv_cents'] as int,
      ordersPaid: json['orders_paid'] as int,
    );
  }
}

/// Modelo para resultado procesado de GMV
class ProcessedGMVAnalytics {
  final double totalGMV;
  final int totalOrdersPaid;
  final double averageOrderValue;
  final double dailyGrowthRate;
  final List<GMVAnalyticsData> trends;

  ProcessedGMVAnalytics({
    required this.totalGMV,
    required this.totalOrdersPaid,
    required this.averageOrderValue,
    required this.dailyGrowthRate,
    required this.trends,
  });
}

/// Servicio principal de Analytics con Isolates
class AnalyticsIsolateService {
  final Dio _dio = DioClient.instance.dio;

  // ============================================================================
  // SP4: ISOLATE 1 - PROCESAMIENTO DE ORDENES (BQ 4.1)
  // ============================================================================
  
  /// Procesa datos de ordenes por status usando ISOLATE
  /// 
  /// GET /analytics/bq/4_1
  /// 
  /// SP4 ISOLATE: Este metodo descarga datos del Backend y luego los procesa
  /// en un Isolate separado para no bloquear la UI.
  /// 
  /// Procesamiento pesado incluye:
  /// - Calculo de totales por status
  /// - Tasa de conversion (completed / total)
  /// - Tasa de cancelacion (cancelled / total)
  /// - Tendencias diarias
  Future<ProcessedOrdersAnalytics> processOrdersAnalyticsInIsolate({
    required String startDate,
    required String endDate,
  }) async {
    try {
      // SP4: Paso 1 - Descargar datos del Backend (main isolate)
      print('SP4 ISOLATE: Descargando datos de ordenes desde Backend...');
      
      final response = await _dio.get(
        '/analytics/bq/4_1',
        queryParameters: {
          'start': startDate,
          'end': endDate,
        },
      );

      final List<dynamic> jsonData = response.data as List<dynamic>;
      
      print('SP4 ISOLATE: ${jsonData.length} registros descargados. Iniciando procesamiento en Isolate...');

      // SP4: Paso 2 - Procesar datos en Isolate separado (background)
      // CRITICAL: Spawn new isolate para procesamiento pesado
      final result = await Isolate.run(() {
        // SP4 ISOLATE WORKER: Este codigo se ejecuta en un Isolate separado
        print('SP4 ISOLATE WORKER: Procesando ${jsonData.length} ordenes en background...');
        
        // Parsear datos
        final orders = jsonData
            .map((json) => OrdersAnalyticsData.fromJson(json as Map<String, dynamic>))
            .toList();

        // Calculos pesados
        int total = 0;
        final Map<String, int> byStatus = {};
        
        for (final order in orders) {
          total += order.count;
          byStatus[order.status] = (byStatus[order.status] ?? 0) + order.count;
        }

        // Calcular tasas
        final completed = byStatus['completed'] ?? 0;
        final cancelled = byStatus['cancelled'] ?? 0;
        
        final conversionRate = total > 0 ? (completed / total) * 100 : 0.0;
        final cancellationRate = total > 0 ? (cancelled / total) * 100 : 0.0;

        print('SP4 ISOLATE WORKER: Procesamiento completado. Total: $total ordenes');

        return ProcessedOrdersAnalytics(
          totalOrders: total,
          ordersByStatus: byStatus,
          conversionRate: conversionRate,
          cancellationRate: cancellationRate,
          dailyTrends: orders,
        );
      });

      print('SP4 ISOLATE: Datos procesados exitosamente en background');
      return result;
    } catch (e) {
      print('SP4 ISOLATE ERROR: $e');
      throw Exception('Error procesando analytics de ordenes: $e');
    }
  }

  // ============================================================================
  // SP4: ISOLATE 2 - PROCESAMIENTO DE LISTINGS (BQ 1.1)
  // ============================================================================
  
  /// Procesa datos de listings por categoria usando ISOLATE
  /// 
  /// GET /analytics/bq/1_1
  /// 
  /// SP4 ISOLATE: Descarga y procesa datos de listings en background
  /// 
  /// Procesamiento pesado:
  /// - Agregacion por categoria
  /// - Identificacion de categoria mas popular
  /// - Calculo de promedios diarios
  Future<ProcessedListingsAnalytics> processListingsAnalyticsInIsolate({
    required String startDate,
    required String endDate,
  }) async {
    try {
      // SP4: Descargar datos (main isolate)
      print('SP4 ISOLATE: Descargando datos de listings desde Backend...');
      
      final response = await _dio.get(
        '/analytics/bq/1_1',
        queryParameters: {
          'start': startDate,
          'end': endDate,
        },
      );

      final List<dynamic> jsonData = response.data as List<dynamic>;
      
      print('SP4 ISOLATE: ${jsonData.length} registros descargados. Procesando en Isolate...');

      // SP4: Procesar en Isolate separado
      final result = await Isolate.run(() {
        // SP4 ISOLATE WORKER: Background processing
        print('SP4 ISOLATE WORKER: Procesando listings en background...');
        
        final listings = jsonData
            .map((json) => ListingsAnalyticsData.fromJson(json as Map<String, dynamic>))
            .toList();

        int total = 0;
        final Map<String, int> byCategory = {};
        final Set<String> days = {};
        
        for (final listing in listings) {
          total += listing.count;
          final category = listing.categoryId ?? 'uncategorized';
          byCategory[category] = (byCategory[category] ?? 0) + listing.count;
          days.add(listing.day);
        }

        // Identificar top category
        String topCategory = 'none';
        int maxCount = 0;
        byCategory.forEach((category, count) {
          if (count > maxCount) {
            maxCount = count;
            topCategory = category;
          }
        });

        final averagePerDay = days.isNotEmpty ? total / days.length : 0.0;

        print('SP4 ISOLATE WORKER: Procesamiento completado. Total: $total listings');

        return ProcessedListingsAnalytics(
          totalListings: total,
          listingsByCategory: byCategory,
          topCategory: topCategory,
          averageListingsPerDay: averagePerDay,
        );
      });

      print('SP4 ISOLATE: Datos de listings procesados exitosamente');
      return result;
    } catch (e) {
      print('SP4 ISOLATE ERROR: $e');
      throw Exception('Error procesando analytics de listings: $e');
    }
  }

  // ============================================================================
  // SP4: ISOLATE 3 - PROCESAMIENTO DE EVENTOS (BQ 2.1)
  // ============================================================================
  
  /// Procesa datos de eventos por tipo usando ISOLATE
  /// 
  /// GET /analytics/bq/2_1
  /// 
  /// SP4 ISOLATE: Procesa eventos de telemetria en background
  /// 
  /// Procesamiento:
  /// - Agregacion por tipo de evento
  /// - Evento mas frecuente
  /// - Promedios diarios
  Future<ProcessedEventsAnalytics> processEventsAnalyticsInIsolate({
    required String startDate,
    required String endDate,
  }) async {
    try {
      // SP4: Descargar datos
      print('SP4 ISOLATE: Descargando datos de eventos desde Backend...');
      
      final response = await _dio.get(
        '/analytics/bq/2_1',
        queryParameters: {
          'start': startDate,
          'end': endDate,
        },
      );

      final List<dynamic> jsonData = response.data as List<dynamic>;
      
      print('SP4 ISOLATE: ${jsonData.length} registros de eventos. Procesando en Isolate...');

      // SP4: Procesar en Isolate
      final result = await Isolate.run(() {
        // SP4 ISOLATE WORKER: Background event processing
        print('SP4 ISOLATE WORKER: Procesando eventos en background...');
        
        final events = jsonData
            .map((json) => EventsAnalyticsData.fromJson(json as Map<String, dynamic>))
            .toList();

        int total = 0;
        final Map<String, int> byType = {};
        final Set<String> days = {};
        
        for (final event in events) {
          total += event.count;
          final type = event.eventType ?? 'unknown';
          byType[type] = (byType[type] ?? 0) + event.count;
          days.add(event.day);
        }

        // Evento mas frecuente
        String mostFrequent = 'none';
        int maxCount = 0;
        byType.forEach((type, count) {
          if (count > maxCount) {
            maxCount = count;
            mostFrequent = type;
          }
        });

        final averagePerDay = days.isNotEmpty ? total / days.length : 0.0;

        print('SP4 ISOLATE WORKER: $total eventos procesados');

        return ProcessedEventsAnalytics(
          totalEvents: total,
          eventsByType: byType,
          mostFrequentEvent: mostFrequent,
          averageEventsPerDay: averagePerDay,
        );
      });

      print('SP4 ISOLATE: Eventos procesados exitosamente');
      return result;
    } catch (e) {
      print('SP4 ISOLATE ERROR: $e');
      throw Exception('Error procesando analytics de eventos: $e');
    }
  }

  // ============================================================================
  // SP4: ISOLATE 4 - CALCULO DE TENDENCIAS GMV (BQ 4.2)
  // ============================================================================
  
  /// Calcula tendencias de GMV (Gross Merchandise Value) usando ISOLATE
  /// 
  /// GET /analytics/bq/4_2
  /// 
  /// SP4 ISOLATE: Procesamiento complejo de revenue en background
  /// 
  /// Calculos pesados:
  /// - GMV total
  /// - Valor promedio de orden
  /// - Tasa de crecimiento diaria
  /// - Tendencias temporales
  Future<ProcessedGMVAnalytics> calculateGMVTrendsInIsolate({
    required String startDate,
    required String endDate,
  }) async {
    try {
      // SP4: Descargar datos
      print('SP4 ISOLATE: Descargando datos de GMV desde Backend...');
      
      final response = await _dio.get(
        '/analytics/bq/4_2',
        queryParameters: {
          'start': startDate,
          'end': endDate,
        },
      );

      final List<dynamic> jsonData = response.data as List<dynamic>;
      
      print('SP4 ISOLATE: ${jsonData.length} registros de GMV. Procesando en Isolate...');

      // SP4: Procesar en Isolate
      final result = await Isolate.run(() {
        // SP4 ISOLATE WORKER: Background GMV calculations
        print('SP4 ISOLATE WORKER: Calculando tendencias de GMV en background...');
        
        final gmvData = jsonData
            .map((json) => GMVAnalyticsData.fromJson(json as Map<String, dynamic>))
            .toList();

        // Ordenar por fecha para calcular tendencias
        gmvData.sort((a, b) => a.day.compareTo(b.day));

        int totalGMVCents = 0;
        int totalOrders = 0;
        
        for (final data in gmvData) {
          totalGMVCents += data.gmvCents;
          totalOrders += data.ordersPaid;
        }

        final totalGMV = totalGMVCents / 100.0; // Convertir a unidades
        final avgOrderValue = totalOrders > 0 ? totalGMV / totalOrders : 0.0;

        // Calcular tasa de crecimiento (primer dia vs ultimo dia)
        double growthRate = 0.0;
        if (gmvData.length >= 2) {
          final firstDayGMV = gmvData.first.gmvCents / 100.0;
          final lastDayGMV = gmvData.last.gmvCents / 100.0;
          
          if (firstDayGMV > 0) {
            growthRate = ((lastDayGMV - firstDayGMV) / firstDayGMV) * 100;
          }
        }

        print('SP4 ISOLATE WORKER: GMV total: \$$totalGMV, Crecimiento: ${growthRate.toStringAsFixed(2)}%');

        return ProcessedGMVAnalytics(
          totalGMV: totalGMV,
          totalOrdersPaid: totalOrders,
          averageOrderValue: avgOrderValue,
          dailyGrowthRate: growthRate,
          trends: gmvData,
        );
      });

      print('SP4 ISOLATE: Tendencias de GMV calculadas exitosamente');
      return result;
    } catch (e) {
      print('SP4 ISOLATE ERROR: $e');
      throw Exception('Error calculando tendencias de GMV: $e');
    }
  }
}
