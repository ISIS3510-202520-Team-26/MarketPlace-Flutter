import 'package:flutter/material.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../../data/services/analytics_isolate_service.dart';
import '../../../data/repositories/local_sync_repository.dart';
import '../../../data/repositories/hive_repository.dart';

/// ============================================================================
/// SP4: EJEMPLO DE UI - DEMO DE FUTURE + ASYNC/AWAIT + ISOLATES
/// ============================================================================
/// 
/// Esta página demuestra el uso de los métodos implementados en SP4:
/// - ReviewRepository con Future handlers y async/await
/// - OrdersRepository con transiciones de estado async
/// - AnalyticsIsolateService con procesamiento en background
/// 
/// Visibilidad: Los logs con marcadores SP4 aparecen en la consola de debug.
/// 
/// Para probar:
/// 1. flutter run
/// 2. Navegar a esta página desde el menú
/// 3. Ver logs en consola con marcadores SP4 e "SP4 ISOLATE"
/// ============================================================================
class Sp4AsyncDemoPage extends StatefulWidget {
  const Sp4AsyncDemoPage({super.key});

  @override
  State<Sp4AsyncDemoPage> createState() => _Sp4AsyncDemoPageState();
}

class _Sp4AsyncDemoPageState extends State<Sp4AsyncDemoPage> {
  final _reviewRepo = ReviewRepository();
  final _ordersRepo = OrdersRepository();
  final _analyticsIsolateService = AnalyticsIsolateService();
  final _localSyncRepo = LocalSyncRepository(baseUrl: 'http://3.19.208.242:8000/v1');
  final _hiveRepo = HiveRepository(baseUrl: 'http://3.19.208.242:8000/v1');
  
  String _output = 'SP4: Listo para probar implementaciones async, Isolates, BD Local y BD Llave/Valor\n\n'
      'Selecciona una opción para ver Future handlers, async/await, Isolates, SQLite o Hive en acción.';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // SP4 KV: Inicializa Hive al cargar la pagina
    _hiveRepo.initialize().catchError((e) {
      print('SP4 KV DEMO: Error al inicializar Hive: $e');
    });
  }

  // ============================================================================
  // 🔥 SP4: DEMO 1 - FUTURE CON HANDLERS
  // ============================================================================
  void _testFutureHandlers() {
    setState(() {
      _isLoading = true;
      _output = '🔥 SP4: Ejecutando Future con .then()/.catchError()...\n\n';
    });

    // ⚡ SP4: Llama a createReviewWithHandlers (no usa await)
    _reviewRepo
        .createReviewWithHandlers(
          orderId: 'demo-order-123',
          rateeId: 'demo-user-456',
          rating: 5,
          comment: 'Excelente servicio - Demo SP4',
        )
        .then((review) {
          // ✅ SP4: Handler de éxito
          setState(() {
            _isLoading = false;
            _output += '✅ SUCCESS!\n\n'
                'Review creado:\n'
                '- ID: ${review.id}\n'
                '- Rating: ${review.rating}⭐\n'
                '- Comment: ${review.comment}\n\n'
                '📝 Ver logs en consola para marcadores SP4';
          });
        })
        .catchError((error) {
          // ❌ SP4: Handler de error
          setState(() {
            _isLoading = false;
            _output += '❌ ERROR!\n\n'
                'Error: $error\n\n'
                '📝 Ver logs en consola para detalles';
          });
        });
  }

  // ============================================================================
  // 🔥 SP4: DEMO 2 - ASYNC/AWAIT CON TRY-CATCH
  // ============================================================================
  Future<void> _testAsyncAwait() async {
    setState(() {
      _isLoading = true;
      _output = '🔥 SP4: Ejecutando async/await con try-catch...\n\n';
    });

    try {
      // ⚡ SP4: await suspende la ejecución hasta que complete
      final reviews = await _reviewRepo.loadUserReviewsAsync(
        'demo-user-789',
        limit: 10,
      );

      // ✅ SP4: Éxito - actualiza UI
      setState(() {
        _isLoading = false;
        _output += '✅ SUCCESS!\n\n'
            '${reviews.length} reviews cargados\n\n';

        if (reviews.isEmpty) {
          _output += 'Usuario sin reviews (esperado en demo)\n\n';
        } else {
          _output += 'Reviews:\n';
          for (var review in reviews.take(3)) {
            _output += '- ${review.rating}⭐: ${review.comment ?? "Sin comentario"}\n';
          }
          _output += '\n';
        }

        _output += '📝 Ver logs en consola para marcadores ⏳✅ SP4';
      });
    } catch (e) {
      // ❌ SP4: Error - actualiza UI
      setState(() {
        _isLoading = false;
        _output += '❌ ERROR!\n\n'
            'Error: $e\n\n'
            '📝 Ver logs en consola para detalles';
      });
    }
  }

  // ============================================================================
  // 🔥 SP4: DEMO 3 - ASYNC/AWAIT CON NULL SAFETY
  // ============================================================================
  Future<void> _testNullableAsync() async {
    setState(() {
      _isLoading = true;
      _output = '🔥 SP4: Ejecutando async/await con retorno nullable...\n\n';
    });

    try {
      // ⚡ SP4: await con Future<Review?> (nullable)
      final review = await _reviewRepo.loadOrderReviewAsync('demo-order-999');

      // ✅ SP4: Maneja null y non-null
      setState(() {
        _isLoading = false;
        if (review == null) {
          _output += 'ℹ️ Orden sin review\n\n'
              'Resultado: null (esperado en demo)\n\n'
              '📝 Ver logs en consola - manejo de 404';
        } else {
          _output += '✅ Review encontrado!\n\n'
              '- Rating: ${review.rating}⭐\n'
              '- Comment: ${review.comment}\n\n'
              '📝 Ver logs en consola para marcadores SP4';
        }
      });
    } catch (e) {
      // ❌ SP4: Error
      setState(() {
        _isLoading = false;
        _output += '❌ ERROR!\n\n$e\n\n📝 Ver logs en consola';
      });
    }
  }

  // ============================================================================
  // 🔥 SP4: DEMO 4 - ASYNC/AWAIT CON PROCESAMIENTO DE DATOS
  // ============================================================================
  Future<void> _testDataProcessing() async {
    setState(() {
      _isLoading = true;
      _output = '🔥 SP4: Ejecutando async/await con agregación de datos...\n\n';
    });

    try {
      // ⚡ SP4: await con procesamiento de datos complejo
      final rating = await _reviewRepo.calculateUserRatingAsync('demo-user-123');

      // ✅ SP4: Muestra resultado agregado
      setState(() {
        _isLoading = false;
        _output += '✅ Rating calculado!\n\n'
            '⭐ Promedio: ${rating.averageRating.toStringAsFixed(2)}\n'
            '📊 Total reviews: ${rating.totalReviews}\n'
            '✨ Positivas: ${rating.positivePercentage.toStringAsFixed(1)}%\n\n'
            'Distribución:\n';

        rating.ratingDistribution.forEach((stars, count) {
          _output += '$stars⭐: $count reviews\n';
        });

        _output += '\n📝 Ver logs en consola para proceso de cálculo';
      });
    } catch (e) {
      // ❌ SP4: Error
      setState(() {
        _isLoading = false;
        _output += '❌ ERROR!\n\n$e\n\n📝 Ver logs en consola';
      });
    }
  }

  // ============================================================================
  // 🔥 SP4: DEMO 5 - FUTURE CON ENCADENAMIENTO
  // ============================================================================
  void _testChainedHandlers() {
    setState(() {
      _isLoading = true;
      _output = '🔥 SP4: Ejecutando Future con handlers encadenados...\n\n';
    });

    // ⚡ SP4: Encadenamiento de .then() handlers
    _reviewRepo
        .canUserReviewOrderWithHandlers('demo-order-456')
        .then((canReview) {
          // ✅ SP4: Handler de éxito
          setState(() {
            _isLoading = false;
            _output += canReview
                ? '✅ Usuario PUEDE crear review\n\n'
                    'Orden sin review existente\n\n'
                : '❌ Usuario NO PUEDE crear review\n\n'
                    'Orden ya tiene review\n\n';
            _output += '📝 Ver logs en consola para flujo de decisión';
          });
        })
        .catchError((error) {
          // ❌ SP4: Handler de error
          setState(() {
            _isLoading = false;
            _output += '❌ ERROR en verificación!\n\n$error\n\n📝 Ver logs';
          });
        });
  }

  // ============================================================================
  // 🔥 SP4: DEMO 6 - ASYNC/AWAIT CON OPERACIONES PARALELAS
  // ============================================================================
  Future<void> _testParallelOperations() async {
    setState(() {
      _isLoading = true;
      _output = '🔥 SP4: Ejecutando Future.wait() con operaciones paralelas...\n\n';
    });

    try {
      // ⚡ SP4: Future.wait ejecuta múltiples futures en paralelo
      final userIds = ['user-1', 'user-2', 'user-3'];
      final ratingsMap = await _reviewRepo.getBulkUserRatingsAsync(userIds);

      // ✅ SP4: Resultados de operaciones paralelas
      setState(() {
        _isLoading = false;
        _output += '✅ Ratings cargados en paralelo!\n\n'
            'Usuarios procesados: ${ratingsMap.length}\n\n';

        ratingsMap.forEach((userId, rating) {
          _output += '$userId:\n'
              '  ⭐ ${rating.averageRating.toStringAsFixed(2)} '
              '(${rating.totalReviews} reviews)\n';
        });

        _output += '\n📝 Ver logs en consola - ejecutados simultáneamente';
      });
    } catch (e) {
      // ❌ SP4: Error
      setState(() {
        _isLoading = false;
        _output += '❌ ERROR en carga paralela!\n\n$e\n\n📝 Ver logs';
      });
    }
  }

  // ============================================================================
  // 🔥 SP4: DEMO 7 - FLUJO COMPLETO CON HANDLERS (ORDERS)
  // ============================================================================
  void _testOrderFlow() {
    setState(() {
      _isLoading = true;
      _output = '🔥 SP4: Ejecutando flujo completo: crear → pagar → completar...\n\n';
    });

    // ⚡ SP4: Encadenamiento complejo de operaciones de orden
    _ordersRepo
        .processFullOrderFlowWithHandlers(listingId: 'demo-listing-789')
        .then((completedOrder) {
          // ✅ SP4: Flujo completado exitosamente
          setState(() {
            _isLoading = false;
            _output += '🎉 FLUJO COMPLETADO!\n\n'
                'Orden procesada:\n'
                '- ID: ${completedOrder.id}\n'
                '- Estado final: ${completedOrder.status}\n'
                '- Total: \$${completedOrder.total}\n\n'
                '📝 Ver logs en consola para el flujo paso a paso:\n'
                '   1️⃣ Crear orden\n'
                '   2️⃣ Pagar orden\n'
                '   3️⃣ Completar orden';
          });
        })
        .catchError((error) {
          // ❌ SP4: Error en algún paso del flujo
          setState(() {
            _isLoading = false;
            _output += '❌ ERROR EN FLUJO!\n\n'
                'El flujo falló en algún paso\n\n'
                'Error: $error\n\n'
                '📝 Ver logs para identificar el paso fallido';
          });
        });
  }

  // ============================================================================
  // SP4 ISOLATE: DEMO 1 - PROCESAMIENTO DE ORDENES EN ISOLATE
  // ============================================================================
  Future<void> _testOrdersIsolate() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 ISOLATE: Procesando analytics de ordenes en background...\n\n';
    });

    try {
      // SP4 ISOLATE: La UI permanece responsive mientras se procesa en background
      final stopwatch = Stopwatch()..start();
      
      final result = await _analyticsIsolateService.processOrdersAnalyticsInIsolate(
        startDate: '2024-01-01T00:00:00Z',
        endDate: '2024-12-31T23:59:59Z',
      );
      
      stopwatch.stop();

      setState(() {
        _isLoading = false;
        _output += 'PROCESAMIENTO COMPLETADO EN ISOLATE\n\n'
            'Tiempo: ${stopwatch.elapsedMilliseconds}ms\n\n'
            'Resultados:\n'
            '- Total ordenes: ${result.totalOrders}\n'
            '- Tasa de conversion: ${result.conversionRate.toStringAsFixed(2)}%\n'
            '- Tasa de cancelacion: ${result.cancellationRate.toStringAsFixed(2)}%\n\n'
            'Por status:\n';
        
        result.ordersByStatus.forEach((status, count) {
          _output += '  $status: $count\n';
        });
        
        _output += '\nVer logs en consola para detalles del Isolate';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 ISOLATE: DEMO 2 - PROCESAMIENTO DE LISTINGS EN ISOLATE
  // ============================================================================
  Future<void> _testListingsIsolate() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 ISOLATE: Procesando analytics de listings en background...\n\n';
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      final result = await _analyticsIsolateService.processListingsAnalyticsInIsolate(
        startDate: '2024-01-01T00:00:00Z',
        endDate: '2024-12-31T23:59:59Z',
      );
      
      stopwatch.stop();

      setState(() {
        _isLoading = false;
        _output += 'PROCESAMIENTO COMPLETADO EN ISOLATE\n\n'
            'Tiempo: ${stopwatch.elapsedMilliseconds}ms\n\n'
            'Resultados:\n'
            '- Total listings: ${result.totalListings}\n'
            '- Categoria top: ${result.topCategory}\n'
            '- Promedio diario: ${result.averageListingsPerDay.toStringAsFixed(2)}\n\n'
            'Por categoria:\n';
        
        result.listingsByCategory.forEach((category, count) {
          _output += '  $category: $count\n';
        });
        
        _output += '\nVer logs en consola para detalles del Isolate';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 ISOLATE: DEMO 3 - PROCESAMIENTO DE EVENTOS EN ISOLATE
  // ============================================================================
  Future<void> _testEventsIsolate() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 ISOLATE: Procesando eventos de telemetria en background...\n\n';
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      final result = await _analyticsIsolateService.processEventsAnalyticsInIsolate(
        startDate: '2024-01-01T00:00:00Z',
        endDate: '2024-12-31T23:59:59Z',
      );
      
      stopwatch.stop();

      setState(() {
        _isLoading = false;
        _output += 'PROCESAMIENTO COMPLETADO EN ISOLATE\n\n'
            'Tiempo: ${stopwatch.elapsedMilliseconds}ms\n\n'
            'Resultados:\n'
            '- Total eventos: ${result.totalEvents}\n'
            '- Evento mas frecuente: ${result.mostFrequentEvent}\n'
            '- Promedio diario: ${result.averageEventsPerDay.toStringAsFixed(2)}\n\n'
            'Por tipo:\n';
        
        result.eventsByType.forEach((type, count) {
          _output += '  $type: $count\n';
        });
        
        _output += '\nVer logs en consola para detalles del Isolate';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 ISOLATE: DEMO 4 - CALCULO DE GMV EN ISOLATE
  // ============================================================================
  Future<void> _testGMVIsolate() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 ISOLATE: Calculando tendencias de GMV en background...\n\n';
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      final result = await _analyticsIsolateService.calculateGMVTrendsInIsolate(
        startDate: '2024-01-01T00:00:00Z',
        endDate: '2024-12-31T23:59:59Z',
      );
      
      stopwatch.stop();

      setState(() {
        _isLoading = false;
        _output += 'PROCESAMIENTO COMPLETADO EN ISOLATE\n\n'
            'Tiempo: ${stopwatch.elapsedMilliseconds}ms\n\n'
            'Resultados:\n'
            '- GMV Total: \$${result.totalGMV.toStringAsFixed(2)}\n'
            '- Ordenes pagadas: ${result.totalOrdersPaid}\n'
            '- Valor promedio orden: \$${result.averageOrderValue.toStringAsFixed(2)}\n'
            '- Tasa crecimiento: ${result.dailyGrowthRate.toStringAsFixed(2)}%\n\n'
            'Ver logs en consola para detalles del Isolate';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 DB: DEMO 1 - SINCRONIZAR LISTINGS DESDE BACKEND A BD LOCAL
  // ============================================================================
  Future<void> _testSyncListings() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 DB: Sincronizando listings desde Backend a BD local...\n\n';
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      final listings = await _localSyncRepo.syncListingsFromBackend(limit: 10);
      
      stopwatch.stop();

      setState(() {
        _isLoading = false;
        _output += 'SINCRONIZACION COMPLETADA\n\n'
            'Tiempo: ${stopwatch.elapsedMilliseconds}ms\n'
            'Listings sincronizados: ${listings.length}\n\n'
            'Primeros 3 listings:\n';
        
        for (var i = 0; i < listings.length && i < 3; i++) {
          final listing = listings[i];
          _output += '${i + 1}. ${listing['title']}\n'
              '   Precio: \$${(listing['price_cents'] / 100).toStringAsFixed(2)}\n'
              '   Seller: ${listing['seller_id']}\n\n';
        }
        
        _output += 'Ver logs en consola para detalles SP4 DB SYNC';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 DB: DEMO 2 - CONSULTAR ORDEN CON RELACIONES (JOIN)
  // ============================================================================
  Future<void> _testQueryOrderWithJoin() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 DB: Consultando orden con JOIN en BD local...\n\n';
    });

    try {
      // SP4 DB: Primero sincroniza algunos datos
      await _localSyncRepo.syncListingsFromBackend(limit: 5);
      
      // SP4 DB: Luego consulta con JOIN
      final stats = await _localSyncRepo.getLocalDatabaseStats();
      
      setState(() {
        _isLoading = false;
        _output += 'CONSULTA RELACIONAL COMPLETADA\n\n'
            'Registros en BD local:\n'
            '- Users: ${stats['users']}\n'
            '- Listings: ${stats['listings']}\n'
            '- Orders: ${stats['orders']}\n'
            '- Reviews: ${stats['reviews']}\n\n'
            'La BD local usa SQLite con relaciones:\n'
            '- Users 1:N Listings\n'
            '- Listings 1:N Orders\n'
            '- Orders 1:1 Reviews\n\n'
            'Ver logs en consola para queries SQL (SP4 DB)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 DB: DEMO 3 - CALCULAR ESTADISTICAS LOCALES (AGREGACIONES)
  // ============================================================================
  Future<void> _testLocalAggregations() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 DB: Calculando estadisticas con agregaciones SQL...\n\n';
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      // SP4 DB: Sincroniza datos primero
      await _localSyncRepo.syncListingsFromBackend(limit: 20);
      
      // SP4 DB: Obtiene estadisticas
      final dbStats = await _localSyncRepo.getLocalDatabaseStats();
      
      stopwatch.stop();

      setState(() {
        _isLoading = false;
        _output += 'AGREGACIONES COMPLETADAS\n\n'
            'Tiempo: ${stopwatch.elapsedMilliseconds}ms\n\n'
            'Estadisticas de BD Local:\n'
            '- Total users: ${dbStats['users']}\n'
            '- Total listings: ${dbStats['listings']}\n'
            '- Total orders: ${dbStats['orders']}\n'
            '- Total reviews: ${dbStats['reviews']}\n\n'
            'Operaciones SQL usadas:\n'
            '- COUNT(*)\n'
            '- AVG()\n'
            '- SUM()\n'
            '- GROUP BY\n\n'
            'Ver logs en consola para queries (SP4 DB)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 DB: DEMO 4 - MODO OFFLINE (CACHE LOCAL)
  // ============================================================================
  Future<void> _testOfflineMode() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 DB: Probando modo offline con cache local...\n\n';
    });

    try {
      // SP4 DB: Primero sincroniza datos
      _output += 'Paso 1: Sincronizando datos a BD local...\n';
      await _localSyncRepo.syncListingsFromBackend(limit: 10);
      
      // SP4 DB: Luego simula obtener datos (usara cache si no hay red)
      _output += 'Paso 2: Obteniendo datos desde BD local...\n';
      final stats = await _localSyncRepo.getLocalDatabaseStats();
      
      setState(() {
        _isLoading = false;
        _output += '\nMODO OFFLINE DEMOSTRADO\n\n'
            'Datos disponibles en cache:\n'
            '- Listings: ${stats['listings']}\n'
            '- Orders: ${stats['orders']}\n'
            '- Reviews: ${stats['reviews']}\n\n'
            'VENTAJAS:\n'
            '- Funciona sin conexion\n'
            '- Consultas instantaneas\n'
            '- Sincroniza cuando hay red\n\n'
            'Ver logs en consola (SP4 DB SYNC)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 KV: DEMO 1 - USER PREFERENCES EN HIVE
  // ============================================================================
  Future<void> _testHivePreferences() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 KV: Probando preferencias de usuario con Hive...\n\n';
    });

    try {
      // SP4 KV: Guarda preferencias
      _output += 'Paso 1: Guardando preferencias en Hive...\n';
      await _hiveRepo.setupUserProfile(
        campus: 'Universidad Javeriana',
        theme: 'dark',
        language: 'es',
        notifications: true,
      );
      
      // SP4 KV: Lee preferencias
      _output += 'Paso 2: Leyendo preferencias desde Hive...\n';
      final settings = _hiveRepo.getUserSettings();
      
      // SP4 KV: Modifica una preferencia
      _output += 'Paso 3: Cambiando tema a light...\n';
      await _hiveRepo.updateTheme('light');
      
      setState(() {
        _isLoading = false;
        _output += '\nPREFERENCIAS GUARDADAS EN HIVE\n\n'
            'Configuracion actual:\n'
            '- Tema: ${settings['theme_mode']}\n'
            '- Idioma: ${settings['language']}\n'
            '- Notificaciones: ${settings['notifications_enabled']}\n'
            '- Campus: ${settings['preferred_campus']}\n\n'
            'VENTAJAS HIVE:\n'
            '- Acceso instantaneo (sin SQL)\n'
            '- Persistente entre sesiones\n'
            '- Tipado fuerte con boxes\n\n'
            'Ver logs en consola (SP4 KV REPO)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 KV: DEMO 2 - FEATURE FLAGS EN HIVE (SYNC CON BACKEND)
  // ============================================================================
  Future<void> _testHiveFeatureFlags() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 KV: Sincronizando feature flags desde Backend...\n\n';
    });

    try {
      // SP4 KV: Sincroniza feature flags desde Backend
      _output += 'Paso 1: GET /features desde Backend...\n';
      final flags = await _hiveRepo.syncFeatureFlagsFromBackend();
      
      // SP4 KV: Verifica una flag especifica
      _output += 'Paso 2: Verificando flag "chat_enabled"...\n';
      final chatEnabled = await _hiveRepo.isFeatureEnabled('chat_enabled', defaultValue: false);
      
      // SP4 KV: Registra uso de feature
      if (chatEnabled) {
        _output += 'Paso 3: Registrando uso de feature en Backend...\n';
        await _hiveRepo.registerFeatureUse('chat_enabled');
      }
      
      setState(() {
        _isLoading = false;
        _output += '\nFEATURE FLAGS SINCRONIZADOS\n\n'
            'Total flags: ${flags.length}\n'
            'Chat habilitado: $chatEnabled\n\n'
            'Flags disponibles:\n';
        
        flags.forEach((key, value) {
          _output += '- $key: ${value ? "ON" : "OFF"}\n';
        });
        
        _output += '\nVENTAJAS:\n'
            '- Sincronizacion con Backend\n'
            '- Cache local para offline\n'
            '- Acceso rapido sin SQL\n\n'
            'Ver logs en consola (SP4 KV REPO)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 KV: DEMO 3 - CACHE CON TTL EN HIVE
  // ============================================================================
  Future<void> _testHiveCache() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 KV: Probando cache con TTL en Hive...\n\n';
    });

    try {
      // SP4 KV: Primera llamada - obtiene desde Backend y cachea
      _output += 'Paso 1: Primera llamada (Backend + cache)...\n';
      final stopwatch1 = Stopwatch()..start();
      final listings1 = await _hiveRepo.getListingsWithCache(forceRefresh: true);
      stopwatch1.stop();
      
      // SP4 KV: Segunda llamada - usa cache
      _output += 'Paso 2: Segunda llamada (solo cache)...\n';
      final stopwatch2 = Stopwatch()..start();
      final listings2 = await _hiveRepo.getListingsWithCache(forceRefresh: false);
      stopwatch2.stop();
      
      setState(() {
        _isLoading = false;
        _output += '\nCACHE CON TTL DEMOSTRADO\n\n'
            'Primera llamada (Backend):\n'
            '- Tiempo: ${stopwatch1.elapsedMilliseconds}ms\n'
            '- Listings: ${listings1.length}\n\n'
            'Segunda llamada (Cache Hive):\n'
            '- Tiempo: ${stopwatch2.elapsedMilliseconds}ms\n'
            '- Listings: ${listings2.length}\n\n'
            'Mejora: ${((stopwatch1.elapsedMilliseconds - stopwatch2.elapsedMilliseconds) / stopwatch1.elapsedMilliseconds * 100).toStringAsFixed(1)}% mas rapido\n\n'
            'VENTAJAS CACHE HIVE:\n'
            '- TTL automatico\n'
            '- Sin queries SQL\n'
            '- Acceso O(1)\n\n'
            'Ver logs en consola (SP4 KV REPO)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  // ============================================================================
  // SP4 KV: DEMO 4 - SESSION MANAGEMENT EN HIVE
  // ============================================================================
  Future<void> _testHiveSession() async {
    setState(() {
      _isLoading = true;
      _output = 'SP4 KV: Probando gestion de sesion con Hive...\n\n';
    });

    try {
      // SP4 KV: Inicia sesion
      _output += 'Paso 1: Iniciando sesion...\n';
      await _hiveRepo.startSession(
        token: 'demo-jwt-token-abc123',
        userId: 'user-demo-456',
        userData: {
          'id': 'user-demo-456',
          'name': 'Usuario Demo',
          'email': 'demo@javeriana.edu.co',
          'campus': 'Bogota',
        },
      );
      
      // SP4 KV: Verifica sesion
      _output += 'Paso 2: Verificando sesion...\n';
      final hasSession = _hiveRepo.hasActiveSession();
      final token = _hiveRepo.getSessionToken();
      final user = _hiveRepo.getCachedUser();
      
      // SP4 KV: Obtiene estadisticas
      _output += 'Paso 3: Obteniendo estadisticas de Hive...\n';
      final stats = _hiveRepo.getStorageStatistics();
      
      setState(() {
        _isLoading = false;
        _output += '\nSESION GESTIONADA EN HIVE\n\n'
            'Estado de sesion:\n'
            '- Sesion activa: $hasSession\n'
            '- Token: ${token?.substring(0, 20)}...\n'
            '- Usuario: ${user?['name']}\n'
            '- Email: ${user?['email']}\n\n'
            'Estadisticas Hive:\n'
            '- Total boxes: ${stats['total_boxes']}\n'
            '- Total keys: ${stats['total_keys']}\n'
            '- Backend URL: ${stats['backend_url']}\n\n'
            'VENTAJAS SESSION EN HIVE:\n'
            '- Persistente entre reinicios\n'
            '- Acceso rapido sin BD\n'
            '- Seguro (Hive encriptado)\n\n'
            'Ver logs en consola (SP4 KV REPO)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += 'ERROR!\n\n$e\n\nVer logs en consola';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SP4: Async + Isolates + BD Demo'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ⚡ SP4: Card informativa
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text(
                          'SP4: Future + Async/Await Demo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demuestra los patrones implementados en:\n'
                      '• review_repository.dart\n'
                      '• orders_repository.dart\n'
                      '• analytics_isolate_service.dart (Isolates)\n'
                      '• database_helper.dart (BD Local SQLite)\n'
                      '• local_sync_repository.dart (Sync)\n\n'
                      'IMPORTANTE: Ver logs en consola de debug para marcadores SP4',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ⚡ SP4: Área de output
            Card(
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 200),
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'SP4: Procesando...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SelectableText(
                        _output,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // SP4: Sección Reviews
            const Text(
              'REVIEW REPOSITORY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),

            _buildButton(
              'Future con Handlers',
              'createReviewWithHandlers()',
              _testFutureHandlers,
            ),
            _buildButton(
              'Async/Await',
              'loadUserReviewsAsync()',
              _testAsyncAwait,
            ),
            _buildButton(
              'Nullable Async',
              'loadOrderReviewAsync()',
              _testNullableAsync,
            ),
            _buildButton(
              'Data Processing',
              'calculateUserRatingAsync()',
              _testDataProcessing,
            ),
            _buildButton(
              'Chained Handlers',
              'canUserReviewOrderWithHandlers()',
              _testChainedHandlers,
            ),
            _buildButton(
              'Parallel Operations',
              'getBulkUserRatingsAsync()',
              _testParallelOperations,
            ),

            const SizedBox(height: 16),

            // SP4: Sección Orders
            const Text(
              'ORDERS REPOSITORY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),

            _buildButton(
              'Full Order Flow',
              'processFullOrderFlowWithHandlers()',
              _testOrderFlow,
            ),

            const SizedBox(height: 24),

            // ============================================================================
            // SP4 ISOLATE: SECCION DE DEMOS - PROCESAMIENTO EN BACKGROUND
            // ============================================================================
            const Divider(thickness: 2, color: Colors.deepPurple),
            const SizedBox(height: 16),

            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'SP4 ISOLATE: Background Processing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demuestra procesamiento pesado en Isolates:\n'
                      '• analytics_isolate_service.dart\n'
                      '• La UI permanece responsive durante el procesamiento\n'
                      '• Ver logs en consola para marcadores SP4 ISOLATE',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'ISOLATES ANALYTICS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),

            _buildButton(
              'SP4 ISOLATE: Orders Analytics',
              'processOrdersAnalyticsInIsolate()',
              _testOrdersIsolate,
            ),
            _buildButton(
              'SP4 ISOLATE: Listings Analytics',
              'processListingsAnalyticsInIsolate()',
              _testListingsIsolate,
            ),
            _buildButton(
              'SP4 ISOLATE: Events Analytics',
              'processEventsAnalyticsInIsolate()',
              _testEventsIsolate,
            ),
            _buildButton(
              'SP4 ISOLATE: GMV Trends',
              'calculateGMVTrendsInIsolate()',
              _testGMVIsolate,
            ),

            const SizedBox(height: 24),

            // ============================================================================
            // SP4 DB: SECCION DE DEMOS - BASE DE DATOS LOCAL RELACIONAL
            // ============================================================================
            const Divider(thickness: 2, color: Colors.green),
            const SizedBox(height: 16),

            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'SP4 DB: Base de Datos Local Relacional',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demuestra BD local SQLite con relaciones:\n'
                      '• database_helper.dart (esquema y CRUD)\n'
                      '• local_sync_repository.dart (sincronizacion)\n'
                      '• Tablas: users, listings, orders, reviews\n'
                      '• Soporta modo offline con cache local\n'
                      '• Ver logs en consola para marcadores SP4 DB',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'BD LOCAL SQLITE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),

            _buildButton(
              'SP4 DB: Sync Listings to Local',
              'syncListingsFromBackend()',
              _testSyncListings,
            ),
            _buildButton(
              'SP4 DB: Query with JOIN',
              'getOrderWithDetails() + SQL JOIN',
              _testQueryOrderWithJoin,
            ),
            _buildButton(
              'SP4 DB: Local Aggregations',
              'COUNT/AVG/SUM en SQLite',
              _testLocalAggregations,
            ),
            _buildButton(
              'SP4 DB: Offline Mode',
              'Cache local sin red',
              _testOfflineMode,
            ),

            const SizedBox(height: 24),

            // ============================================================================
            // SP4 KV: SECCION DE DEMOS - BASE DE DATOS LLAVE/VALOR HIVE
            // ============================================================================
            const Divider(thickness: 2, color: Colors.teal),
            const SizedBox(height: 16),

            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'SP4 KV: Base de Datos Llave/Valor Hive',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demuestra BD Llave/Valor Hive (NoSQL):\n'
                      '• hive_service.dart (5 boxes)\n'
                      '• hive_repository.dart (integracion Backend)\n'
                      '• Boxes: user_prefs, app_config, cache, feature_flags, session\n'
                      '• Acceso O(1) sin SQL queries\n'
                      '• Sincroniza feature flags desde Backend\n'
                      '• Ver logs en consola para marcadores SP4 KV',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'BD LLAVE/VALOR HIVE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),

            _buildButton(
              'SP4 KV: User Preferences',
              'setupUserProfile() + getUserSettings()',
              _testHivePreferences,
            ),
            _buildButton(
              'SP4 KV: Feature Flags Sync',
              'syncFeatureFlagsFromBackend()',
              _testHiveFeatureFlags,
            ),
            _buildButton(
              'SP4 KV: Cache with TTL',
              'getListingsWithCache() con Hive',
              _testHiveCache,
            ),
            _buildButton(
              'SP4 KV: Session Management',
              'startSession() + hasActiveSession()',
              _testHiveSession,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, String method, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              method,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
