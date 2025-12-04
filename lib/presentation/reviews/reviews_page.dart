import 'package:flutter/material.dart';
import 'package:market_app/data/models/review.dart';
import 'package:market_app/data/repositories/review_repository.dart';
import 'package:market_app/data/repositories/local_sync_repository.dart';
import 'package:market_app/core/net/connectivity_service.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  // SP4 REVIEWS: Repositorios y servicios
  final ReviewRepository _reviewRepo = ReviewRepository();
  final LocalSyncRepository _localSync = LocalSyncRepository(baseUrl: 'http://3.19.208.242:8000/v1');
  final ConnectivityService _connectivity = ConnectivityService.instance;

  // SP4 REVIEWS: Estado de la página
  List<Review> _reviews = [];
  bool _loading = true;
  String? _error;
  bool _isOnline = true;
  bool _usingCache = false;

  @override
  void initState() {
    super.initState();
    print('SP4 REVIEWS: Inicializando ReviewsPage...');
    _checkConnectivity();
    _loadReviews();
  }

  // ============================================================================
  // SP4 REVIEWS: MONITOREO DE CONECTIVIDAD
  // ============================================================================

  /// SP4 REVIEWS: Verifica conectividad y sincroniza automáticamente
  Future<void> _checkConnectivity() async {
    print('SP4 REVIEWS: Verificando conectividad...');
    
    final isOnline = await _connectivity.isOnline;
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
      
      print('SP4 REVIEWS: Estado de conectividad: ${isOnline ? "ONLINE" : "OFFLINE"}');
      
      // SP4 REVIEWS: Si vuelve a estar online, sincroniza automáticamente
      if (isOnline && _usingCache) {
        print('SP4 REVIEWS: Conexión restaurada - sincronizando...');
        _syncReviews();
      }
    }
  }

  // ============================================================================
  // SP4 REVIEWS: CARGA DE REVIEWS (ONLINE/OFFLINE)
  // ============================================================================

  /// SP4 REVIEWS: Método principal de carga - enruta según conectividad
  Future<void> _loadReviews() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    print('SP4 REVIEWS: Iniciando carga de reviews...');
    
    if (_isOnline) {
      print('SP4 REVIEWS: Modo ONLINE - cargando desde Backend...');
      await _loadFromBackend();
    } else {
      print('SP4 REVIEWS: Modo OFFLINE - cargando desde SQLite...');
      await _loadFromCache();
    }
  }

  // ============================================================================
  // SP4 REVIEWS: CARGA DESDE BACKEND (ASYNC/AWAIT)
  // ============================================================================

  /// SP4 REVIEWS: Obtiene reviews del Backend y las cachea en SQLite
  Future<void> _loadFromBackend() async {
    try {
      print('SP4 REVIEWS: GET /reviews/users/{userId} desde Backend...');
      
      // SP4 REVIEWS: Aquí deberías obtener el userId del usuario autenticado
      // Por ahora usamos un placeholder - en producción usa AuthRepository
      const String userId = 'current-user-id'; // TODO: Obtener de sesión actual
      
      // SP4 REVIEWS: Usa async/await para obtener reviews del Backend
      final reviews = await _reviewRepo.loadUserReviewsAsync(userId, limit: 50);
      
      print('SP4 REVIEWS: ${reviews.length} reviews obtenidas del Backend');
      
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loading = false;
          _usingCache = false;
          _error = null;
        });
      }
      
      // SP4 REVIEWS: Cachea en SQLite para modo offline
      await _cacheReviews(userId);
      
    } catch (e) {
      print('SP4 REVIEWS: Error al cargar desde Backend: $e');
      
      // SP4 REVIEWS: Si falla Backend, intenta cargar desde cache
      if (_isOnline) {
        print('SP4 REVIEWS: Fallback a cache SQLite...');
        await _loadFromCache();
      } else {
        if (mounted) {
          setState(() {
            _error = 'Error al cargar reviews: $e';
            _loading = false;
          });
        }
      }
    }
  }

  // ============================================================================
  // SP4 REVIEWS: CARGA DESDE CACHE (MODO OFFLINE)
  // ============================================================================

  /// SP4 REVIEWS: Obtiene reviews del cache SQLite local
  Future<void> _loadFromCache() async {
    try {
      print('SP4 REVIEWS: Cargando desde SQLite cache...');
      
      // SP4 REVIEWS: Obtener userId del usuario autenticado
      const String userId = 'current-user-id'; // TODO: Obtener de sesión actual
      
      // SP4 REVIEWS: Obtiene reviews del cache local
      final localReviews = await _localSync.getLocalReviews(userId);
      
      print('SP4 REVIEWS: ${localReviews.length} reviews obtenidas del cache SQLite');
      
      // SP4 REVIEWS: Convierte Map a modelo Review
      final reviews = localReviews
          .map((json) => Review.fromJson(json))
          .toList();
      
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loading = false;
          _usingCache = true;
          _error = null;
        });
      }
      
    } catch (e) {
      print('SP4 REVIEWS: Error al cargar desde cache: $e');
      
      if (mounted) {
        setState(() {
          _error = 'Error al cargar reviews del cache: $e';
          _loading = false;
          _usingCache = true;
        });
      }
    }
  }

  // ============================================================================
  // SP4 REVIEWS: CACHEO EN SQLITE
  // ============================================================================

  /// SP4 REVIEWS: Guarda reviews en SQLite para uso offline
  Future<void> _cacheReviews(String userId) async {
    try {
      print('SP4 REVIEWS: Cacheando ${_reviews.length} reviews en SQLite...');
      
      // SP4 REVIEWS: Sincroniza con Backend - esto guarda automáticamente en SQLite
      await _localSync.syncUserReviewsFromBackend(userId);
      
      print('SP4 REVIEWS: Reviews cacheadas exitosamente en SQLite');
      
    } catch (e) {
      print('SP4 REVIEWS: Error al cachear reviews: $e');
      // No es crítico si falla el cacheo
    }
  }

  // ============================================================================
  // SP4 REVIEWS: SINCRONIZACIÓN MANUAL
  // ============================================================================

  /// SP4 REVIEWS: Sincroniza manualmente desde Backend
  Future<void> _syncReviews() async {
    if (!_isOnline) {
      print('SP4 REVIEWS: No se puede sincronizar - sin conexión');
      _showSnackBar('Sin conexión a internet', Colors.orange);
      return;
    }
    
    print('SP4 REVIEWS: Iniciando sincronización manual...');
    _showSnackBar('Sincronizando reviews...', Colors.blue);
    
    await _loadFromBackend();
    
    if (_error == null) {
      _showSnackBar('Reviews sincronizadas exitosamente', Colors.green);
    }
  }

  // ============================================================================
  // SP4 REVIEWS: UI HELPERS
  // ============================================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================================
  // SP4 REVIEWS: BUILD UI
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reviews'),
        actions: [
          // SP4 REVIEWS: Indicador de conectividad
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // SP4 REVIEWS: Botón de sincronización manual
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isOnline ? _syncReviews : null,
            tooltip: 'Sincronizar reviews',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: Column(
          children: [
            // SP4 REVIEWS: Banner de modo cache
            if (_usingCache)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo offline: Mostrando ${_reviews.length} reviews del cache SQLite',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Contenido principal
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SP4 REVIEWS: CONTENIDO PRINCIPAL
  // ============================================================================

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('SP4 REVIEWS: Cargando reviews...'),
          ],
        ),
      );
    }
    
    if (_error != null && _reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadReviews,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tienes reviews todavía',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las reviews que hagas a otros usuarios aparecerán aquí',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
    
    // SP4 REVIEWS: Lista de reviews
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  // ============================================================================
  // SP4 REVIEWS: TARJETA DE REVIEW
  // ============================================================================

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SP4 REVIEWS: Header con rating
            Row(
              children: [
                // SP4 REVIEWS: Avatar con inicial
                CircleAvatar(
                  backgroundColor: _getRatingColor(review.rating),
                  child: Icon(
                    _getRatingIcon(review.rating),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SP4 REVIEWS: Estrellas de rating
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < review.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Orden: ${review.orderId.substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // SP4 REVIEWS: Fecha
                Text(
                  _formatDate(review.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            // SP4 REVIEWS: Comentario
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  review.comment!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            
            // SP4 REVIEWS: IDs (solo en debug)
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Rater: ${review.raterId.substring(0, 8)}... → Ratee: ${review.rateeId.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // SP4 REVIEWS: HELPERS DE UI
  // ============================================================================

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  IconData _getRatingIcon(int rating) {
    if (rating >= 4) return Icons.thumb_up;
    if (rating >= 3) return Icons.sentiment_neutral;
    return Icons.thumb_down;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks semana${weeks > 1 ? 's' : ''}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    print('SP4 REVIEWS: Disposing ReviewsPage...');
    super.dispose();
  }
}
