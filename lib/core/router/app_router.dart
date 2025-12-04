import 'package:go_router/go_router.dart';

import '../../presentation/auth/login_page.dart';
import '../../presentation/auth/register_page.dart';
import '../../presentation/preloading/preloading_page.dart';
import '../../presentation/home/home_page.dart';
import '../../presentation/listings/create_listing_page.dart';
import '../../presentation/listings/listing_detail_page.dart';
import '../../presentation/profile/profile_page.dart';
import '../../presentation/profile/profile_stats_page.dart';
import '../../presentation/cart/cart_page.dart';
import '../../presentation/orders/orders_page.dart'; // SP4: Orders Page
import '../../presentation/reviews/reviews_page.dart'; // SP4: Reviews Page
import '../../presentation/favorites/favorites_page.dart'; // ✨ SP4 FAV: Favorites Page (3/4)
import '../../presentation/notifications/notifications_page.dart'; // ✨ SP4 NOTIF: Notifications Page (4/4)
import '../../data/models/listing.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
      GoRoute(path: '/preloading', builder: (c, s) => const PreloadingPage()),
      GoRoute(path: '/', builder: (c, s) => const HomePage()),
      GoRoute(path: '/listings/create', builder: (c, s) => const CreateListingPage()),
      // 🆕 Detalle
      GoRoute(
        path: '/listings/:id',
        builder: (c, s) {
          final id = s.pathParameters['id']!;
          final extra = s.extra;
          if (extra is Listing) return ListingDetailPage(listing: extra);
          return ListingDetailPage(listingId: id);
        },
      ),
      // 👤 Perfil de usuario
      GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
      // 📊 Estadísticas del perfil (con FutureBuilder)
      GoRoute(path: '/profile/stats', builder: (c, s) => const ProfileStatsPage()),
      // 🛒 Carrito de compras
      GoRoute(path: '/cart', builder: (c, s) => const CartPage()),
      // 📦 SP4: Orders Page - Mis órdenes con SQLite cache y offline mode
      GoRoute(path: '/orders', builder: (c, s) => const OrdersPage()),
      // ⭐ SP4: Reviews Page - Mis reviews con Future handlers y async/await
      GoRoute(path: '/reviews', builder: (c, s) => const ReviewsPage()),
      // ❤️ ✨ SP4 FAV: Favorites Page - Vista 3/4 con Hive (Preferences) y CachedNetworkImage (Glide/Kingfisher)
      GoRoute(path: '/favorites', builder: (c, s) => const FavoritesPage()),
      // 🔔 ✨ SP4 NOTIF: Notifications Page - Vista 4/4 con Local Files y LRU Cache (NSCache equivalent)
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsPage()),
    ],
  );
}