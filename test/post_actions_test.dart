import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/content/data/content_models.dart';
import 'package:side_b/features/content/data/reactions_repository.dart';
import 'package:side_b/features/content/presentation/content_providers.dart';
import 'package:side_b/features/content/presentation/post_actions_bar.dart';
import 'package:side_b/features/content/presentation/post_detail_screen.dart';
import 'package:side_b/features/content/presentation/reaction_providers.dart';

class _Guest extends AuthController {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  const post = Post(id: 5, title: 'The Car', description: '', slug: 'the-car');

  testWidgets('comment and share stay available while reactions are disabled', (
    tester,
  ) async {
    MethodCall? shared;
    const channel = MethodChannel('side_b/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      shared = call;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    var comments = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reactionCatalogProvider.overrideWith(
            (ref) async => ReactionCatalog(enabled: false, types: []),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: PostActionsBar(post: post, onComment: () => comments++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reaccionar'), findsOneWidget);
    await tester.tap(find.text('Comentar'));
    expect(comments, 1);
    await tester.tap(find.text('Compartir'));
    await tester.pumpAndSettle();
    expect(shared?.method, 'share');
    expect(shared?.arguments['title'], 'The Car');
    final uri = Uri.parse(shared!.arguments['url'] as String);
    expect(uri.path, endsWith('/publicacion.php'));
    expect(uri.queryParameters['slug'], 'the-car');
    expect(tester.takeException(), isNull);
  });

  testWidgets('comment action opens an article directly at its conversation', (
    tester,
  ) async {
    final article = Post(
      id: 5,
      title: 'The Car',
      description: '',
      slug: 'the-car',
      content: List.filled(
        24,
        '<p>Una historia para escuchar y conversar.</p>',
      ).join(),
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          postProvider.overrideWith((ref, id) async => article),
          commentsProvider.overrideWith((ref, id) async => []),
          authProvider.overrideWith(_Guest.new),
          reactionCatalogProvider.overrideWith(
            (ref) async => ReactionCatalog(enabled: false, types: []),
          ),
        ],
        child: const MaterialApp(
          home: PostDetailScreen(postId: 5, scrollToComments: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heading = tester.getRect(find.text('Comentarios'));
    expect(heading.top, greaterThanOrEqualTo(0));
    expect(heading.bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
  });
}
