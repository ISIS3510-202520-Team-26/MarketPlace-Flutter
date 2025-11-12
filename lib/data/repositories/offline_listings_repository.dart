// lib/data/repositories/offline_listings_repository.dart
import '../models/listing.dart';
import '../../core/storage/storage.dart';
import '../models/listing_photo.dart';
import '../models/price_suggestion.dart' show PriceSuggestion;
import 'listings_repository.dart';

/// Wrapper de ListingsRepository con soporte offline usando LocalDatabaseService
/// 
/// **Estrategia:**
/// 1. Intenta primero traer datos del API
/// 2. Si tiene éxito, guarda en BD local (SQLite)
/// 3. Si falla por falta de conexión, usa BD local
/// 
/// **Uso:**
/// ```dart
/// final repo = OfflineListingsRepository();
/// final listing = await repo.getListingById('123'); // API first, fallback a SQLite
/// ```
class OfflineListingsRepository with OfflineRepositoryMixin {
  final _apiRepo = ListingsRepository();
  final _localDb = LocalDatabaseService();

  /// Obtiene listing por ID con soporte offline
  Future<Listing> getListingById(String id, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      final listing = await _apiRepo.getListingById(id);
      await _localDb.saveListings([listing]);
      return listing;
    }

    return executeWithFallback<Listing>(
      fetchFromApi: () async {
        print('[OfflineListings] 🌐 Obteniendo listing $id del API...');
        return _apiRepo.getListingById(id);
      },
      saveToCache: (listing) async {
        print('[OfflineListings] 💾 Guardando listing en cache');
        await _localDb.saveListings([listing]);
      },
      fetchFromCache: () async {
        print('[OfflineListings] 📦 Cargando listing del cache local');
        return _localDb.getListingById(id);
      },
      errorMessage: 'Error al obtener listing',
    );
  }

  /// Busca listings con soporte offline (solo búsquedas simples en offline)
  Future<ListingsPage> searchListings({
    String? q,
    String? categoryId,
    String? brandId,
    int? minPrice,
    int? maxPrice,
    double? nearLat,
    double? nearLon,
    double? radiusKm,
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    // Búsquedas geográficas siempre requieren API
    final requiresApi = nearLat != null || nearLon != null;

    if (forceRefresh || requiresApi) {
      final results = await _apiRepo.searchListings(
        q: q,
        categoryId: categoryId,
        brandId: brandId,
        minPrice: minPrice,
        maxPrice: maxPrice,
        nearLat: nearLat,
        nearLon: nearLon,
        radiusKm: radiusKm,
        page: page,
        pageSize: pageSize,
      );
      
      // Guardar en cache
      await _localDb.saveListings(results.items);
      return results;
    }

    return executeWithFallback<ListingsPage>(
      fetchFromApi: () async {
        print('[OfflineListings] 🌐 Buscando listings en API...');
        return _apiRepo.searchListings(
          q: q,
          categoryId: categoryId,
          brandId: brandId,
          minPrice: minPrice,
          maxPrice: maxPrice,
          page: page,
          pageSize: pageSize,
        );
      },
      saveToCache: (results) async {
        print('[OfflineListings] 💾 Guardando ${results.items.length} listings en cache');
        await _localDb.saveListings(results.items);
      },
      fetchFromCache: () async {
        print('[OfflineListings] 📦 Buscando listings en cache local');
        final listings = await _searchInCache(
          q: q,
          categoryId: categoryId,
          brandId: brandId,
          minPrice: minPrice,
          maxPrice: maxPrice,
          limit: pageSize,
          offset: (page - 1) * pageSize,
        );

        return ListingsPage(
          items: listings,
          total: listings.length,
          page: page,
          pageSize: pageSize,
          hasNext: listings.length >= pageSize,
        );
      },
      errorMessage: 'Error al buscar listings',
    );
  }

  /// Búsqueda en cache local
  Future<List<Listing>> _searchInCache({
    String? q,
    String? categoryId,
    String? brandId,
    int? minPrice,
    int? maxPrice,
    int? limit,
    int? offset,
  }) async {
    if (q != null && q.isNotEmpty) {
      return _localDb.searchListings(q);
    }

    return _localDb.getListings(
      categoryId: categoryId,
      brandId: brandId,
      isActive: true,
      minPrice: minPrice,
      maxPrice: maxPrice,
      limit: limit,
      offset: offset,
    );
  }

  /// Obtiene listings cercanos (requiere API)
  Future<List<Listing>> getListingsNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int limit = 50,
  }) async {
    // Búsqueda geográfica siempre requiere API
    return _apiRepo.getListingsNearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      limit: limit,
    );
  }

  /// Crea un nuevo listing (requiere API)
  Future<Listing> createListing(Listing listing) async {
    final created = await _apiRepo.createListing(listing);
    await _localDb.saveListings([created]);
    return created;
  }

  /// Actualiza un listing (requiere API)
  Future<Listing> updateListing(String id, Listing listing) async {
    final updated = await _apiRepo.updateListing(id, listing);
    await _localDb.saveListings([updated]);
    return updated;
  }

  /// Elimina un listing (requiere API)
  Future<void> deleteListing(String id) async {
    await _apiRepo.deleteListing(id);
    // No hay método delete en LocalDB, pero se limpiará en el próximo sync
  }

  // Pasar directamente al API los métodos que no necesitan cache
  Future<UserStatsData> getUserStats() => _apiRepo.getUserStats();
  
  Future<PriceSuggestion?> suggestPrice({
    required String categoryId,
    String? brandId,
    String? condition,
    int? msrpCents,
    int? monthsSinceRelease,
    int? roundingQuantum,
  }) => _apiRepo.suggestPrice(
    categoryId: categoryId,
    brandId: brandId,
    condition: condition,
    msrpCents: msrpCents,
    monthsSinceRelease: monthsSinceRelease,
    roundingQuantum: roundingQuantum,
  );

  Future<PresignResponse> getPresignedUploadUrl({
    required String listingId,
    required String filename,
    required String contentType,
  }) => _apiRepo.getPresignedUploadUrl(
    listingId: listingId,
    filename: filename,
    contentType: contentType,
  );

  Future<void> uploadImageToPresignedUrl({
    required String uploadUrl,
    required List<int> imageBytes,
    required String contentType,
  }) => _apiRepo.uploadImageToPresignedUrl(
    uploadUrl: uploadUrl,
    imageBytes: imageBytes,
    contentType: contentType,
  );

  Future<String> confirmImageUpload({
    required String listingId,
    required String objectKey,
  }) => _apiRepo.confirmImageUpload(
    listingId: listingId,
    objectKey: objectKey,
  );

  Future<String> getImagePreviewUrl(String objectKey) =>
      _apiRepo.getImagePreviewUrl(objectKey);

  Future<String> uploadListingImage({
    required String listingId,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  }) => _apiRepo.uploadListingImage(
    listingId: listingId,
    imageBytes: imageBytes,
    filename: filename,
    contentType: contentType,
  );

  /// Acceso directo a la BD local (útil para debug)
  LocalDatabaseService get localDatabase => _localDb;

  /// Acceso directo al repo del API (útil para operaciones que no necesitan cache)
  ListingsRepository get apiRepository => _apiRepo;
}
