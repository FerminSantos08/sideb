import 'package:side_b/core/config/api_config.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/network/api_client.dart';
import 'package:side_b/core/network/api_exception.dart';
import 'package:side_b/core/storage/token_storage.dart';
import 'package:side_b/core/widgets/editorial_components.dart';
import 'package:side_b/features/content/presentation/post_actions_bar.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/content/data/content_models.dart';
import 'package:side_b/features/content/data/content_repository.dart';
import 'package:side_b/features/content/presentation/content_providers.dart';
import 'package:side_b/features/content/presentation/post_comments_section.dart';
import 'package:side_b/features/content/data/reactions_repository.dart';
import 'package:side_b/features/content/presentation/reaction_providers.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(TokenStorage());
  String? path;
  Object? body;
  bool fail = false;
  Completer<void>? pending;
  final rows = <Map<String, dynamic>>[];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    this.path = path;
    return {'comments': rows};
  }

  @override
  Future<dynamic> post(String path, {Object? data}) async {
    this.path = path;
    body = data;
    if (pending != null) await pending!.future;
    if (fail) throw const ApiException('Sin conexión');
    rows.add({
      'id': 1,
      'comentario': (data as Map)['comentario'],
      'autor': 'Ana',
      'fecha': '2026-11-15T12:30:00',
    });
    return {'id': 1, 'comentario': (data)['comentario']};
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
  _FakeApi api, {
  AuthUser? user,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        authProvider.overrideWith(() => _Session(user)),
        contentRepositoryProvider.overrideWithValue(ContentRepository(api)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PostCommentsSection(postId: 5)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows comment counts on all article cards at narrow widths', (
    tester,
  ) async {
    const post = Post(
      id: 5,
      title: 'Una historia para escuchar',
      description: 'Descripción',
      slug: 'historia',
      author: 'Editorial',
      date: '2026-11-02',
      commentsCount: 3,
    );
    for (final card in <Widget>[
      FeaturedPostCard(post: post, onTap: () {}, height: 320),
      CompactPostCard(post: post, onTap: () {}),
      EditorialPostCard(post: post, onTap: () {}),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reactionCatalogProvider.overrideWith(
              (ref) async => ReactionCatalog(enabled: false, types: []),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: SingleChildScrollView(child: card),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PostActionsBar), findsOneWidget);
      expect(find.text('Comentar'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('falls back to the author initial when an avatar cannot load', (
    tester,
  ) async {
    final api = _FakeApi();
    api.rows.add({
      'id': 1,
      'comentario': 'Hola',
      'autor': 'Ana',
      'fecha': null,
      'avatar_url': 'https://example.com/missing.webp',
    });
    await _render(tester, api);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Hola'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('reads avatar URLs and counts from API metadata', () {
    final comment = PostComment.fromJson({
      'id': 1,
      'comentario': 'Hola',
      'autor': 'Ana',
      'fecha': null,
      'avatar_url': 'http://127.0.0.1:8000/media/uploads/perfiles/ana.webp',
    });
    expect(
      comment.avatarUrl,
      contains('${ApiConfig.baseUrl}/media/uploads/perfiles/ana.webp'),
    );
    final post = Post.fromJson({
      'id': 5,
      'titulo': 'Artículo',
      'slug': 'articulo',
      'comments_count': 3,
    });
    expect(post.commentsCount, 3);
  });
  test('reads and writes the API comment contract', () async {
    final api = _FakeApi();
    final repository = ContentRepository(api);
    await repository.addComment(5, '  Excelente lectura\nGracias  ');
    expect(api.path, '/posts/5/comments');
    expect(api.body, {'comentario': 'Excelente lectura\nGracias'});
    final comments = await repository.comments(5);
    expect(comments.single, isA<PostComment>());
    expect(comments.single.author, 'Ana');
    expect(comments.single.text, 'Excelente lectura\nGracias');
    await expectLater(repository.addComment(5, '  '), throwsArgumentError);
    await expectLater(repository.addComment(5, 'a' * 501), throwsArgumentError);
  });

  testWidgets('visitors can read comments and are invited to log in', (
    tester,
  ) async {
    final api = _FakeApi();
    await _render(tester, api);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('Todavía no hay comentarios'), findsOneWidget);
  });

  testWidgets(
    'validates, prevents duplicate submissions and refreshes after posting',
    (tester) async {
      final api = _FakeApi();
      await _render(tester, api, user: _user);
      await tester.tap(find.text('PUBLICAR COMENTARIO'));
      await tester.pumpAndSettle();
      expect(
        find.text('Escribe un comentario antes de publicar.'),
        findsOneWidget,
      );
      expect(api.body, isNull);

      api.pending = Completer<void>();
      await tester.enterText(
        find.byType(TextFormField),
        'Me encantó esta lectura.',
      );
      await tester.tap(find.text('PUBLICAR COMENTARIO'));
      await tester.pump();
      expect(find.text('PUBLICANDO…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      api.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Me encantó esta lectura.'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('15/11/2026 · 12:30'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('preserves the draft when publishing fails', (tester) async {
    final api = _FakeApi()..fail = true;
    await _render(tester, api, user: _user);
    await tester.enterText(find.byType(TextFormField), 'Mi comentario');
    await tester.tap(find.text('PUBLICAR COMENTARIO'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Conservamos tu texto'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'Mi comentario',
    );
    api.fail = false;
    await tester.ensureVisible(find.text('PUBLICAR COMENTARIO'));
    await tester.tap(find.text('PUBLICAR COMENTARIO'));
    await tester.pumpAndSettle();
    expect(find.text('Mi comentario'), findsOneWidget);
  });
}
