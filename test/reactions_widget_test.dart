import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/network/api_exception.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/content/data/reactions_repository.dart';
import 'package:side_b/features/content/presentation/post_reactions_bar.dart';
import 'package:side_b/features/content/presentation/reaction_providers.dart';
import 'package:side_b/features/content/presentation/reaction_gesture_picker.dart';
import 'package:side_b/features/profile/presentation/profile_screen.dart';

final _catalog = ReactionCatalog(
  enabled: true,
  types: const [
    ReactionType(
      id: 'me_encanta',
      label: 'Me encanta',
      symbol: 'heart',
      color: '#C16A60',
    ),
    ReactionType(
      id: 'temazo',
      label: 'Temazo',
      symbol: 'music-2',
      color: '#858C77',
    ),
    ReactionType(
      id: 'lo_escucharia',
      label: 'Lo escuché',
      symbol: 'headphones',
      color: '#B89B72',
    ),
    ReactionType(
      id: 'sorprendente',
      label: 'Sorprendente',
      symbol: 'sparkles',
      color: '#A18BB6',
    ),
  ],
);

class _Repository implements ReactionsRepository {
  String? selection;
  bool fail = false;
  int writes = 0;
  @override
  Future<ReactionCatalog> catalog() async => _catalog;
  @override
  Future<String?> selected(int postId) async => selection;
  @override
  Future<ReactionSummary> summary(int postId) async => ReactionSummary(
    enabled: true,
    counts: {
      for (final type in _catalog.types) type.id: selection == type.id ? 1 : 0,
    },
  );
  @override
  Future<void> select(
    int postId,
    String reactionId,
    ReactionCatalog catalog,
  ) async {
    if (fail) throw const ApiException('Sin conexión');
    writes++;
    selection = reactionId;
  }

  @override
  Future<void> remove(int postId) async {
    if (fail) throw const ApiException('Sin conexión');
    writes++;
    selection = null;
  }
}

class _Session extends AuthController {
  _Session(this.user);
  final AuthUser? user;
  @override
  Future<AuthUser?> build() async => user;
}

const _user = AuthUser(
  id: 1,
  name: 'Ana',
  email: 'ana@example.com',
  role: 'Listener',
);

Future<void> _render(
  WidgetTester tester,
  _Repository repository, {
  bool guest = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        reactionsRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(() => _Session(guest ? null : _user)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.only(top: 240, left: 24),
            child: Align(
              alignment: Alignment.topLeft,
              child: PostReactionsBar(postId: 5),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.byType(TextButton).first);
  await tester.pumpAndSettle();
  final type = _catalog.types.firstWhere((type) => type.label == label);
  final item = find.byKey(ValueKey('reaction-option-${type.id}'));
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'scroll wins before the hold threshold and stays fixed during a reaction gesture',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final choices = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                const SizedBox(height: 220),
                ReactionGesturePicker(
                  types: _catalog.types,
                  iconFor: reactionIcon,
                  colorFor: reactionColor,
                  onSelected: choices.add,
                  builder: (context, open) => TextButton(
                    key: const ValueKey('scroll-reaction-trigger'),
                    onPressed: open,
                    child: const Text('Reaccionar'),
                  ),
                ),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      );
      final trigger = find.byKey(const ValueKey('scroll-reaction-trigger'));
      await tester.drag(trigger, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(find.byKey(const ValueKey('reaction-capsule')), findsNothing);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(trigger));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      final target = tester.getCenter(
        find.byKey(const ValueKey('reaction-option-lo_escucharia')),
      );
      await gesture.moveTo(target);
      await tester.pump(const Duration(milliseconds: 180));
      expect(controller.offset, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(choices, ['lo_escucharia']);
      expect(controller.offset, 0);
    },
  );

  testWidgets(
    'capsule stays inside a narrow viewport and dismisses on outside tap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _render(tester, _Repository());
      await tester.tap(find.byKey(const ValueKey('reaction-trigger-5')));
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('reaction-capsule')),
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      await tester.tapAt(const Offset(300, 620));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reaction-capsule')), findsNothing);
    },
  );

  testWidgets(
    'long press slides across measured icons and release commits once',
    (tester) async {
      final repository = _Repository();
      await _render(tester, repository);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('reaction-trigger-5'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      final capsule = find.byKey(const ValueKey('reaction-capsule'));
      expect(capsule, findsOneWidget);
      final bounds = tester.getRect(capsule);
      final first = tester.getCenter(
        find.byKey(const ValueKey('reaction-option-me_encanta')),
      );
      await gesture.moveTo(first);
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        tester
            .widget<AnimatedScale>(
              find.byKey(const ValueKey('reaction-scale-me_encanta')),
            )
            .scale,
        1.28,
      );
      final label = find.byKey(const ValueKey('reaction-label-me_encanta'));
      final labelBounds = tester.getRect(label);
      await gesture.moveTo(first + const Offset(4, 2));
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getRect(label), labelBounds);
      final second = tester.getCenter(
        find.byKey(const ValueKey('reaction-option-temazo')),
      );
      await gesture.moveTo(second);
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getRect(capsule), bounds);
      expect(
        tester
            .widget<AnimatedScale>(
              find.byKey(const ValueKey('reaction-scale-me_encanta')),
            )
            .scale,
        1,
      );
      expect(
        tester
            .widget<AnimatedScale>(
              find.byKey(const ValueKey('reaction-scale-temazo')),
            )
            .scale,
        1.28,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repository.selection, 'temazo');
      expect(repository.writes, 1);
      expect(capsule, findsNothing);
    },
  );

  testWidgets(
    'release outside valid zones cancels without changing the active reaction',
    (tester) async {
      final repository = _Repository()..selection = 'me_encanta';
      await _render(tester, repository);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('reaction-trigger-5'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('reaction-option-temazo'))),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await gesture.moveTo(const Offset(780, 560));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repository.selection, 'me_encanta');
      expect(repository.writes, 0);
      expect(find.byKey(const ValueKey('reaction-capsule')), findsNothing);
    },
  );

  testWidgets(
    'disposes the floating capsule when its publication leaves the tree',
    (tester) async {
      await _render(tester, _Repository());
      await tester.tap(find.byKey(const ValueKey('reaction-trigger-5')));
      await tester.pumpAndSettle();
      expect(find.byType(ReactionGesturePicker), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reaction-capsule')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dropdown displays four Lucide options and counters', (
    tester,
  ) async {
    await _render(tester, _Repository());
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
    for (final type in _catalog.types) {
      expect(
        find.byKey(ValueKey('reaction-option-${type.id}')),
        findsOneWidget,
      );
      expect(find.byIcon(reactionIcon(type.symbol)), findsWidgets);
    }
    expect(find.byKey(const ValueKey('reaction-capsule')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects, replaces and removes the same reaction', (
    tester,
  ) async {
    final repository = _Repository();
    await _render(tester, repository);
    await _choose(tester, 'Me encanta');
    expect(repository.selection, 'me_encanta');
    expect(find.text('Me encanta'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await _choose(tester, 'Temazo');
    expect(repository.selection, 'temazo');
    expect(find.text('Temazo'), findsOneWidget);
    await _choose(tester, 'Temazo');
    expect(repository.selection, isNull);
    expect(repository.writes, 3);
    expect(find.text('Reaccionar'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('restores a persisted reaction when opening the article', (
    tester,
  ) async {
    await _render(tester, _Repository()..selection = 'lo_escucharia');
    expect(find.text('Lo escuché'), findsOneWidget);
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reaction-label-lo_escucharia')),
      findsOneWidget,
    );
  });

  testWidgets('a failed update preserves the confirmed selection', (
    tester,
  ) async {
    final repository = _Repository()..selection = 'me_encanta';
    await _render(tester, repository);
    repository.fail = true;
    await _choose(tester, 'Sorprendente');
    expect(repository.selection, 'me_encanta');
    expect(find.text('Me encanta'), findsOneWidget);
    expect(find.textContaining('No pudimos actualizar'), findsOneWidget);
  });

  testWidgets('guests can inspect counts but must log in before reacting', (
    tester,
  ) async {
    final repository = _Repository();
    await _render(tester, repository, guest: true);
    await _choose(tester, 'Temazo');
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(repository.writes, 0);
  });
}
