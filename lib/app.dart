import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/services/api_client.dart';
import 'data/services/token_storage.dart';
import 'l10n/generated/app_localizations.dart';
import 'routing/router.dart';
import 'ui/core/theme/app_theme.dart';

class BerdikariApp extends StatefulWidget {
  const BerdikariApp({super.key});

  @override
  State<BerdikariApp> createState() => _BerdikariAppState();
}

class _BerdikariAppState extends State<BerdikariApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final router = createRouter();

  @override
  void initState() {
    super.initState();
    _tokenStorage = TokenStorage();
    _apiClient = ApiClient(tokenProvider: _tokenStorage.read);
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        Provider<ApiClient>.value(value: _apiClient),
      ],
      child: MaterialApp.router(
        title: 'Berdikari',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('id'),
        supportedLocales: const [Locale('id')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }
}
