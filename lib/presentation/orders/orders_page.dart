import 'package:flutter/material.dart';
import '../../data/repositories/orders_repository.dart';
import '../../data/repositories/local_sync_repository.dart';
import '../../data/models/order.dart';
import 'package:intl/intl.dart';
import '../../core/net/connectivity_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  // SP4 ORDERS: Repositories
  final _ordersRepo = OrdersRepository();
  final _localSyncRepo = LocalSyncRepository(baseUrl: 'http://3.19.208.242:8000/v1');
  final _connectivity = ConnectivityService.instance;

  // SP4 ORDERS: Estado
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  bool _isOnline = true;
  bool _usingCache = false;

  @override
  void initState() {
    super.initState();
    print('SP4 ORDERS: Inicializando OrdersPage...');
    _loadOrders();
    _checkConnectivity();
  }

  // ============================================================================
  // SP4 ORDERS: VERIFICAR CONECTIVIDAD
  // ============================================================================
  Future<void> _checkConnectivity() async {
    print('SP4 ORDERS: Verificando conectividad...');
    
    final isConnected = await _connectivity.isOnline;
    setState(() {
      _isOnline = isConnected;
    });
    
    if (isConnected && _usingCache) {
      print('SP4 ORDERS: Conexión restaurada - sincronizando...');
      _syncOrders();
    }
  }

  // ============================================================================
  // SP4 ORDERS: CARGAR ORDENES (ASYNC/AWAIT)
  // ============================================================================
  Future<void> _loadOrders() async {
    print('SP4 ORDERS: Cargando órdenes...');
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isConnected = await _connectivity.isOnline;
      
      if (isConnected) {
        // SP4 ORDERS: Online - cargar desde Backend con async/await
        print('SP4 ORDERS: Modo ONLINE - cargando desde Backend...');
        await _loadFromBackend();
      } else {
        // SP4 ORDERS: Offline - cargar desde SQLite
        print('SP4 ORDERS: Modo OFFLINE - cargando desde SQLite...');
        await _loadFromCache();
      }
    } catch (e) {
      print('SP4 ORDERS: Error al cargar órdenes: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ============================================================================
  // SP4 ORDERS: CARGAR DESDE BACKEND (ASYNC/AWAIT)
  // ============================================================================
  Future<void> _loadFromBackend() async {
    print('SP4 ORDERS: GET /orders desde Backend...');
    
    try {
      // SP4 ORDERS: Usa async/await para esperar las órdenes
      final orders = await _ordersRepo.getMyOrders(pageSize: 50);
      
      print('SP4 ORDERS: ${orders.length} órdenes obtenidas del Backend');
      
      // SP4 ORDERS: Cachear en SQLite para modo offline
      await _cacheOrders(orders);
      
      setState(() {
        _orders = orders;
        _loading = false;
        _usingCache = false;
      });
    } catch (e) {
      print('SP4 ORDERS: Error al cargar desde Backend: $e');
      
      // SP4 ORDERS: Fallback a cache si hay error de red
      await _loadFromCache();
    }
  }

  // ============================================================================
  // SP4 ORDERS: CARGAR DESDE CACHE SQLITE
  // ============================================================================
  Future<void> _loadFromCache() async {
    print('SP4 ORDERS: Cargando desde SQLite cache...');
    
    try {
      // SP4 ORDERS: Obtiene órdenes desde base de datos local
      final cachedOrdersData = await _localSyncRepo.getLocalOrders();
      
      // SP4 ORDERS: Convertir Map a Order
      final cachedOrders = cachedOrdersData.map((data) => Order.fromJson(data)).toList();
      
      print('SP4 ORDERS: ${cachedOrders.length} órdenes obtenidas del cache SQLite');
      
      setState(() {
        _orders = cachedOrders;
        _loading = false;
        _usingCache = true;
      });
      
      if (cachedOrders.isEmpty) {
        setState(() {
          _error = 'No hay órdenes en cache. Conéctate a internet para sincronizar.';
        });
      }
    } catch (e) {
      print('SP4 ORDERS: Error al cargar desde cache: $e');
      setState(() {
        _error = 'Error al cargar órdenes del cache local';
        _loading = false;
      });
    }
  }

  // ============================================================================
  // SP4 ORDERS: CACHEAR ORDENES EN SQLITE
  // ============================================================================
  Future<void> _cacheOrders(List<Order> orders) async {
    print('SP4 ORDERS: Cacheando ${orders.length} órdenes en SQLite...');
    
    try {
      for (final order in orders) {
        // Convertir a Map para SQLite
        final orderMap = {
          'id': order.id,
          'buyer_id': order.buyerId,
          'seller_id': order.sellerId,
          'listing_id': order.listingId,
          'status': order.status,
          'total_cents': order.totalCents,
          'currency': order.currency,
          'created_at': order.createdAt.toIso8601String(),
        };
        
        await _localSyncRepo.saveOrderToLocal(orderMap);
      }
      
      print('SP4 ORDERS: Órdenes cacheadas exitosamente en SQLite');
    } catch (e) {
      print('SP4 ORDERS: Error al cachear órdenes: $e');
    }
  }

  // ============================================================================
  // SP4 ORDERS: SINCRONIZAR CON BACKEND
  // ============================================================================
  Future<void> _syncOrders() async {
    print('SP4 ORDERS: Sincronizando con Backend...');
    
    try {
      await _localSyncRepo.syncOrdersFromBackend(limit: 50);
      _loadOrders();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Órdenes sincronizadas exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('SP4 ORDERS: Error al sincronizar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sincronizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Órdenes'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // SP4 ORDERS: Indicador de conectividad
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    _isOnline ? Icons.cloud_done : Icons.cloud_off,
                    color: _isOnline ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // SP4 ORDERS: Botón de sincronización
          if (_isOnline)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncOrders,
              tooltip: 'Sincronizar con Backend',
            ),
        ],
      ),
      body: Column(
        children: [
          // SP4 ORDERS: Banner de modo cache
          if (_usingCache)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.storage, color: Colors.orange.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modo offline: Mostrando ${_orders.length} órdenes del cache SQLite',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // Lista de órdenes
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadOrders,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _orders.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No tienes órdenes aún'),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              itemCount: _orders.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                return _buildOrderCard(order);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SP4 ORDERS: WIDGET DE ORDEN
  // ============================================================================
  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          'Orden #${order.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Estado: ${_getStatusText(order.status)}'),
            Text('Total: ${_formatPrice(order.totalCents, order.currency)}'),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: statusColor),
        onTap: () {
          // TODO: Navegar a detalle de orden
          print('SP4 ORDERS: Orden seleccionada: ${order.id}');
        },
      ),
    );
  }

  // ============================================================================
  // SP4 ORDERS: HELPERS
  // ============================================================================
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'paid':
        return Icons.payment;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pendiente';
      case 'paid':
        return 'Pagada';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  String _formatPrice(int cents, String currency) {
    final amount = cents / 100;
    return NumberFormat.currency(
      symbol: currency == 'USD' ? '\$' : '\$',
      decimalDigits: 0,
    ).format(amount);
  }
}
