// lib/data/repositories/offline_catalog_repository.dart
import '../models/brand.dart';
import '../models/category.dart';
import '../../core/storage/storage.dart';
import 'catalog_repository.dart';

/// Wrapper de CatalogRepository con soporte offline usando LocalDatabaseService
/// 
/// **Estrategia:**
/// 1. Intenta primero traer datos del API
/// 2. Si tiene éxito, guarda en BD local (SQLite)
/// 3. Si falla por falta de conexión, usa BD local
/// 
/// **Uso:**
/// ```dart
/// final repo = OfflineCatalogRepository();
/// final categories = await repo.getCategories(); // API first, fallback a SQLite
/// ```
class OfflineCatalogRepository with OfflineRepositoryMixin {
  final _apiRepo = CatalogRepository();
  final _localDb = LocalDatabaseService();

  /// Obtiene categorías con soporte offline
  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    if (forceRefresh) {
      // Si se fuerza refresh, ir directo al API
      final categories = await _apiRepo.getCategories();
      await _localDb.saveCategories(categories);
      return categories;
    }

    return executeWithFallback<List<Category>>(
      fetchFromApi: () async {
        print('[OfflineCatalog] 🌐 Obteniendo categorías del API...');
        return _apiRepo.getCategories();
      },
      saveToCache: (categories) async {
        print('[OfflineCatalog] 💾 Guardando ${categories.length} categorías en cache');
        await _localDb.saveCategories(categories);
      },
      fetchFromCache: () async {
        print('[OfflineCatalog] 📦 Cargando categorías del cache local');
        return _localDb.getCategories();
      },
      errorMessage: 'Error al obtener categorías',
    );
  }

  /// Obtiene marcas con soporte offline
  Future<List<Brand>> getBrands({String? categoryId, bool forceRefresh = false}) async {
    if (forceRefresh) {
      final brands = await _apiRepo.getBrands(categoryId: categoryId);
      await _localDb.saveBrands(brands);
      return brands;
    }

    return executeWithFallback<List<Brand>>(
      fetchFromApi: () async {
        print('[OfflineCatalog] 🌐 Obteniendo marcas del API...');
        return _apiRepo.getBrands(categoryId: categoryId);
      },
      saveToCache: (brands) async {
        print('[OfflineCatalog] 💾 Guardando ${brands.length} marcas en cache');
        await _localDb.saveBrands(brands);
      },
      fetchFromCache: () async {
        print('[OfflineCatalog] 📦 Cargando marcas del cache local');
        return _localDb.getBrands(categoryId: categoryId);
      },
      errorMessage: 'Error al obtener marcas',
    );
  }

  /// Obtiene categoría por ID con soporte offline
  Future<Category?> getCategoryById(String id) async {
    return executeWithFallback<Category?>(
      fetchFromApi: () async {
        final categories = await _apiRepo.getCategories();
        return categories.where((c) => c.id == id).firstOrNull;
      },
      saveToCache: (category) async {
        if (category != null) {
          await _localDb.saveCategories([category]);
        }
      },
      fetchFromCache: () async {
        return _localDb.getCategoryById(id);
      },
      errorMessage: 'Error al obtener categoría',
    );
  }

  /// Obtiene marca por ID con soporte offline
  Future<Brand?> getBrandById(String id) async {
    return executeWithFallback<Brand?>(
      fetchFromApi: () async {
        final brands = await _apiRepo.getBrands();
        return brands.where((b) => b.id == id).firstOrNull;
      },
      saveToCache: (brand) async {
        if (brand != null) {
          await _localDb.saveBrands([brand]);
        }
      },
      fetchFromCache: () async {
        return _localDb.getBrandById(id);
      },
      errorMessage: 'Error al obtener marca',
    );
  }

  /// Crea una nueva categoría (requiere conexión)
  Future<Category> createCategory({
    required String name,
    String? slug,
  }) async {
    final category = await _apiRepo.createCategory(name: name, slug: slug);
    await _localDb.saveCategories([category]);
    return category;
  }

  /// Crea una nueva marca (requiere conexión)
  Future<Brand> createBrand({
    required String name,
    required String categoryId,
    String? slug,
  }) async {
    final brand = await _apiRepo.createBrand(
      name: name,
      categoryId: categoryId,
      slug: slug,
    );
    await _localDb.saveBrands([brand]);
    return brand;
  }

  /// Acceso directo a la BD local (útil para debug)
  LocalDatabaseService get localDatabase => _localDb;

  /// Acceso directo al repo del API (útil para operaciones que no necesitan cache)
  CatalogRepository get apiRepository => _apiRepo;
}
