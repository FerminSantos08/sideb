import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/network/api_client.dart';
import 'package:side_b/core/network/api_exception.dart';
import 'package:side_b/core/storage/token_storage.dart';
import 'package:side_b/features/checkout/data/checkout_repository.dart';
import 'package:side_b/features/checkout/presentation/checkout_providers.dart';
import 'package:side_b/features/checkout/presentation/checkout_screen.dart';
import 'package:side_b/features/checkout/presentation/order_screens.dart';

Map<String, dynamic> _data({bool paid = false}) => {
  'id': 81,
  'status': paid ? 'pagado' : 'pendiente',
  'paid': paid,
  'date': '2026-11-16T10:00:00',
  'address': 'Calle de prueba 10, México, 12345',
  'currency': 'MXN',
  'subtotal': '399.00',
  'shipping': '99.00',
  'discount': 0,
  'tax': 0,
  'total': '498.00',
  'items': [
    {'name': 'AM', 'quantity': 1, 'price': '399.00', 'image': null},
  ],
};

class _Api extends ApiClient {
  _Api() : super(TokenStorage());
  final calls = <String>[];
  Map<String, dynamic>? body;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(path);
    if (path == '/checkout/addresses') return {'addresses': []};
    if (path == '/orders')
      return {
        'orders': [_data()],
      };
    return _data();
  }

  @override
  Future<dynamic> post(String path, {Object? data}) async {
    calls.add(path);
    body = data as Map<String, dynamic>?;
    return path.endsWith('payment-session')
        ? {'url': 'https://www.sandbox.paypal.com/checkoutnow?token=example'}
        : _data();
  }
}

class _Repository extends CheckoutRepository {
  _Repository() : super(_Api());
  bool fail = false, paid = false;
  int creates = 0, reads = 0;
  final requests = <String>[];
  Completer<void>? pending;
  @override
  Future<PurchaseQuote> quote({int? addressId, String? address}) async =>
      PurchaseQuote.fromJson(_data());
  @override
  Future<PurchaseOrder> create({
    required String requestId,
    required int expectedTotal,
    int? addressId,
    String? address,
  }) async {
    creates++;
    requests.add(requestId);
    if (pending != null) await pending!.future;
    if (fail) throw const ApiException('Conexión interrumpida');
    return PurchaseOrder.fromJson(_data());
  }

  @override
  Future<PurchaseOrder> order(int id) async {
    reads++;
    return PurchaseOrder.fromJson(_data(paid: paid));
  }

  @override
  Future<List<PurchaseOrder>> orders() async => [
    PurchaseOrder.fromJson(_data(paid: paid)),
  ];
  int confirmations = 0;
  @override
  Future<PurchaseOrder> confirmPayment(int id) async {
    confirmations++;
    return PurchaseOrder.fromJson(_data(paid: paid));
  }

  @override
  Future<String> paymentUrl(int id) async =>
      'https://www.sandbox.paypal.com/checkoutnow?token=example';
}

class _HistoryRepository extends _Repository {
  @override
  Future<List<PurchaseOrder>> orders() async => [
    for (final id in [81, 84, 82, 86, 83, 85])
      PurchaseOrder.fromJson({
        ..._data(),
        'id': id,
        'date': '2026-11-${id - 70}T10:00:00',
      }),
  ];
}

Future<void> _render(
  WidgetTester tester,
  _Repository repository, {
  Widget? child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        checkoutRepositoryProvider.overrideWithValue(repository),
        deliveryAddressesProvider.overrideWith((ref) async => []),
        orderProvider.overrideWith((ref, id) => repository.order(id)),
        ordersProvider.overrideWith((ref) => repository.orders()),
      ],
      child: MaterialApp(home: child ?? const CheckoutScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows five recent orders before opening the full history', (
    tester,
  ) async {
    await _render(tester, _HistoryRepository(), child: const OrdersScreen());
    expect(find.text('SB-000086'), findsOneWidget);
    await _visible(tester, 'Ver todos los pedidos');
    expect(find.text('SB-000082'), findsOneWidget);
    expect(find.text('SB-000081'), findsNothing);

    await tester.tap(find.text('Ver todos los pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Historial de pedidos.'), findsOneWidget);
    await _visible(tester, 'SB-000081');
    expect(find.text('SB-000081'), findsOneWidget);
  });

  test('repository sends destination, stable id and expected total, never client line prices', () async {
    final api = _Api();
    final repository = CheckoutRepository(api);
    final id = checkoutRequestId();
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    await repository.create(
      requestId: id,
      expectedTotal: 49800,
      address: '  Mi calle  ',
    );
    expect(api.body, {
      'address': 'Mi calle',
      'request_id': id,
      'expected_total': '498.00',
    });
    expect(money(39950), '\$399.50 MXN');
    expect(PurchaseOrder.fromJson(_data()).paid, isFalse);
  });
  testWidgets(
    'validates delivery and displays server quote before creating the order',
    (tester) async {
      final repository = _Repository();
      await _render(tester, repository);
      await tester.tap(find.text('REVISAR COMPRA'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe la dirección de envío.'), findsOneWidget);
      expect(repository.creates, 0);
      await tester.enterText(find.byType(TextFormField), 'Mi dirección');
      await _visible(tester, 'REVISAR COMPRA');
      await tester.pumpAndSettle();
      await tester.tap(find.text('REVISAR COMPRA'));
      await tester.pumpAndSettle();
      expect(find.text('\$498.00 MXN'), findsOneWidget);
      expect(find.text('Calle de prueba 10, México, 12345'), findsOneWidget);
      expect(repository.creates, 0);
    },
  );
  testWidgets(
    'retry retains the same idempotency key and prevents double submission',
    (tester) async {
      final repository = _Repository()..fail = true;
      await _render(tester, repository);
      await tester.enterText(find.byType(TextFormField), 'Mi dirección');
      await _visible(tester, 'REVISAR COMPRA');
      await tester.pumpAndSettle();
      await tester.tap(find.text('REVISAR COMPRA'));
      await tester.pumpAndSettle();
      await _visible(tester, 'CREAR PEDIDO Y CONTINUAR');
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREAR PEDIDO Y CONTINUAR'));
      await tester.pumpAndSettle();
      expect(find.text('Conexión interrumpida'), findsOneWidget);
      repository.pending = Completer<void>();
      await _visible(tester, 'CREAR PEDIDO Y CONTINUAR');
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREAR PEDIDO Y CONTINUAR'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repository.requests.toSet().length, 1);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(repository.creates, 2);
    },
  );
  testWidgets(
    'opening PayPal and returning never implies payment confirmation',
    (tester) async {
      final repository = _Repository();
      const channel = MethodChannel('side_b/payment');
      MethodCall? opened;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        opened = call;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await _render(tester, repository, child: const OrderScreen(orderId: 81));
      await _visible(tester, 'PAGAR CON PAYPAL');
      await tester.pumpAndSettle();
      await tester.tap(find.text('PAGAR CON PAYPAL'));
      await tester.pumpAndSettle();
      expect(opened?.method, 'open');
      expect(
        (opened!.arguments as Map)['url'],
        startsWith('https://www.sandbox.paypal.com/'),
      );
      expect(repository.confirmations, greaterThanOrEqualTo(1));
      expect(find.text('Tu compra está confirmada.'), findsNothing);
      await _visible(tester, 'ACTUALIZAR ESTADO');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACTUALIZAR ESTADO'));
      await tester.pumpAndSettle();
      expect(find.text('Tu compra está confirmada.'), findsNothing);
      repository.paid = true;
      await _visible(tester, 'ACTUALIZAR ESTADO');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACTUALIZAR ESTADO'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tu compra está confirmada.'),
        -160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tu compra está confirmada.'), findsOneWidget);
      expect(find.text('PAGAR CON PAYPAL'), findsNothing);
    },
  );
}
