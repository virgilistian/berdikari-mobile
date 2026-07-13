import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/cart_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/daily_stock_repository.dart';
import 'data/repositories/finance_repository.dart';
import 'data/repositories/orders_repository.dart';
import 'data/repositories/shift_repository.dart';
import 'data/repositories/stock_repository.dart';
import 'data/services/api_client.dart';
import 'data/services/auth_service.dart';
import 'data/services/catalog_service.dart';
import 'data/services/finance_service.dart';
import 'data/services/inventory_service.dart';
import 'data/services/sales_service.dart';
import 'data/services/token_storage.dart';
import 'l10n/generated/app_localizations.dart';
import 'routing/router.dart';
import 'ui/core/theme/app_theme.dart';

class BerdikariApp extends StatefulWidget {
  const BerdikariApp({
    super.key,
    this.authRepository,
    this.catalogService,
    this.salesService,
    this.inventoryService,
    this.financeService,
  });

  /// Test seams: inject pre-configured fakes. Production leaves them null.
  final AuthRepository? authRepository;
  final CatalogService? catalogService;
  final SalesService? salesService;
  final InventoryService? inventoryService;
  final FinanceService? financeService;

  @override
  State<BerdikariApp> createState() => _BerdikariAppState();
}

class _BerdikariAppState extends State<BerdikariApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final CatalogRepository _catalogRepository;
  late final CartRepository _cartRepository;
  late final ShiftRepository _shiftRepository;
  late final OrdersRepository _ordersRepository;
  late final DailyStockRepository _dailyStockRepository;
  late final StockRepository _stockRepository;
  late final FinanceRepository _financeRepository;
  late final SalesService _salesService;
  late final InventoryService _inventoryService;
  late final FinanceService _financeService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _tokenStorage = TokenStorage();
    _apiClient = ApiClient(tokenProvider: _tokenStorage.read);

    if (widget.authRepository != null) {
      _authRepository = widget.authRepository!;
    } else {
      _authRepository = AuthRepository(
        service: AuthService(apiClient: _apiClient),
        tokenStorage: _tokenStorage,
      );
      // Expired/revoked token mid-use -> drop the session; the router
      // redirect then lands on /login.
      _apiClient.onUnauthorized = _authRepository.clearSession;
    }

    final catalogService =
        widget.catalogService ?? CatalogService(apiClient: _apiClient);
    _salesService = widget.salesService ?? SalesService(apiClient: _apiClient);
    _inventoryService =
        widget.inventoryService ?? InventoryService(apiClient: _apiClient);
    _financeService =
        widget.financeService ?? FinanceService(apiClient: _apiClient);

    _catalogRepository = CatalogRepository(catalogService: catalogService);
    _cartRepository = CartRepository(
      salesService: _salesService,
      authRepository: _authRepository,
    );
    _shiftRepository = ShiftRepository(salesService: _salesService);
    _ordersRepository = OrdersRepository(
      salesService: _salesService,
      authRepository: _authRepository,
    );
    _dailyStockRepository = DailyStockRepository(
      inventoryService: _inventoryService,
      authRepository: _authRepository,
    );
    _stockRepository = StockRepository(
      inventoryService: _inventoryService,
      authRepository: _authRepository,
    );
    _financeRepository = FinanceRepository(
      financeService: _financeService,
      authRepository: _authRepository,
    );

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
        Provider<CatalogRepository>.value(value: _catalogRepository),
        ChangeNotifierProvider<CartRepository>.value(value: _cartRepository),
        ChangeNotifierProvider<ShiftRepository>.value(value: _shiftRepository),
        Provider<OrdersRepository>.value(value: _ordersRepository),
        ChangeNotifierProvider<DailyStockRepository>.value(
            value: _dailyStockRepository),
        ChangeNotifierProvider<StockRepository>.value(value: _stockRepository),
        ChangeNotifierProvider<FinanceRepository>.value(
            value: _financeRepository),
        Provider<SalesService>.value(value: _salesService),
        Provider<InventoryService>.value(value: _inventoryService),
        Provider<FinanceService>.value(value: _financeService),
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
