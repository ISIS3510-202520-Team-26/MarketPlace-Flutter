import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/auth/login_page.dart';
import '../../presentation/auth/register_page.dart';   // <-- agrega esto
import '../../presentation/home/home_page.dart';
import '../../presentation/listings/create_listing_page.dart';
import '../../presentation/listings/listing_detail_page.dart';
import '../../data/models/listing.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
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
    ],
  );
}