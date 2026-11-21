import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/network/api_client.dart';
import 'package:side_b/core/network/api_exception.dart';
import 'package:side_b/core/storage/token_storage.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/wishlist/wishlist.dart';
import 'package:side_b/features/content/presentation/content_providers.dart';

const user = AuthUser(
  id: 1,
  name: 'Ana',
  email: 'ana@example.com',
  role: 'Listener',
);

class Session extends AuthController {
  Session(this.user);
  final AuthUser? user;
  @override
  Future<AuthUser?> build() async => user;
}

class Api extends ApiClient {
  Api() : super(TokenStorage());
  final ids = <int>{7};
  bool fail = false;
  int reads = 0, carts = 0;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    reads++;
    return {
      'saved_ids': ids.toList(),
      'items': ids
          .map(
            (id) => {
              'id': id,
              'nombre': 'Disco $id',
              'precio': 100,
              'stock': id == 8 ? 0 : 2,
            },
          )
          .toList(),
    };
  }

  @override
  Future<dynamic> delete(String path) async {
    if (fail) throw const ApiException('Sin conexión');
    ids.remove(int.parse(path.split('/').last));
  }

  @override
  Future<dynamic> post(String path, {Object? data}) async {
    if (path == '/cart/items') {
      carts++;
      return null;
    }
    ids.add((data as Map)['product_id'] as int);
  }
}

Future<void> render(
  WidgetTester t,
  Api api,
  Widget child, {
  AuthUser? session = user,
}) async {
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => Session(session)),
        apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('heart reads persisted state and toggles through the API', (
    t,
  ) async {
    final api = Api();
    await render(t, api, const WishlistButton(productId: 7));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(api.ids, isEmpty);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(api.ids, {7});
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
  testWidgets('failed removal preserves the saved heart', (t) async {
    final api = Api()..fail = true;
    await render(t, api, const WishlistButton(productId: 7));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(api.ids, {7});
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
  testWidgets(
    'wishlist supports cart and removal while disabling unavailable stock',
    (t) async {
      final api = Api()..ids.add(8);
      await render(t, api, const WishlistScreen());
      expect(find.text('Disco 7'), findsOneWidget);
      final unavailable = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'AGOTADO'),
      );
      expect(unavailable.onPressed, isNull);
      await t.tap(find.text('AGREGAR AL CARRITO'));
      await t.pumpAndSettle();
      expect(api.carts, 1);
      expect(api.ids, {7, 8});
      await t.tap(find.byTooltip('Quitar Disco 7'));
      await t.pumpAndSettle();
      expect(api.ids, {8});
      expect(find.text('Disco 7'), findsNothing);
    },
  );
  testWidgets('guest wishlist does not request private data', (t) async {
    final api = Api();
    await render(t, api, const WishlistScreen(), session: null);
    expect(api.reads, 0);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });
}
