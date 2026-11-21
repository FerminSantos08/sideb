import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/network/api_client.dart';
import 'package:side_b/core/network/api_exception.dart';
import 'package:side_b/core/storage/token_storage.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/content/data/content_models.dart';
import 'package:side_b/features/creation/data/editorial_repository.dart';
import 'package:side_b/features/creation/presentation/creation_hub_screen.dart';
import 'package:side_b/features/creation/presentation/creation_providers.dart';
import 'package:side_b/features/creation/presentation/editorial_management_screen.dart';
import 'package:side_b/features/library/data/saved_posts_repository.dart';
import 'package:side_b/features/library/presentation/saved_posts_screen.dart';

const _post = Post(
  id: 7,
  title: 'Artículo original',
  description: 'Descripción',
  slug: 'articulo-original',
  content: '<h2>Subtítulo</h2><p>Texto original.</p>',
  status: 'borrador',
);
const _author = AuthUser(
  id: 1,
  name: 'Ana',
  email: 'ana@example.com',
  role: 'Artista',
  roleId: 2,
);

class _Session extends AuthController {
  _Session(this.user);
  final AuthUser? user;
  @override
  Future<AuthUser?> build() async => user;
}

class _Api extends ApiClient {
  _Api() : super(TokenStorage());
  String? path;
  Object? body;
  @override
  Future<dynamic> put(String path, {Object? data}) async {
    this.path = path;
    body = data;
    return {
      'post': {'id': 7, 'titulo': 'Artículo', 'slug': 'articulo'},
      'artist_ids': [],
      'album_ids': [],
      'revision': 'b' * 64,
    };
  }
}

class _Saved extends SavedPostsRepository {
  _Saved() : super(_Api());
  final ids = <int>{};
  bool fail = false;
  int writes = 0;
  @override
  Future<SavedPosts> load() async =>
      SavedPosts(posts: ids.contains(7) ? [_post] : [], ids: ids);
  @override
  Future<void> save(int id) async {
    if (fail) throw const ApiException('Sin conexión');
    writes++;
    ids.add(id);
  }

  @override
  Future<void> remove(int id) async {
    if (fail) throw const ApiException('Sin conexión');
    writes++;
    ids.remove(id);
  }
}

class _Editorial extends EditorialRepository {
  _Editorial() : super(_Api());
  bool fail = false;
  int reads = 0;
  int uploads = 0;
  PublicationDraft? submitted;
  @override
  Future<String> uploadCover(List<int> bytes) async {
    uploads++;
    return 'd' * 32;
  }

  final revisions = <String>[];
  EditablePublication current = EditablePublication(
    post: _post,
    artistIds: [],
    albumIds: [],
    revision: 'a' * 64,
  );
  @override
  Future<List<Post>> publications() async {
    reads++;
    return [current.post];
  }

  @override
  Future<EditablePublication> editable(int id) async => current;
  @override
  Future<EditorialOptions> options() async =>
      const EditorialOptions(artists: [], albums: []);
  @override
  Future<EditablePublication> update(
    int id,
    PublicationDraft draft,
    String revision,
  ) async {
    submitted = draft;
    revisions.add(revision);
    if (fail)
      throw const ApiException(
        'Cambió en otra sesión. Conserva tus cambios.',
        statusCode: 409,
      );
    expect(revision, current.revision);
    current = EditablePublication(
      post: Post(
        id: id,
        title: draft.title,
        description: draft.description ?? '',
        slug: current.post.slug,
        content: draft.content,
        status: draft.state,
      ),
      artistIds: draft.artistIds,
      albumIds: draft.albumIds,
      revision: revisions.length.isEven ? 'c' * 64 : 'b' * 64,
    );
    return current;
  }
}

Future<void> _render(
  WidgetTester tester,
  Widget child, {
  _Saved? saved,
  _Editorial? editorial,
  AuthUser? user = _author,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => _Session(user)),
        savedPostsRepositoryProvider.overrideWithValue(saved ?? _Saved()),
        editorialRepositoryProvider.overrideWithValue(
          editorial ?? _Editorial(),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  for (var i = 0; i < 20 && finder.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
}

void main() {
  test(
    'editorial update sends the revision and preserves HTML and associations',
    () async {
      final api = _Api();
      final repository = EditorialRepository(api);
      await repository.update(
        7,
        const PublicationDraft(
          title: 'Título',
          content: '<h2>Subtítulo</h2>',
          state: 'borrador',
          artistIds: [2],
          albumIds: [4],
        ),
        'a' * 64,
      );
      expect(api.path, '/editorial/posts/7');
      final body = api.body as Map;
      expect(body['revision'], 'a' * 64);
      expect(body['content'], '<h2>Subtítulo</h2>');
      expect(body['artist_ids'], [2]);
    },
  );
  test('numeric editorial role ids support Spanish role names', () {
    const executive = AuthUser(
      id: 1,
      name: 'Ana',
      email: 'a@example.com',
      role: 'Productor Ejecutivo',
      roleId: 3,
    );
    expect(executive.canPublish, isTrue);
    expect(executive.canManageAllPosts, isTrue);
  });
  testWidgets('bookmark reflects persisted state and can be removed', (
    tester,
  ) async {
    final saved = _Saved();
    await _render(
      tester,
      const Scaffold(body: SavePostButton(postId: 7)),
      saved: saved,
    );
    await tester.tap(find.byTooltip('Guardar publicación'));
    await tester.pumpAndSettle();
    expect(saved.ids, {7});
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar publicación de guardados'));
    await tester.pumpAndSettle();
    expect(saved.ids, isEmpty);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });
  testWidgets('failed bookmarking preserves confirmed state', (tester) async {
    final saved = _Saved()..fail = true;
    await _render(
      tester,
      const Scaffold(body: SavePostButton(postId: 7)),
      saved: saved,
    );
    await tester.tap(find.byTooltip('Guardar publicación'));
    await tester.pumpAndSettle();
    expect(saved.ids, isEmpty);
    expect(find.text('Sin conexión'), findsOneWidget);
  });
  testWidgets(
    'saved articles list removes a bookmark without editing the article',
    (tester) async {
      final saved = _Saved()..ids.add(7);
      await _render(tester, const SavedPostsScreen(), saved: saved);
      expect(find.text('Artículo original'), findsOneWidget);
      await tester.tap(find.byTooltip('Quitar de guardados'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Aún no tienes publicaciones'),
        findsOneWidget,
      );
      expect(_post.content, contains('Texto original'));
    },
  );
  testWidgets('editor loads a draft and retains changes on conflict', (
    tester,
  ) async {
    final editorial = _Editorial()..fail = true;
    await _render(
      tester,
      Scaffold(body: CreationHubScreen(initial: editorial.current)),
      editorial: editorial,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(3))
          .controller!
          .text,
      _post.content,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Mi nueva versión',
    );
    await _visible(tester, find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cambió en otra sesión'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Mi nueva versión',
    );
    editorial.fail = false;
    await _visible(tester, find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Publicación actualizada.'), findsOneWidget);
    await _visible(tester, find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(editorial.revisions.last, isNot('a' * 64));
    expect(editorial.current.post.slug, 'articulo-original');
  });
  testWidgets('listener cannot open editorial management', (tester) async {
    final editorial = _Editorial();
    await _render(
      tester,
      const EditorialManagementScreen(),
      editorial: editorial,
      user: const AuthUser(
        id: 2,
        name: 'Luis',
        email: 'l@example.com',
        role: 'Listener',
        roleId: 1,
      ),
    );
    expect(find.textContaining('no tiene acceso'), findsOneWidget);
    expect(editorial.reads, 0);
  });
  testWidgets(
    'cover preview stays local and a failed save reuses the upload token',
    (tester) async {
      final editorial = _Editorial()..fail = true;
      const channel = MethodChannel('side_b/profile');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
            ),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await _render(
        tester,
        Scaffold(body: CreationHubScreen(initial: editorial.current)),
        editorial: editorial,
      );
      await _visible(tester, find.text('ELEGIR PORTADA'));
      await tester.tap(find.text('ELEGIR PORTADA'));
      await tester.pumpAndSettle();
      expect(editorial.uploads, 0);
      expect(find.text('CANCELAR CAMBIO DE PORTADA'), findsOneWidget);
      await _visible(tester, find.text('CANCELAR CAMBIO DE PORTADA'));
      await tester.tap(find.text('CANCELAR CAMBIO DE PORTADA'));
      await tester.pumpAndSettle();
      expect(editorial.uploads, 0);
      expect(find.text('CANCELAR CAMBIO DE PORTADA'), findsNothing);
      await _visible(tester, find.text('ELEGIR PORTADA'));
      await tester.tap(find.text('ELEGIR PORTADA'));
      await tester.pumpAndSettle();
      await _visible(tester, find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(editorial.uploads, 1);
      expect(editorial.submitted!.coverToken, 'd' * 32);
      expect(find.text('CANCELAR CAMBIO DE PORTADA'), findsOneWidget);
      editorial.fail = false;
      await _visible(tester, find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(editorial.uploads, 1);
      expect(find.text('Publicación actualizada.'), findsOneWidget);
      expect(find.text('CANCELAR CAMBIO DE PORTADA'), findsNothing);
    },
  );
}
