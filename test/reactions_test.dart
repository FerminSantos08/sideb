import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/network/api_client.dart';
import 'package:side_b/core/storage/token_storage.dart';
import 'package:side_b/features/content/data/reactions_repository.dart';
import 'package:side_b/features/content/presentation/reaction_providers.dart';

class _Api extends ApiClient {
  _Api() : super(TokenStorage());
  final paths = <String>[];
  Object? body;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add(path);
    if (path == '/reactions/types') return {'enabled': false, 'types': []};
    if (path.endsWith('/reactions')) {
      return {
        'enabled': true,
        'total': 3,
        'counts': {'sample': 3},
      };
    }
    return {'reaction_id': null};
  }

  @override
  Future<dynamic> put(String path, {Object? data}) async {
    paths.add(path);
    body = data;
    return data;
  }

  @override
  Future<dynamic> delete(String path) async {
    paths.add(path);
    return null;
  }
}

void main() {
  const type = ReactionType(id: 'sample', label: 'Test only', symbol: '*');
  test('catalog rejects more than five types and duplicate ids', () {
    expect(
      () => ReactionCatalog(enabled: true, types: List.filled(6, type)),
      throwsFormatException,
    );
    expect(
      () => ReactionCatalog(enabled: true, types: [type, type]),
      throwsFormatException,
    );
    expect(
      () => ReactionCatalog(enabled: true, types: []),
      throwsFormatException,
    );
    expect(ReactionCatalog(enabled: false, types: []).available, isFalse);
  });

  test('select and remove follow the authenticated API contract', () async {
    final api = _Api();
    final repository = ReactionsRepository(api);
    final catalog = ReactionCatalog(enabled: true, types: [type]);
    await repository.select(5, 'sample', catalog);
    expect(api.paths.single, '/posts/5/reaction');
    expect(api.body, {'reaction_id': 'sample'});
    expect(await repository.selected(5), isNull);
    expect((await repository.summary(5)).total, 3);
    await repository.remove(5);
    expect(api.paths.last, '/posts/5/reaction');
  });

  test(
    'rejects disabled and unknown choices before sending a request',
    () async {
      final api = _Api();
      final repository = ReactionsRepository(api);
      await expectLater(
        repository.select(
          5,
          'unknown',
          ReactionCatalog(enabled: true, types: [type]),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.select(
          5,
          'sample',
          ReactionCatalog(enabled: false, types: []),
        ),
        throwsArgumentError,
      );
      expect(api.paths, isEmpty);
    },
  );

  test('disabled catalog skips per-post requests', () async {
    final api = _Api();
    final container = ProviderContainer(
      overrides: [
        reactionsRepositoryProvider.overrideWithValue(ReactionsRepository(api)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      reactionSummaryProvider(5),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final summary = await container.read(reactionSummaryProvider(5).future);
    expect(summary.enabled, isFalse);
    expect(api.paths, ['/reactions/types']);
  });
}
