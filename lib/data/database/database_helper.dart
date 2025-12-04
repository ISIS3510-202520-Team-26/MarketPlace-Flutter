// ============================================================================
// SP4 DB: DATABASE HELPER - BASE DE DATOS LOCAL RELACIONAL (SQLite)
// ============================================================================
// Este archivo implementa la capa de acceso a la base de datos local SQLite
// con esquema relacional que replica las entidades principales del Backend:
// - Users (usuarios)
// - Listings (publicaciones)
// - Orders (ordenes)
// - Reviews (resenas)
//
// RELACIONES IMPLEMENTADAS:
// - User 1:N Listings (un usuario puede tener muchas publicaciones)
// - User 1:N Orders (como buyer y como seller)
// - Listing 1:N Orders (una publicacion puede tener muchas ordenes)
// - Order 1:1 Review (una orden puede tener una resena)
// - User 1:N Reviews (como rater y como ratee)
//
// TECNOLOGIA: sqflite (SQLite para Flutter)
// MARCADORES: Todos los metodos tienen comentarios "SP4 DB:" para visibilidad
// ============================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ============================================================================
// SP4 DB: CLASE PRINCIPAL - SINGLETON PARA GESTIONAR LA BD
// ============================================================================
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // SP4 DB: Getter para obtener la instancia de la BD
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    print('SP4 DB: Inicializando base de datos SQLite...');
    _database = await _initDatabase();
    print('SP4 DB: Base de datos inicializada exitosamente');
    
    return _database!;
  }

  // ============================================================================
  // SP4 DB: INICIALIZACION DE LA BASE DE DATOS
  // ============================================================================
  // Crea la base de datos y todas las tablas con sus relaciones
  Future<Database> _initDatabase() async {
    print('SP4 DB: Obteniendo ruta de la base de datos...');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'marketplace_sp4.db');
    
    print('SP4 DB: Ruta de BD: $path');
    print('SP4 DB: Creando/abriendo base de datos...');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onOpen: (db) {
        print('SP4 DB: Base de datos abierta correctamente');
      },
    );
  }

  // ============================================================================
  // SP4 DB: CREACION DE ESQUEMA - TABLAS Y RELACIONES
  // ============================================================================
  Future<void> _createDatabase(Database db, int version) async {
    print('SP4 DB: Creando esquema de base de datos...');
    
    // SP4 DB: Tabla USERS - Usuarios del sistema
    print('SP4 DB: Creando tabla USERS...');
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        campus TEXT,
        created_at TEXT NOT NULL,
        last_synced_at TEXT NOT NULL
      )
    ''');
    print('SP4 DB: Tabla USERS creada');

    // SP4 DB: Tabla LISTINGS - Publicaciones de productos
    print('SP4 DB: Creando tabla LISTINGS...');
    await db.execute('''
      CREATE TABLE listings (
        id TEXT PRIMARY KEY,
        seller_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        category_id TEXT NOT NULL,
        brand_id TEXT,
        price_cents INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'COP',
        condition TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        latitude REAL,
        longitude REAL,
        price_suggestion_used INTEGER NOT NULL DEFAULT 0,
        quick_view_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT NOT NULL,
        FOREIGN KEY (seller_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    print('SP4 DB: Tabla LISTINGS creada');

    // SP4 DB: Indices para optimizar consultas de LISTINGS
    print('SP4 DB: Creando indices para LISTINGS...');
    await db.execute('CREATE INDEX idx_listings_seller ON listings(seller_id)');
    await db.execute('CREATE INDEX idx_listings_category ON listings(category_id)');
    await db.execute('CREATE INDEX idx_listings_active ON listings(is_active)');
    print('SP4 DB: Indices de LISTINGS creados');

    // SP4 DB: Tabla ORDERS - Ordenes de compra
    print('SP4 DB: Creando tabla ORDERS...');
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        buyer_id TEXT NOT NULL,
        seller_id TEXT NOT NULL,
        listing_id TEXT NOT NULL,
        total_cents INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'COP',
        status TEXT NOT NULL DEFAULT 'created',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT NOT NULL,
        FOREIGN KEY (buyer_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (seller_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
      )
    ''');
    print('SP4 DB: Tabla ORDERS creada');

    // SP4 DB: Indices para optimizar consultas de ORDERS
    print('SP4 DB: Creando indices para ORDERS...');
    await db.execute('CREATE INDEX idx_orders_buyer ON orders(buyer_id)');
    await db.execute('CREATE INDEX idx_orders_seller ON orders(seller_id)');
    await db.execute('CREATE INDEX idx_orders_listing ON orders(listing_id)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    print('SP4 DB: Indices de ORDERS creados');

    // SP4 DB: Tabla REVIEWS - Resenas de ordenes
    print('SP4 DB: Creando tabla REVIEWS...');
    await db.execute('''
      CREATE TABLE reviews (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL UNIQUE,
        rater_id TEXT NOT NULL,
        ratee_id TEXT NOT NULL,
        rating INTEGER NOT NULL,
        comment TEXT,
        created_at TEXT NOT NULL,
        last_synced_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (rater_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (ratee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    print('SP4 DB: Tabla REVIEWS creada');

    // SP4 DB: Indices para optimizar consultas de REVIEWS
    print('SP4 DB: Creando indices para REVIEWS...');
    await db.execute('CREATE INDEX idx_reviews_order ON reviews(order_id)');
    await db.execute('CREATE INDEX idx_reviews_rater ON reviews(rater_id)');
    await db.execute('CREATE INDEX idx_reviews_ratee ON reviews(ratee_id)');
    print('SP4 DB: Indices de REVIEWS creados');

    print('SP4 DB: ESQUEMA COMPLETO CREADO - 4 tablas con relaciones');
  }

  // ============================================================================
  // SP4 DB: OPERACIONES CRUD - USERS
  // ============================================================================

  // SP4 DB: Insertar o actualizar usuario
  Future<int> upsertUser(Map<String, dynamic> user) async {
    print('SP4 DB: Upsert usuario: ${user['id']}');
    final db = await database;
    
    user['last_synced_at'] = DateTime.now().toIso8601String();
    
    final result = await db.insert(
      'users',
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('SP4 DB: Usuario guardado exitosamente');
    return result;
  }

  // SP4 DB: Obtener usuario por ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    print('SP4 DB: Consultando usuario: $userId');
    final db = await database;
    
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    
    if (results.isEmpty) {
      print('SP4 DB: Usuario no encontrado');
      return null;
    }
    
    print('SP4 DB: Usuario encontrado: ${results.first['name']}');
    return results.first;
  }

  // SP4 DB: Obtener todos los usuarios
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    print('SP4 DB: Consultando todos los usuarios...');
    final db = await database;
    
    final results = await db.query('users', orderBy: 'name ASC');
    
    print('SP4 DB: ${results.length} usuarios encontrados');
    return results;
  }

  // ============================================================================
  // SP4 DB: OPERACIONES CRUD - LISTINGS
  // ============================================================================

  // SP4 DB: Insertar o actualizar listing
  Future<int> upsertListing(Map<String, dynamic> listing) async {
    print('SP4 DB: Upsert listing: ${listing['id']}');
    final db = await database;
    
    listing['last_synced_at'] = DateTime.now().toIso8601String();
    
    final result = await db.insert(
      'listings',
      listing,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('SP4 DB: Listing guardado exitosamente');
    return result;
  }

  // SP4 DB: Obtener listing por ID
  Future<Map<String, dynamic>?> getListingById(String listingId) async {
    print('SP4 DB: Consultando listing: $listingId');
    final db = await database;
    
    final results = await db.query(
      'listings',
      where: 'id = ?',
      whereArgs: [listingId],
      limit: 1,
    );
    
    if (results.isEmpty) {
      print('SP4 DB: Listing no encontrado');
      return null;
    }
    
    print('SP4 DB: Listing encontrado: ${results.first['title']}');
    return results.first;
  }

  // SP4 DB: Obtener listings por seller
  Future<List<Map<String, dynamic>>> getListingsBySeller(String sellerId) async {
    print('SP4 DB: Consultando listings del vendedor: $sellerId');
    final db = await database;
    
    final results = await db.query(
      'listings',
      where: 'seller_id = ?',
      whereArgs: [sellerId],
      orderBy: 'created_at DESC',
    );
    
    print('SP4 DB: ${results.length} listings encontrados');
    return results;
  }

  // SP4 DB: Obtener listings activos
  Future<List<Map<String, dynamic>>> getActiveListings({int? limit}) async {
    print('SP4 DB: Consultando listings activos...');
    final db = await database;
    
    final results = await db.query(
      'listings',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    
    print('SP4 DB: ${results.length} listings activos encontrados');
    return results;
  }

  // ============================================================================
  // SP4 DB: OPERACIONES CRUD - ORDERS
  // ============================================================================

  // SP4 DB: Insertar o actualizar orden
  Future<int> upsertOrder(Map<String, dynamic> order) async {
    print('SP4 DB: Upsert orden: ${order['id']}');
    final db = await database;
    
    order['last_synced_at'] = DateTime.now().toIso8601String();
    
    final result = await db.insert(
      'orders',
      order,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('SP4 DB: Orden guardada exitosamente');
    return result;
  }

  // SP4 DB: Obtener orden por ID
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    print('SP4 DB: Consultando orden: $orderId');
    final db = await database;
    
    final results = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    
    if (results.isEmpty) {
      print('SP4 DB: Orden no encontrada');
      return null;
    }
    
    print('SP4 DB: Orden encontrada: status=${results.first['status']}');
    return results.first;
  }

  // SP4 DB: Obtener ordenes por buyer
  Future<List<Map<String, dynamic>>> getOrdersByBuyer(String buyerId) async {
    print('SP4 DB: Consultando ordenes del comprador: $buyerId');
    final db = await database;
    
    final results = await db.query(
      'orders',
      where: 'buyer_id = ?',
      whereArgs: [buyerId],
      orderBy: 'created_at DESC',
    );
    
    print('SP4 DB: ${results.length} ordenes encontradas');
    return results;
  }

  // SP4 DB: Obtener ordenes por seller
  Future<List<Map<String, dynamic>>> getOrdersBySeller(String sellerId) async {
    print('SP4 DB: Consultando ordenes del vendedor: $sellerId');
    final db = await database;
    
    final results = await db.query(
      'orders',
      where: 'seller_id = ?',
      whereArgs: [sellerId],
      orderBy: 'created_at DESC',
    );
    
    print('SP4 DB: ${results.length} ordenes encontradas');
    return results;
  }

  // SP4 DB: Obtener ordenes por status
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    print('SP4 DB: Consultando ordenes con status: $status');
    final db = await database;
    
    final results = await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    
    print('SP4 DB: ${results.length} ordenes encontradas');
    return results;
  }

  // ============================================================================
  // SP4 DB: OPERACIONES CRUD - REVIEWS
  // ============================================================================

  // SP4 DB: Insertar o actualizar review
  Future<int> upsertReview(Map<String, dynamic> review) async {
    print('SP4 DB: Upsert review: ${review['id']}');
    final db = await database;
    
    review['last_synced_at'] = DateTime.now().toIso8601String();
    
    final result = await db.insert(
      'reviews',
      review,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('SP4 DB: Review guardada exitosamente');
    return result;
  }

  // SP4 DB: Obtener review por ID
  Future<Map<String, dynamic>?> getReviewById(String reviewId) async {
    print('SP4 DB: Consultando review: $reviewId');
    final db = await database;
    
    final results = await db.query(
      'reviews',
      where: 'id = ?',
      whereArgs: [reviewId],
      limit: 1,
    );
    
    if (results.isEmpty) {
      print('SP4 DB: Review no encontrada');
      return null;
    }
    
    print('SP4 DB: Review encontrada: rating=${results.first['rating']}');
    return results.first;
  }

  // SP4 DB: Obtener review por orden
  Future<Map<String, dynamic>?> getReviewByOrder(String orderId) async {
    print('SP4 DB: Consultando review de orden: $orderId');
    final db = await database;
    
    final results = await db.query(
      'reviews',
      where: 'order_id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    
    if (results.isEmpty) {
      print('SP4 DB: Review de orden no encontrada');
      return null;
    }
    
    print('SP4 DB: Review de orden encontrada');
    return results.first;
  }

  // SP4 DB: Obtener reviews por rater (quien califica)
  Future<List<Map<String, dynamic>>> getReviewsByRater(String raterId) async {
    print('SP4 DB: Consultando reviews hechas por: $raterId');
    final db = await database;
    
    final results = await db.query(
      'reviews',
      where: 'rater_id = ?',
      whereArgs: [raterId],
      orderBy: 'created_at DESC',
    );
    
    print('SP4 DB: ${results.length} reviews encontradas');
    return results;
  }

  // SP4 DB: Obtener reviews por ratee (quien recibe la calificacion)
  Future<List<Map<String, dynamic>>> getReviewsByRatee(String rateeId) async {
    print('SP4 DB: Consultando reviews recibidas por: $rateeId');
    final db = await database;
    
    final results = await db.query(
      'reviews',
      where: 'ratee_id = ?',
      whereArgs: [rateeId],
      orderBy: 'created_at DESC',
    );
    
    print('SP4 DB: ${results.length} reviews encontradas');
    return results;
  }

  // ============================================================================
  // SP4 DB: CONSULTAS RELACIONALES (JOINS)
  // ============================================================================

  // SP4 DB: Obtener listing con datos del seller
  Future<Map<String, dynamic>?> getListingWithSeller(String listingId) async {
    print('SP4 DB: Consultando listing con seller (JOIN)...');
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT 
        l.*,
        u.name as seller_name,
        u.email as seller_email,
        u.campus as seller_campus
      FROM listings l
      INNER JOIN users u ON l.seller_id = u.id
      WHERE l.id = ?
      LIMIT 1
    ''', [listingId]);
    
    if (results.isEmpty) {
      print('SP4 DB: Listing con seller no encontrado');
      return null;
    }
    
    print('SP4 DB: Listing con seller encontrado: ${results.first['title']} by ${results.first['seller_name']}');
    return results.first;
  }

  // SP4 DB: Obtener orden con todos sus datos relacionados
  Future<Map<String, dynamic>?> getOrderWithDetails(String orderId) async {
    print('SP4 DB: Consultando orden con detalles (MULTIPLE JOINS)...');
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT 
        o.*,
        l.title as listing_title,
        l.price_cents as listing_price,
        buyer.name as buyer_name,
        buyer.email as buyer_email,
        seller.name as seller_name,
        seller.email as seller_email
      FROM orders o
      INNER JOIN listings l ON o.listing_id = l.id
      INNER JOIN users buyer ON o.buyer_id = buyer.id
      INNER JOIN users seller ON o.seller_id = seller.id
      WHERE o.id = ?
      LIMIT 1
    ''', [orderId]);
    
    if (results.isEmpty) {
      print('SP4 DB: Orden con detalles no encontrada');
      return null;
    }
    
    print('SP4 DB: Orden con detalles encontrada: ${results.first['listing_title']}');
    return results.first;
  }

  // SP4 DB: Obtener review con datos de la orden y usuarios
  Future<Map<String, dynamic>?> getReviewWithDetails(String reviewId) async {
    print('SP4 DB: Consultando review con detalles (MULTIPLE JOINS)...');
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT 
        r.*,
        o.total_cents as order_total,
        o.status as order_status,
        l.title as listing_title,
        rater.name as rater_name,
        ratee.name as ratee_name
      FROM reviews r
      INNER JOIN orders o ON r.order_id = o.id
      INNER JOIN listings l ON o.listing_id = l.id
      INNER JOIN users rater ON r.rater_id = rater.id
      INNER JOIN users ratee ON r.ratee_id = ratee.id
      WHERE r.id = ?
      LIMIT 1
    ''', [reviewId]);
    
    if (results.isEmpty) {
      print('SP4 DB: Review con detalles no encontrada');
      return null;
    }
    
    print('SP4 DB: Review con detalles encontrada: ${results.first['rater_name']} -> ${results.first['ratee_name']}');
    return results.first;
  }

  // ============================================================================
  // SP4 DB: AGREGACIONES Y ESTADISTICAS
  // ============================================================================

  // SP4 DB: Calcular rating promedio de un usuario
  Future<double> calculateAverageRating(String userId) async {
    print('SP4 DB: Calculando rating promedio para usuario: $userId');
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT AVG(rating) as avg_rating, COUNT(*) as total_reviews
      FROM reviews
      WHERE ratee_id = ?
    ''', [userId]);
    
    final avgRating = results.first['avg_rating'] as double? ?? 0.0;
    final totalReviews = results.first['total_reviews'] as int? ?? 0;
    
    print('SP4 DB: Rating promedio: $avgRating ($totalReviews reviews)');
    return avgRating;
  }

  // SP4 DB: Contar ordenes por status de un usuario
  Future<Map<String, int>> countOrdersByStatus(String userId) async {
    print('SP4 DB: Contando ordenes por status para usuario: $userId');
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM orders
      WHERE buyer_id = ? OR seller_id = ?
      GROUP BY status
    ''', [userId, userId]);
    
    final counts = <String, int>{};
    for (final row in results) {
      counts[row['status'] as String] = row['count'] as int;
    }
    
    print('SP4 DB: Conteo completado: $counts');
    return counts;
  }

  // SP4 DB: Obtener estadisticas de un seller
  Future<Map<String, dynamic>> getSellerStats(String sellerId) async {
    print('SP4 DB: Calculando estadisticas del vendedor: $sellerId');
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT l.id) as total_listings,
        COUNT(DISTINCT o.id) as total_orders,
        SUM(CASE WHEN o.status = 'completed' THEN o.total_cents ELSE 0 END) as total_revenue,
        AVG(CASE WHEN o.status = 'completed' THEN o.total_cents ELSE NULL END) as avg_order_value
      FROM users u
      LEFT JOIN listings l ON u.id = l.seller_id
      LEFT JOIN orders o ON l.id = o.listing_id
      WHERE u.id = ?
    ''', [sellerId]);
    
    final stats = results.first;
    print('SP4 DB: Estadisticas calculadas: ${stats['total_listings']} listings, ${stats['total_orders']} ordenes');
    
    return {
      'total_listings': stats['total_listings'] ?? 0,
      'total_orders': stats['total_orders'] ?? 0,
      'total_revenue': stats['total_revenue'] ?? 0,
      'avg_order_value': stats['avg_order_value'] ?? 0,
    };
  }

  // ============================================================================
  // SP4 DB: UTILIDADES Y MANTENIMIENTO
  // ============================================================================

  // SP4 DB: Limpiar toda la base de datos
  Future<void> clearDatabase() async {
    print('SP4 DB: Limpiando toda la base de datos...');
    final db = await database;
    
    await db.delete('reviews');
    await db.delete('orders');
    await db.delete('listings');
    await db.delete('users');
    
    print('SP4 DB: Base de datos limpiada completamente');
  }

  // SP4 DB: Contar registros en todas las tablas
  Future<Map<String, int>> countAllRecords() async {
    print('SP4 DB: Contando registros en todas las tablas...');
    final db = await database;
    
    final userCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    ) ?? 0;
    
    final listingCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM listings'),
    ) ?? 0;
    
    final orderCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM orders'),
    ) ?? 0;
    
    final reviewCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reviews'),
    ) ?? 0;
    
    final counts = {
      'users': userCount,
      'listings': listingCount,
      'orders': orderCount,
      'reviews': reviewCount,
    };
    
    print('SP4 DB: Conteo completado: $counts');
    return counts;
  }

  // SP4 DB: Cerrar conexion a la base de datos
  Future<void> close() async {
    print('SP4 DB: Cerrando conexion a la base de datos...');
    final db = await database;
    await db.close();
    _database = null;
    print('SP4 DB: Conexion cerrada');
  }
}
