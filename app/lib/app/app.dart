import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/router/app_router.dart';
import '../features/settings/providers/locale_provider.dart';
import '../l10n/generated/app_localizations.dart';
import 'theme.dart';

class JiaApp extends ConsumerWidget {
  const JiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Jia',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Localization
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
        Locale('ms'),
        Locale('tl'),
        Locale('id'),
        Locale('my'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Routing
      routerConfig: router,
    );
  }
}
