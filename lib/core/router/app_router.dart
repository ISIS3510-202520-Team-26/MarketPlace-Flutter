import 'package:go_router/go_router.dart';

import '../../presentation/auth/login_page.dart';
import '../../presentation/auth/register_page.dart';
import '../../presentation/preloading/preloading_page.dart';
import '../../presentation/home/home_page.dart';
import '../../presentation/listings/create_listing_page.dart';
import '../../presentation/listings/listing_detail_page.dart';
import '../../presentation/listings/my_listings_page.dart';
import '../../presentation/profile/profile_page.dart';
import '../../presentation/profile/profile_stats_page.dart';
import '../../presentation/cart/cart_page.dart';
import '../../presentation/settings/settings_page.dart';
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
      GoRoute(path: '/listings/my', builder: (c, s) => const MyListingsPage()),
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
      // ⚙️ Configuración
      GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
    ],
  );
}