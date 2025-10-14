import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/auth/login_page.dart';
import '../../presentation/auth/register_page.dart';   // <-- agrega esto
import '../../presentation/home/home_page.dart';
import '../../presentation/listings/create_listing_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterPage()), // <-- nueva ruta
      GoRoute(path: '/', builder: (c, s) => const HomePage()),
      GoRoute(path: '/listings/create', builder: (c, s) => const CreateListingPage()),
    ],
  );
}
