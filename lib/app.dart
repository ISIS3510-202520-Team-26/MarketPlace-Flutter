import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/settings_provider.dart';


class MarketApp extends StatefulWidget {
  const MarketApp({super.key});
  
  @override
  State<MarketApp> createState() => _MarketAppState();
}

class _MarketAppState extends State<MarketApp> {
  final _settingsProvider = SettingsProvider.instance;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    await _settingsProvider.initialize();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Mostrar splash mientras carga settings
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _settingsProvider,
      builder: (context, _) {
        final settings = _settingsProvider.settings;
        final fontScale = settings.fontSize.scaleFactor;
        final isDark = settings.isDarkMode;
        
        return MaterialApp.router(
          title: 'Tech Market',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(fontScale: fontScale, isDark: isDark),
          routerConfig: AppRouter.router,
          locale: Locale(settings.language),
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}