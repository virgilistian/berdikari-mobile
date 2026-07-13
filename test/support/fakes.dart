import 'package:berdikari_mobile/data/models/auth_user.dart';
import 'package:berdikari_mobile/data/models/order.dart';
import 'package:berdikari_mobile/data/models/product.dart';
import 'package:berdikari_mobile/data/models/shift.dart';
import 'package:berdikari_mobile/data/repositories/auth_repository.dart';
import 'package:berdikari_mobile/data/services/api_client.dart';
import 'package:berdikari_mobile/data/services/auth_service.dart';
import 'package:berdikari_mobile/data/services/catalog_service.dart';
import 'package:berdikari_mobile/data/services/sales_service.dart';
import 'package:berdikari_mobile/data/services/token_storage.dart';

/// Token storage backed by a plain field — no platform channel.
class InMemoryTokenStorage extends TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

/// AuthService that answers from fixtures instead of HTTP.
class FakeAuthService extends AuthService {
  FakeAuthService({this.user, this.token = 'fake-token', this.loginError})
      : super(apiClient: ApiClient(tokenProvider: () async => null));

  AuthUser? user;
  String token;
  ApiException? loginError;
  bool logoutCalled = false;

  @override
  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final error = loginError;
    if (error != null) throw error;
    return (token: token, user: user!);
  }

  @override
  Future<AuthUser> me() async {
    final current = user;
    if (current == null) {
      throw ApiException(statusCode: 401, message: 'Unauthenticated.');
    }
    return current;
  }

  @override
  Future<void> logout() async => logoutCalled = true;

  @override
  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) async {
    final current = user!;
    user = AuthUser(
      id: current.id,
      name: name,
      email: email,
      role: current.role,
      businessId: current.businessId,
      roles: current.roles,
      permissions: current.permissions,
    );
    return user!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {}
}

AuthUser sampleUser({
  List<String> permissions = const ['finance.view', 'pos.view', 'pos.open'],
  List<String> roles = const ['cashier'],
  String name = 'Ibu Sari',
}) =>
    AuthUser(
      id: '1',
      name: name,
      email: 'sari@berdikari.id',
      role: 'cashier',
      businessId: '1',
      roles: roles,
      permissions: permissions,
    );

/// Repository wired to fakes. Seed [token] to simulate a persisted session.
AuthRepository fakeAuthRepository({
  AuthUser? user,
  String? token,
  ApiException? loginError,
}) =>
    AuthRepository(
      service: FakeAuthService(user: user, loginError: loginError),
      tokenStorage: InMemoryTokenStorage(token),
    );

Product sampleProduct({
  String id = 'p1',
  String name = 'Es Teh',
  int price = 5000,
  String? categoryId = 'c1',
  bool isActive = true,
}) =>
    Product(
      id: id,
      categoryId: categoryId,
      name: name,
      sku: null,
      price: price,
      isActive: isActive,
      imageUrl: null,
    );

/// CatalogService that answers from in-memory fixtures instead of HTTP.
class FakeCatalogService extends CatalogService {
  FakeCatalogService({List<Product>? products, List<ProductCategory>? categories})
      : products = products ??
            [
              sampleProduct(id: 'p1', name: 'Es Teh', price: 5000),
              sampleProduct(id: 'p2', name: 'Nasi Kucing', price: 3000),
            ],
        categories = categories ?? [const ProductCategory(id: 'c1', name: 'Minuman')],
        super(apiClient: ApiClient(tokenProvider: () async => null));

  List<Product> products;
  List<ProductCategory> categories;

  @override
  Future<List<Product>> fetchProducts() async => products;

  @override
  Future<List<ProductCategory>> fetchCategories() async => categories;
}

/// SalesService that answers from fixtures instead of HTTP.
class FakeSalesService extends SalesService {
  FakeSalesService({
    this.activeShift,
    this.orders = const [],
    this.checkoutError,
  }) : super(apiClient: ApiClient(tokenProvider: () async => null));

  CashierShift? activeShift;
  List<Order> orders;
  ApiException? checkoutError;
  Map<String, dynamic>? lastCheckoutPayload;

  @override
  Future<Order> submitOrder(Map<String, dynamic> payload) async {
    lastCheckoutPayload = payload;
    final error = checkoutError;
    if (error != null) throw error;

    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    final total = items.fold<int>(
        0, (sum, i) => sum + (i['quantity'] as int) * (i['unit_price'] as int));
    final payments =
        (payload['payments'] as List).cast<Map<String, dynamic>>();
    final paid =
        payments.fold<int>(0, (sum, p) => sum + (p['amount'] as int));

    return Order(
      id: payload['client_uuid'] as String,
      orderNo: 'INV-0001',
      status: 'completed',
      paymentStatus: paid >= total ? 'paid' : 'partial',
      totalAmount: total,
      paidAmount: paid,
      changeAmount: (paid - total).clamp(0, paid),
      balanceDue: (total - paid).clamp(0, total),
      customerName: payload['customer_name'] as String?,
      createdAt: DateTime.now(),
      items: const [],
      payments: const [],
    );
  }

  @override
  Future<List<Order>> fetchOrders({String? businessId, String? status}) async {
    if (status == null || status.isEmpty) return orders;
    return orders.where((o) => o.status == status).toList();
  }

  @override
  Future<CashierShift?> fetchActiveShift() async => activeShift;

  @override
  Future<CashierShift> openShift({required int openingCash}) async {
    activeShift = sampleShift(openingCash: openingCash);
    return activeShift!;
  }

  @override
  Future<CashierShift> closeShift(
    String id, {
    required int closingCash,
    String? closingNote,
  }) async {
    final closed = sampleShift(
      id: id,
      status: 'closed',
      openingCash: activeShift?.openingCash ?? 0,
      closingCash: closingCash,
      expectedCash: activeShift?.openingCash ?? 0,
      cashDifference:
          closingCash - (activeShift?.openingCash ?? 0),
      closingNote: closingNote,
    );
    activeShift = null;
    return closed;
  }
}

CashierShift sampleShift({
  String id = 's1',
  String status = 'open',
  int openingCash = 100000,
  int? closingCash,
  int? expectedCash,
  int? cashDifference,
  int transactionCount = 0,
  int totalSales = 0,
  String? closingNote,
}) =>
    CashierShift(
      id: id,
      status: status,
      openingCash: openingCash,
      closingCash: closingCash,
      expectedCash: expectedCash,
      cashDifference: cashDifference,
      transactionCount: transactionCount,
      totalSales: totalSales,
      closingNote: closingNote,
      openedAt: DateTime.now(),
      closedAt: status == 'closed' ? DateTime.now() : null,
      cashierName: 'Ibu Sari',
    );
