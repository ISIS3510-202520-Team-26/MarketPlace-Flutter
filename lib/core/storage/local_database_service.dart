// lib/core/storage/local_database_service.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/listing.dart';
import '../../data/models/category.dart';
import '../../data/models/brand.dart';

/// Servicio de Base de Datos Local SQLite
/// 
/// Gestiona una copia local de los datos del backend (listings, categories, brands)
/// para que la app funcione offline y tenga respuestas instantáneas.
/// 
/// Arquitectura:
/// - Tablas: listings, categories, brands
/// - Sincronización: descarga datos del backend y los almacena localmente
/// - Consultas: lee primero de local, actualiza en background
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;
  
  /// Obtiene la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos SQLite
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'market_app.db');
    
    print('[LocalDB] 📦 Inicializando base de datos en: $path');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea las tablas de la base de datos
  Future<void> _onCreate(Database db, int version) async {
    print('[LocalDB] 🔨 Creando tablas...');
    
    // Tabla de categorías
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');
    
    // Tabla de marcas
    await db.execute('''
      CREATE TABLE brands (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT NOT NULL,
        category_id TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
    
    // Tabla de listings
    await db.execute('''
      CREATE TABLE listings (
        id TEXT PRIMARY KEY,
        seller_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        category_id TEXT NOT NULL,
        brand_id TEXT,
        price_cents INTEGER NOT NULL,
        currency TEXT NOT NULL,
        condition TEXT,
        quantity INTEGER NOT NULL,
        is_active INTEGER NOT NULL,
        latitude REAL,
        longitude REAL,
        price_suggestion_used INTEGER NOT NULL,
        quick_view_enabled INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (brand_id) REFERENCES brands(id)
      )
    ''');
    
    // Índices para mejorar rendimiento de búsquedas
    await db.execute('CREATE INDEX idx_listings_category ON listings(category_id)');
    await db.execute('CREATE INDEX idx_listings_brand ON listings(brand_id)');
    await db.execute('CREATE INDEX idx_listings_active ON listings(is_active)');
    await db.execute('CREATE INDEX idx_listings_seller ON listings(seller_id)');
    await db.execute('CREATE INDEX idx_brands_category ON brands(category_id)');
    
    print('[LocalDB] ✅ Tablas creadas exitosamente');
  }

  /// Actualiza el esquema de la base de datos
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('[LocalDB] 🔄 Actualizando base de datos de v$oldVersion a v$newVersion');
    // Futuras migraciones se manejarían aquí
  }

  // ==================== CATEGORIES ====================

  /// Guarda categorías en la base de datos local
  Future<void> saveCategories(List<Category> categories) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    
    for (final category in categories) {
      batch.insert(
        'categories',
        {
          'id': category.id,
          'name': category.name,
          'slug': category.slug,
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    print('[LocalDB] 💾 Guardadas ${categories.length} categorías');
  }

  /// Obtiene todas las categorías de la base de datos local
  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    
    return maps.map((map) => Category(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
    )).toList();
  }

  /// Obtiene una categoría por ID
  Future<Category?> getCategoryById(String id) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
    );
  }

  // ==================== BRANDS ====================

  /// Guarda marcas en la base de datos local
  Future<void> saveBrands(List<Brand> brands) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    
    for (final brand in brands) {
      batch.insert(
        'brands',
        {
          'id': brand.id,
          'name': brand.name,
          'slug': brand.slug,
          'category_id': brand.categoryId,
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    print('[LocalDB] 💾 Guardadas ${brands.length} marcas');
  }

  /// Obtiene todas las marcas de la base de datos local
  Future<List<Brand>> getBrands({String? categoryId}) async {
    final db = await database;
    final maps = await db.query(
      'brands',
      where: categoryId != null ? 'category_id = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'name ASC',
    );
    
    return maps.map((map) => Brand(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      categoryId: map['category_id'] as String?,
    )).toList();
  }

  /// Obtiene una marca por ID
  Future<Brand?> getBrandById(String id) async {
    final db = await database;
    final maps = await db.query(
      'brands',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    return Brand(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      categoryId: map['category_id'] as String?,
    );
  }

  // ==================== LISTINGS ====================

  /// Guarda listings en la base de datos local
  Future<void> saveListings(List<Listing> listings) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    
    for (final listing in listings) {
      batch.insert(
        'listings',
        {
          'id': listing.id,
          'seller_id': listing.sellerId,
          'title': listing.title,
          'description': listing.description,
          'category_id': listing.categoryId,
          'brand_id': listing.brandId,
          'price_cents': listing.priceCents,
          'currency': listing.currency,
          'condition': listing.condition,
          'quantity': listing.quantity,
          'is_active': listing.isActive ? 1 : 0,
          'latitude': listing.latitude,
          'longitude': listing.longitude,
          'price_suggestion_used': listing.priceSuggestionUsed ? 1 : 0,
          'quick_view_enabled': listing.quickViewEnabled ? 1 : 0,
          'created_at': listing.createdAt.toIso8601String(),
          'updated_at': listing.updatedAt.toIso8601String(),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    print('[LocalDB] 💾 Guardados ${listings.length} listings');
  }

  /// Obtiene listings de la base de datos local con filtros
  Future<List<Listing>> getListings({
    String? categoryId,
    String? brandId,
    bool? isActive,
    int? minPrice,
    int? maxPrice,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    
    // Construir WHERE clause dinámicamente
    final conditions = <String>[];
    final args = <dynamic>[];
    
    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    
    if (brandId != null) {
      conditions.add('brand_id = ?');
      args.add(brandId);
    }
    
    if (isActive != null) {
      conditions.add('is_active = ?');
      args.add(isActive ? 1 : 0);
    }
    
    if (minPrice != null) {
      conditions.add('price_cents >= ?');
      args.add(minPrice);
    }
    
    if (maxPrice != null) {
      conditions.add('price_cents <= ?');
      args.add(maxPrice);
    }
    
    final maps = await db.query(
      'listings',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    
    return maps.map(_listingFromMap).toList();
  }

  /// Obtiene un listing por ID
  Future<Listing?> getListingById(String id) async {
    final db = await database;
    final maps = await db.query(
      'listings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return _listingFromMap(maps.first);
  }

  /// Busca listings por texto (título o descripción)
  Future<List<Listing>> searchListings(String query) async {
    final db = await database;
    final maps = await db.query(
      'listings',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    
    return maps.map(_listingFromMap).toList();
  }

  /// Obtiene el conteo de listings
  Future<int> getListingsCount({
    String? categoryId,
    String? brandId,
    bool? isActive,
  }) async {
    final db = await database;
    
    final conditions = <String>[];
    final args = <dynamic>[];
    
    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    
    if (brandId != null) {
      conditions.add('brand_id = ?');
      args.add(brandId);
    }
    
    if (isActive != null) {
      conditions.add('is_active = ?');
      args.add(isActive ? 1 : 0);
    }
    
    final result = await db.query(
      'listings',
      columns: ['COUNT(*) as count'],
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
    );
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== SYNC & CLEANUP ====================

  /// Obtiene la fecha de la última sincronización
  Future<DateTime?> getLastSyncTime() async {
    final db = await database;
    
    // Buscar la fecha más reciente entre todas las tablas
    final listings = await db.query('listings', orderBy: 'synced_at DESC', limit: 1);
    final categories = await db.query('categories', orderBy: 'synced_at DESC', limit: 1);
    final brands = await db.query('brands', orderBy: 'synced_at DESC', limit: 1);
    
    DateTime? lastSync;
    
    if (listings.isNotEmpty) {
      final syncedAt = DateTime.parse(listings.first['synced_at'] as String);
      lastSync = syncedAt;
    }
    
    if (categories.isNotEmpty) {
      final syncedAt = DateTime.parse(categories.first['synced_at'] as String);
      if (lastSync == null || syncedAt.isAfter(lastSync)) {
        lastSync = syncedAt;
      }
    }
    
    if (brands.isNotEmpty) {
      final syncedAt = DateTime.parse(brands.first['synced_at'] as String);
      if (lastSync == null || syncedAt.isAfter(lastSync)) {
        lastSync = syncedAt;
      }
    }
    
    return lastSync;
  }

  /// Elimina datos antiguos para liberar espacio
  Future<void> cleanupOldData({int maxAgeDays = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));
    final cutoff = cutoffDate.toIso8601String();
    
    final deletedListings = await db.delete(
      'listings',
      where: 'synced_at < ?',
      whereArgs: [cutoff],
    );
    
    print('[LocalDB] 🧹 Limpiados $deletedListings listings antiguos');
  }

  /// Limpia toda la base de datos
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('listings');
    await db.delete('brands');
    await db.delete('categories');
    print('[LocalDB] 🗑️ Base de datos limpiada');
  }

  /// Cierra la base de datos
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('[LocalDB] 🔒 Base de datos cerrada');
    }
  }

  // ==================== HELPERS ====================

  /// Convierte un Map de la DB a un objeto Listing
  Listing _listingFromMap(Map<String, dynamic> map) {
    return Listing(
      id: map['id'] as String,
      sellerId: map['seller_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as String,
      brandId: map['brand_id'] as String?,
      priceCents: map['price_cents'] as int,
      currency: map['currency'] as String,
      condition: map['condition'] as String?,
      quantity: map['quantity'] as int,
      isActive: (map['is_active'] as int) == 1,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      priceSuggestionUsed: (map['price_suggestion_used'] as int) == 1,
      quickViewEnabled: (map['quick_view_enabled'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
