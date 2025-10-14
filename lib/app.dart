import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';


class MarketApp extends StatelessWidget {
const MarketApp({super.key});
@override
Widget build(BuildContext context) {
return MaterialApp.router(
title: 'Tech Market',
debugShowCheckedModeBanner: false,
theme: AppTheme.light,
routerConfig: AppRouter.router,
locale: const Locale('en'),
supportedLocales: const [Locale('en'), Locale('es')],
);
}
}