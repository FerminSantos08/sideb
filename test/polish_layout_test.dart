import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/theme/side_b_theme.dart';
import 'package:side_b/core/widgets/async_state.dart';
import 'package:side_b/core/widgets/editorial_components.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/content/data/content_models.dart';
import 'package:side_b/features/content/data/reactions_repository.dart';
import 'package:side_b/features/content/presentation/content_providers.dart';
import 'package:side_b/features/content/presentation/artist_screens.dart';
import 'package:side_b/features/content/presentation/reaction_providers.dart';
import 'package:side_b/features/content/presentation/shop_screen.dart';
import 'package:side_b/features/profile/presentation/profile_screen.dart';

class Guest extends AuthController {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  testWidgets('shop fits narrow screens and larger accessibility text', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    for (final width in [320.0, 412.0, 900.0]) {
      t.view.physicalSize = Size(width, 900);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            productsProvider.overrideWith(
              (ref) => [
                const Product(
                  id: 1,
                  name: 'Edición especial de un disco extraordinario',
                  price: 1899,
                  brand: 'FiiO / Snowsky',
                  category: 'Audio',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: SideBTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const Scaffold(body: ShopScreen()),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await t.pumpAndSettle();
      expect(find.textContaining('Edición especial'), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
  testWidgets('artist discography fits a narrow dark layout with large text', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          artistProvider.overrideWith(
            (ref, id) => const Artist(
              id: 1,
              name: 'Un artista con un nombre largo',
              genre: 'Indie rock',
              bio: 'Una biografía de prueba.',
              albums: [
                Album(
                  id: 1,
                  title: 'Un disco con un título largo',
                  releaseDate: '2025-02-10',
                ),
                Album(id: 2, title: 'Segundo disco'),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: SideBTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const ArtistProfileScreen(artistId: 1),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Biografía'), 180);
    await t.scrollUntilVisible(find.text('ÁLBUM · 2025'), 180);
    expect(find.text('Discografía'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('shop filters categories and opens a complete product card', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    const headphones = Product(
      id: 1,
      name: 'Audífonos',
      category: 'Audio',
      price: 499.50,
      stock: 1,
      description: 'Descripción de prueba.',
    );
    const cable = Product(
      id: 3,
      name: 'Cable de audio',
      category: 'Audio',
      price: 149,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(Guest.new),
          productsProvider.overrideWith(
            (ref) => const [
              headphones,
              cable,
              Product(
                id: 2,
                name: 'Disco de prueba',
                category: 'Vinilos',
                price: 300,
              ),
            ],
          ),
          productProvider.overrideWith(
            (ref, id) => id == cable.id ? cable : headphones,
          ),
        ],
        child: MaterialApp(
          theme: SideBTheme.dark,
          home: const Scaffold(body: ShopScreen()),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Audio'));
    await t.pumpAndSettle();
    expect(find.text('Disco de prueba'), findsNothing);
    await t.scrollUntilVisible(find.text('Audífonos'), 160);
    await t.tap(find.text('Audífonos'));
    await t.pumpAndSettle();
    expect(find.text('1 disponible'), findsOneWidget);
    expect(find.text('Agregar al carrito'), findsOneWidget);
    expect(find.byTooltip('Mi carrito'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Cable de audio'), 180);
    expect(find.text('Productos relacionados'), findsOneWidget);
    expect(find.text('Disco de prueba'), findsNothing);
    await t.tap(find.text('Cable de audio'));
    await t.pumpAndSettle();
    expect(find.text('Cable de audio'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('empty and error states fit a short viewport', (t) async {
    for (final child in [
      const EmptyView(message: 'Tu colección está vacía.'),
      AsyncErrorView(
        message: 'No pudimos cargar la página. Revisa tu conexión e inténtalo de nuevo.',
        onRetry: () {},
      ),
    ]) {
      await t.pumpWidget(
        MaterialApp(
          theme: SideBTheme.light,
          home: Scaffold(body: SizedBox(height: 160, child: child)),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
  });
  testWidgets('featured title is separate from its unshaded image', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          reactionCatalogProvider.overrideWith(
            (ref) async => ReactionCatalog(enabled: false, types: []),
          ),
        ],
        child: MaterialApp(
          theme: SideBTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturedPostCard(
                post: const Post(
                  id: 1,
                  title: 'Escuchar el otro lado',
                  description: '',
                  slug: 'otro-lado',
                ),
                height: 200,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t.getTopLeft(find.text('Escuchar el otro lado')).dy,
      greaterThan(t.getBottomLeft(find.byType(NetworkCover)).dy),
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('guest profile scrolls with keyboard-sized space', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(Guest.new)],
        child: MaterialApp(
          theme: SideBTheme.light,
          home: const Scaffold(
            body: SizedBox(height: 270, child: ProfileScreen()),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
