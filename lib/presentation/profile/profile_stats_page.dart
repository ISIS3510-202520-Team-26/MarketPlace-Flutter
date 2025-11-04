import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/listings_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/services/preload_service.dart';

/// Página de estadísticas del usuario con FutureBuilder
/// 
/// Demuestra el uso avanzado de:
/// - FutureBuilder para manejo de estados asíncronos
/// - Múltiples Futures combinados con Future.wait
/// - Manejo robusto de errores con try-catch
/// - Estados de loading, error y success
/// - Retry mechanism para reintentar peticiones fallidas
/// 
/// **DATOS REALES DEL BACKEND:**
/// - Obtiene listings reales del usuario autenticado
/// - Calcula estadísticas basadas en datos del servidor
/// - Usa Future.wait para peticiones paralelas
class ProfileStatsPage extends StatefulWidget {
  const ProfileStatsPage({super.key});

  @override
  State<ProfileStatsPage> createState() => _ProfileStatsPageState();
}

class _ProfileStatsPageState extends State<ProfileStatsPage> {
  final _authRepo = AuthRepository();
  final _listingsRepo = ListingsRepository();
  final _preloadService = PreloadService.instance;
  
  /// Key para forzar reconstrucción del FutureBuilder
  Key _futureKey = UniqueKey();
  
  /// Future que carga todas las estadísticas
  late Future<UserStats> _statsFuture;
  
  /// Indica si estamos en modo offline
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Telemetry.i.view('profile_stats_page');
    _statsFuture = _loadStats();
    
    // Escuchar actualizaciones mediante Stream
    _preloadService.dataUpdateStream.listen((event) {
      if (mounted && (event.type == DataUpdateType.stats || event.type == DataUpdateType.all)) {
        print('[ProfileStatsPage] 🔄 Stream recibido: ${event.type} - ${event.message ?? ""}');
        setState(() {
          _futureKey = UniqueKey();
          _statsFuture = _loadStats();
        });
      }
    });
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  /// Carga todas las estadísticas del usuario
  /// 
  /// Primero intenta cargar desde caché (instantáneo).
  /// Si hay conexión, también intenta actualizar desde el backend.
  /// Si no hay conexión o falla, usa los datos del caché.
  /// 
  /// **ESTRATEGIA OFFLINE-FIRST:**
  /// 1. Cargar desde caché si existe (< 50ms)
  /// 2. Intentar actualizar desde backend en segundo plano
  /// 3. Si falla, mantener datos del caché
  Future<UserStats> _loadStats() async {
    print('[ProfileStatsPage] 📊 Cargando estadísticas...');
    
    // Primero intentar cargar desde caché
    final cachedStats = await _loadFromCache();
    
    // Si hay caché, usarlo inmediatamente
    if (cachedStats != null) {
      print('[ProfileStatsPage] ✅ Estadísticas cargadas desde caché');
      setState(() => _isOffline = false);
      
      // Intentar actualizar desde backend en segundo plano
      _updateFromBackgroundSync();
      
      return cachedStats;
    }
    
    // Si no hay caché, intentar cargar desde backend
    try {
      print('[ProfileStatsPage] 🌐 No hay caché, cargando desde backend...');
      return await _loadFromBackend();
    } catch (e) {
      print('[ProfileStatsPage] ❌ Error al cargar desde backend: $e');
      setState(() => _isOffline = true);
      
      // Si falla todo, mostrar datos por defecto
      throw 'Error de conexión';
    }
  }
  
  /// Carga estadísticas desde el caché del PreloadService
  Future<UserStats?> _loadFromCache() async {
    try {
      final cachedStatsJson = await _preloadService.getCachedUserStats();
      final cachedProfileJson = await _preloadService.getCachedUserProfile();
      
      if (cachedStatsJson != null && cachedProfileJson != null) {
        return UserStats(
          totalListings: cachedStatsJson['total_listings'] as int? ?? 0,
          activeListings: cachedStatsJson['active_count'] as int? ?? 0,
          soldListings: cachedStatsJson['sold_count'] as int? ?? 0,
          totalValue: (cachedStatsJson['total_value'] as int? ?? 0) / 100.0,
          favoritesCount: cachedStatsJson['favorites_count'] as int? ?? 0,
          viewsCount: cachedStatsJson['views_count'] as int? ?? 0,
          memberSince: cachedProfileJson['created_at'] != null
              ? DateTime.parse(cachedProfileJson['created_at'] as String)
              : DateTime.now(),
        );
      }
    } catch (e) {
      print('[ProfileStatsPage] ⚠️ Error al cargar desde caché: $e');
    }
    return null;
  }
  
  /// Carga estadísticas desde el backend
  Future<UserStats> _loadFromBackend() async {
    try {
      // Ejecutar múltiples peticiones EN PARALELO con Future.wait
      final results = await Future.wait([
        _listingsRepo.getUserStats(),       // [0] Estadísticas de listings
        _authRepo.getCurrentUser(),         // [1] Datos del usuario
        _getFavoritesCount(),               // [2] Favoritos (simulado)
      ]);
      
      // Procesar resultados del backend
      final statsData = results[0] as UserStatsData;
      final user = results[1] as dynamic;
      final favoritesCount = results[2] as int;
      
      // Convertir price_cents a pesos
      final totalValuePesos = statsData.totalValue / 100;
      
      print('[ProfileStatsPage] ✅ Estadísticas del backend actualizadas');
      setState(() => _isOffline = false);
      
      return UserStats(
        totalListings: statsData.myListings.length,
        activeListings: statsData.activeCount,
        soldListings: statsData.soldCount,
        totalValue: totalValuePesos,
        favoritesCount: favoritesCount,
        viewsCount: statsData.viewsCount,
        memberSince: user.createdAt ?? DateTime.now(),
      );
    } catch (e) {
      print('[ProfileStatsPage] ❌ Error al cargar desde backend: $e');
      setState(() => _isOffline = true);
      rethrow;
    }
  }
  
  /// Intenta actualizar desde backend sin bloquear UI
  void _updateFromBackgroundSync() {
    _loadFromBackend().then((updatedStats) {
      if (mounted) {
        setState(() {
          _futureKey = UniqueKey();
          _statsFuture = Future.value(updatedStats);
        });
      }
    }).catchError((error) {
      print('[ProfileStatsPage] ⚠️ No se pudo actualizar desde backend: $error');
      // No hacer nada, mantener datos del caché
    });
  }
  
  /// Simula obtener el conteo de favoritos
  /// TODO: Implementar endpoint en el backend para obtener favoritos reales
  Future<int> _getFavoritesCount() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Por ahora simulamos, pero en el futuro se obtendrá del backend
    return 12 + DateTime.now().millisecond % 20;
  }
  
  /// Reintenta cargar las estadísticas
  /// 
  /// Genera un nuevo Key para forzar que el FutureBuilder
  /// vuelva a construirse con un nuevo Future
  void _retryLoadStats() {
    print('[ProfileStatsPage] 🔄 Reintentando cargar estadísticas...');
    Telemetry.i.click('stats_retry');
    
    setState(() {
      _futureKey = UniqueKey();
      _statsFuture = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () {
            Telemetry.i.click('stats_back');
            context.pop();
          },
        ),
        title: const Text(
          'Mis Estadísticas',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _retryLoadStats,
            tooltip: 'Actualizar estadísticas',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de modo offline
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange[800], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Modo offline - Mostrando datos cacheados',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Contenido principal
          Expanded(
            child: FutureBuilder<UserStats>(
              key: _futureKey,
              future: _statsFuture,
              builder: (context, snapshot) {
                // ESTADO 1: Loading (esperando que el Future se complete)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }
                
                // ESTADO 2: Error (el Future lanzó una excepción)
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }
                
                // ESTADO 3: Success (el Future se completó exitosamente)
                if (snapshot.hasData) {
                  return _buildSuccessState(snapshot.data!);
                }
                
                // ESTADO 4: Empty (no debería ocurrir, pero por seguridad)
                return _buildEmptyState();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Estado de carga con shimmer effect
  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLoadingCard(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLoadingCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildLoadingCard()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLoadingCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildLoadingCard()),
            ],
          ),
          const SizedBox(height: 16),
          _buildLoadingCard(),
        ],
      ),
    );
  }
  
  Widget _buildLoadingCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cargando...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado de error con opción de reintentar
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error al cargar estadísticas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryLoadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado exitoso con las estadísticas
  Widget _buildSuccessState(UserStats stats) {
    return RefreshIndicator(
      onRefresh: () async {
        _retryLoadStats();
        // Esperar a que el nuevo Future se complete
        await _statsFuture;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card de resumen principal
            _buildMainStatsCard(stats),
            const SizedBox(height: 24),
            
            // Título de sección
            const Text(
              'Detalle de Publicaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Grid de estadísticas
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_2,
                    label: 'Total',
                    value: stats.totalListings.toString(),
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    label: 'Activas',
                    value: stats.activeListings.toString(),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.shopping_bag,
                    label: 'Vendidas',
                    value: stats.soldListings.toString(),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.favorite,
                    label: 'Favoritos',
                    value: stats.favoritesCount.toString(),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Información adicional
            _buildInfoCard(stats),
          ],
        ),
      ),
    );
  }

  /// Card principal con el valor total y vistas
  Widget _buildMainStatsCard(UserStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stats.viewsCount} vistas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Valor Total de Publicaciones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_formatNumber(stats.totalValue)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Miembro desde ${_formatDate(stats.memberSince)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Card individual de estadística
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Card con información adicional
  Widget _buildInfoCard(UserStats stats) {
    final successRate = stats.totalListings > 0
        ? (stats.soldListings / stats.totalListings * 100).toStringAsFixed(1)
        : '0.0';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Adicional',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.trending_up,
            label: 'Tasa de éxito',
            value: '$successRate%',
            color: Colors.green,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.calculate,
            label: 'Precio promedio',
            value: stats.totalListings > 0
                ? '\$${_formatNumber(stats.totalValue / stats.totalListings)}'
                : '\$0',
            color: Colors.blue,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Antigüedad',
            value: _getDaysSince(stats.memberSince),
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Estado vacío (no debería ocurrir normalmente)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay datos disponibles',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Formatea números grandes con separadores de miles
  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Formatea fecha
  String _formatDate(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Calcula días desde una fecha
  String _getDaysSince(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days < 30) {
      return '$days días';
    } else if (days < 365) {
      final months = (days / 30).floor();
      return '$months ${months == 1 ? 'mes' : 'meses'}';
    } else {
      final years = (days / 365).floor();
      return '$years ${years == 1 ? 'año' : 'años'}';
    }
  }
}

/// Modelo de datos para las estadísticas del usuario
class UserStats {
  final int totalListings;
  final int activeListings;
  final int soldListings;
  final double totalValue;
  final int favoritesCount;
  final int viewsCount;
  final DateTime memberSince;

  UserStats({
    required this.totalListings,
    required this.activeListings,
    required this.soldListings,
    required this.totalValue,
    required this.favoritesCount,
    required this.viewsCount,
    required this.memberSince,
  });
}
