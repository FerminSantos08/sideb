import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:side_b/app/app.dart';
import 'package:side_b/core/theme/side_b_theme.dart';
import 'package:side_b/core/widgets/editorial_components.dart';
import 'package:side_b/features/content/data/content_models.dart';
import 'package:side_b/features/content/data/reactions_repository.dart';
import 'package:side_b/features/content/presentation/reaction_providers.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/content/presentation/content_providers.dart';
import 'package:side_b/features/shell/presentation/side_b_bottom_navigation.dart';

class _Guest extends AuthController {
  @override
  Future<AuthUser?> build() async => null;
}

class _Member extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 1,
    name: 'Fermín',
    email: 'fermin@example.com',
    role: 'Listener',
  );
}

void main() {
  testWidgets('profile icon toggles the app theme and saves the preference', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postsProvider.overrideWith((ref) => []),
          artistsProvider.overrideWith((ref) => []),
          productsProvider.overrideWith((ref) => []),
          authProvider.overrideWith(_Member.new),
        ],
        child: const SideBApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('side-b-nav-Perfil')));
    await tester.pumpAndSettle();

    final darkToggle = find.byTooltip('Activar tema oscuro');
    expect(
      tester.getCenter(darkToggle).dx,
      greaterThan(tester.getCenter(find.text('Fermín')).dx),
    );
    await tester.tap(darkToggle);
    await tester.pumpAndSettle();
    final lightToggle = find.byTooltip('Activar tema claro');
    expect(lightToggle, findsOneWidget);
    expect(Theme.of(tester.element(lightToggle)).brightness, Brightness.dark);
    expect(
      await const FlutterSecureStorage().read(key: 'side_b_dark_theme'),
      'true',
    );

    await tester.tap(find.byKey(const ValueKey('side-b-nav-Inicio')));
    await tester.pumpAndSettle();
    final home = tester.element(
      find.text('Aún no hay publicaciones disponibles.'),
    );
    expect(
      Theme.of(home).scaffoldBackgroundColor,
      SideBTheme.dark.scaffoldBackgroundColor,
    );

    await tester.tap(find.byKey(const ValueKey('side-b-nav-Perfil')));
    await tester.pumpAndSettle();
    await tester.tap(lightToggle);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(darkToggle)).brightness, Brightness.light);
    expect(
      await const FlutterSecureStorage().read(key: 'side_b_dark_theme'),
      'false',
    );
  });

  testWidgets('renders SIDE B navigation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          postsProvider.overrideWith((ref) => []),
          artistsProvider.overrideWith((ref) => []),
          productsProvider.overrideWith((ref) => []),
          authProvider.overrideWith(_Guest.new),
        ],
        child: const SideBApp(),
      ),
    );
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.bySemanticsLabel('Editorial'), findsOneWidget);
    final homeHeading = tester.getTopLeft(
      find.text('SIDE B / MÚSICA Y CULTURA'),
    );

    for (final label in [
      'Editorial',
      'Artistas',
      'Tienda',
      'Perfil',
      'Inicio',
    ]) {
      await tester.tap(find.byKey(ValueKey('side-b-nav-$label')));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      if (label == 'Artistas' || label == 'Tienda') {
        final eyebrow = label == 'Artistas'
            ? 'ARTISTAS'
            : 'OBJETOS Y EDICIONES';
        expect(tester.getTopLeft(find.text(eyebrow)), homeHeading);
        if (label == 'Tienda') {
          final cart = tester.getTopLeft(find.byTooltip('Mi carrito'));
          expect(cart.dx, greaterThan(homeHeading.dx));
          expect(
            cart.dy,
            lessThan(tester.getTopLeft(find.text('Catálogo')).dy),
          );
        }
      }
    }
    await tester.tap(find.byKey(const ValueKey('side-b-nav-Tienda')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.byType(SideBBottomNavigation), findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(SideBBottomNavigation), findsOneWidget);
  });

  testWidgets('last home card scrolls clear of floating navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          postsProvider.overrideWith(
            (ref) => const [
              Post(id: 1, title: 'Portada', description: '', slug: 'portada'),
              Post(
                id: 2,
                title: 'Última historia',
                description: '',
                slug: 'ultima',
              ),
            ],
          ),
          reactionCatalogProvider.overrideWith(
            (ref) async => ReactionCatalog(enabled: false, types: []),
          ),
          artistsProvider.overrideWith((ref) => []),
          productsProvider.overrideWith((ref) => []),
          authProvider.overrideWith(_Guest.new),
        ],
        child: const SideBApp(),
      ),
    );
    await tester.pumpAndSettle();
    final lastCard = find.widgetWithText(FeaturedPostCard, 'Última historia');
    final pill = find.byKey(const ValueKey('side-b-bottom-navigation-pill'));
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    expect(lastCard, findsOneWidget);
    expect(
      tester.getBottomRight(lastCard).dy,
      lessThan(tester.getTopLeft(pill).dy),
    );

    // Open a normal inner route from the home navigator, then use system Back.
    final navigator = Navigator.of(tester.element(lastCard));
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(appBar: AppBar(title: const Text('Ficha de prueba'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ficha de prueba'), findsOneWidget);
    final detailContext = tester.element(find.text('Ficha de prueba'));
    final detailTheme = Theme.of(detailContext);
    expect(detailTheme.scaffoldBackgroundColor, SideBColors.ivory);
    expect(detailTheme.canvasColor, SideBColors.ivory);
    expect(detailTheme.colorScheme.surface, SideBColors.ivory);
    expect(detailTheme.cardTheme.color, SideBColors.paper);
    expect(pill, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ficha de prueba'), findsNothing);
    expect(lastCard, findsOneWidget);

    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(appBar: AppBar(title: const Text('Ficha de prueba'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('side-b-nav-Tienda')));
    await tester.pumpAndSettle();
    expect(find.text('Ficha de prueba'), findsNothing);
    expect(find.text('Tienda'), findsOneWidget);
  });

  testWidgets('home mixes the three sections and Editorial reuses its cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postsProvider.overrideWith(
            (ref) => const [
              Post(
                id: 10,
                title: 'Artículo de portada',
                description: 'Resumen',
                slug: 'portada',
              ),
            ],
          ),
          reactionCatalogProvider.overrideWith(
            (ref) async => ReactionCatalog(enabled: false, types: []),
          ),
          artistsProvider.overrideWith(
            (ref) => const [Artist(id: 11, name: 'Artista de prueba')],
          ),
          productsProvider.overrideWith(
            (ref) => const [
              Product(id: 12, name: 'Disco de prueba', price: 399),
            ],
          ),
          authProvider.overrideWith(_Guest.new),
        ],
        child: const SideBApp(),
      ),
    );
    await tester.pumpAndSettle();
    final article = find.widgetWithText(
      FeaturedPostCard,
      'Artículo de portada',
    );
    expect(article, findsOneWidget);
    await tester.scrollUntilVisible(find.text('Artista de prueba'), 220);
    await tester.scrollUntilVisible(find.text('Disco de prueba'), 220);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('side-b-nav-Editorial')));
    await tester.pumpAndSettle();
    expect(article, findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);
  });

  testWidgets('slides the olive indicator into Inicio and Editorial', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postsProvider.overrideWith((ref) {
            loads++;
            return [];
          }),
          artistsProvider.overrideWith((ref) => []),
          productsProvider.overrideWith((ref) => []),
          authProvider.overrideWith(_Guest.new),
        ],
        child: const SideBApp(),
      ),
    );
    await tester.pumpAndSettle();
    final indicator = find.byKey(const ValueKey('side-b-nav-indicator'));
    for (final label in ['Tienda', 'Inicio', 'Editorial']) {
      final start = tester.getTopLeft(indicator).dx;
      final previousLoads = loads;
      await tester.tap(find.byKey(ValueKey('side-b-nav-$label')));
      await tester.pump();
      expect(tester.getTopLeft(indicator).dx, closeTo(start, .1));
      await tester.pump(SideBBottomNavigation.animationDuration ~/ 2);
      final midpoint = tester.getTopLeft(indicator).dx;
      expect(midpoint, isNot(closeTo(start, .1)));
      expect(loads, previousLoads);
      await tester.pumpAndSettle();
      final end = tester.getTopLeft(indicator).dx;
      expect(
        midpoint,
        inExclusiveRange(start < end ? start : end, start < end ? end : start),
      );
      expect(loads, label == 'Tienda' ? previousLoads : previousLoads + 1);
    }
  });

  testWidgets('keeps the floating navigation within its maximum width', (
    tester,
  ) async {
    const surfaces = [
      Size(320, 800),
      Size(360, 800),
      Size(412, 800),
      Size(600, 900),
      Size(900, 800),
      Size(900, 600),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final surface in surfaces) {
      tester.view.physicalSize = surface;
      await tester.binding.setSurfaceSize(surface);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SideBBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: _ignoreSelection,
            ),
          ),
        ),
      );

      final size = tester.getSize(
        find.byKey(const ValueKey('side-b-bottom-navigation-pill')),
      );
      expect(size.width, lessThanOrEqualTo(380));
      expect(size.width, lessThanOrEqualTo(surface.width - 32));
      expect(size.height, 64);
      expect(
        tester.getSize(find.byKey(const ValueKey('side-b-nav-Inicio'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getCenter(find.byKey(const ValueKey('side-b-selected-Inicio')))
            .dy,
        closeTo(
          tester
              .getCenter(
                find.byKey(const ValueKey('side-b-bottom-navigation-pill')),
              )
              .dy,
          .1,
        ),
      );
      expect(
        tester
            .getBottomRight(
              find.byKey(const ValueKey('side-b-bottom-navigation-pill')),
            )
            .dy,
        closeTo(surface.height - 16, .1),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}

void _ignoreSelection(int _) {}
