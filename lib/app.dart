import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository.dart';
import 'data/services/api_client.dart';
import 'data/services/auth_service.dart';
import 'data/services/token_storage.dart';
import 'l10n/generated/app_localizations.dart';
import 'routing/router.dart';
import 'ui/core/theme/app_theme.dart';

class BerdikariApp extends StatefulWidget {
  const BerdikariApp({super.key, this.authRepository});

  /// Test seam: inject a pre-configured repository (e.g. with an in-memory
  /// token storage and fake service). Production leaves it null.
  final AuthRepository? authRepository;

  @override
  State<BerdikariApp> createState() => _BerdikariAppState();
}

class _BerdikariAppState extends State<BerdikariApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    if (widget.authRepository != null) {
      _authRepository = widget.authRepository!;
      _tokenStorage = TokenStorage();
      _apiClient = ApiClient(tokenProvider: _tokenStorage.read);
    } else {
      _tokenStorage = TokenStorage();
      _apiClient = ApiClient(tokenProvider: _tokenStorage.read);
      _authRepository = AuthRepository(
        service: AuthService(apiClient: _apiClient),
        tokenStorage: _tokenStorage,
      );
      // Expired/revoked token mid-use -> drop the session; the router
      // redirect then lands on /login.
      _apiClient.onUnauthorized = _authRepository.clearSession;
    }
    _router = createRouter(_authRepository);
    _authRepository.restoreSession();
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
        ChangeNotifierProvider<AuthRepository>.value(value: _authRepository),
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
        routerConfig: _router,
      ),
    );
  }
}
