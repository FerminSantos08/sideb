import 'package:side_b/core/config/api_config.dart';

import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:side_b/core/network/api_client.dart';
import 'package:side_b/core/network/api_exception.dart';
import 'package:side_b/core/storage/token_storage.dart';
import 'package:side_b/core/widgets/user_avatar.dart';
import 'package:side_b/features/auth/auth.dart';
import 'package:side_b/features/checkout/data/checkout_repository.dart';
import 'package:side_b/features/profile/data/profile_repository.dart';
import 'package:side_b/features/profile/presentation/address_book_screen.dart';
import 'package:side_b/features/profile/presentation/profile_settings_screen.dart';

class _Tokens extends TokenStorage {
  @override
  Future<String?> read() async => 'test-token';
}

class _ImageAdapter implements HttpClientAdapter {
  final bytes = <int>[];
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    return ResponseBody.fromString(
      jsonEncode(_json()),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _user = AuthUser(
  id: 1,
  name: 'Ana',
  email: 'ana@example.com',
  role: 'Listener',
  username: 'ana',
  biography: 'Música',
);
Map<String, dynamic> _json() => {
  'id': 1,
  'name': 'ana',
  'email': 'ana@example.com',
  'role': {'name': 'Listener'},
  'profile': {
    'alias': 'Ana',
    'biografia': 'Música',
    'avatar_url': 'http://127.0.0.1:8000/media/uploads/perfiles/ana.webp',
  },
};

class _Api extends ApiClient {
  _Api() : super(TokenStorage());
  String? path;
  Object? body;
  @override
  Future<dynamic> put(String path, {Object? data}) async {
    this.path = path;
    body = data;
    return _json();
  }

  @override
  Future<dynamic> uploadBytes(String path, List<int> bytes) async {
    this.path = path;
    body = bytes;
    return _json();
  }
}

class _Repository extends ProfileRepository {
  _Repository() : super(_Api());
  int saves = 0, photos = 0, passwords = 0, deletes = 0;
  bool fail = false;
  String? savedAlias;
  List<DeliveryAddress> rows = [
    const DeliveryAddress(
      id: 1,
      label: 'Casa',
      address: 'Calle uno',
      isDefault: true,
    ),
    const DeliveryAddress(
      id: 2,
      label: 'Trabajo',
      address: 'Calle dos',
      isDefault: false,
    ),
  ];
  @override
  Future<AuthUser> save(String alias, String biography) async {
    saves++;
    savedAlias = alias;
    if (fail) throw const ApiException('No se guardó');
    return AuthUser(
      id: 1,
      name: alias,
      email: _user.email,
      role: 'Listener',
      biography: biography,
    );
  }

  @override
  Future<AuthUser> avatar(List<int> bytes) async {
    photos++;
    return AuthUser.fromJson(_json());
  }

  @override
  Future<void> password(
    String current,
    String next,
    String confirmation,
  ) async {
    passwords++;
    if (fail)
      throw const ApiException(
        'La contraseña actual no es correcta.',
        statusCode: 403,
      );
  }

  @override
  Future<List<DeliveryAddress>> addresses() async => rows;
  @override
  Future<void> saveAddress({
    int? id,
    required String label,
    required String address,
    required bool isDefault,
  }) async {
    if (fail) throw const ApiException('No se guardó');
  }

  @override
  Future<void> setDefault(int id) async {
    rows = [
      for (final row in rows)
        DeliveryAddress(
          id: row.id,
          label: row.label,
          address: row.address,
          isDefault: row.id == id,
        ),
    ];
  }

  @override
  Future<void> removeAddress(int id) async {
    deletes++;
    rows = rows.where((row) => row.id != id).toList();
    if (rows.isNotEmpty) await setDefault(rows.first.id);
  }
}

class _Session extends AuthController {
  bool loggedOut = false;
  @override
  Future<AuthUser?> build() async => _user;
  @override
  Future<void> logout() async {
    loggedOut = true;
    state = const AsyncData(null);
  }
}

Future<void> _render(
  WidgetTester tester,
  _Repository repository,
  Widget child,
) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(_Session.new),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'avatar upload sends authenticated raw bytes rather than a JSON array',
    () async {
      final client = ApiClient(_Tokens());
      final adapter = _ImageAdapter();
      client.dio.httpClientAdapter = adapter;
      addTearDown(() => client.dio.close());
      await client.uploadBytes('/profile/avatar', [137, 80, 78, 71]);
      expect(adapter.bytes, [137, 80, 78, 71]);
      expect(adapter.request!.contentType, 'application/octet-stream');
      expect(adapter.request!.headers['Authorization'], 'Bearer test-token');
      expect(
        adapter.request!.headers[Headers.contentLengthHeader].toString(),
        '4',
      );
    },
  );
  test(
    'profile contract maps shared avatar and sends password text unchanged',
    () async {
      final api = _Api();
      final repository = ProfileRepository(api);
      final saved = await repository.save('  Ana  ', '  Música  ');
      expect(api.body, {'alias': 'Ana', 'biography': 'Música'});
      expect(
        saved.avatarUrl,
        contains('${ApiConfig.baseUrl}/media/uploads/perfiles/ana.webp'),
      );
      expect(saved.username, 'ana');
      await repository.password(' old pass ', 'new pass 123', 'new pass 123');
      expect(api.path, '/profile/password');
      expect((api.body as Map)['current_password'], ' old pass ');
      await repository.avatar([1, 2, 3]);
      expect(api.path, '/profile/avatar');
      expect(api.body, [1, 2, 3]);
    },
  );
  testWidgets(
    'validates alias, preserves failed edits and refreshes the authenticated profile',
    (tester) async {
      final repository = _Repository()..fail = true;
      await _render(
        tester,
        repository,
        const ProfileSettingsScreen(user: _user),
      );
      await tester.enterText(find.byType(TextFormField).first, '');
      await _visible(tester, find.text('GUARDAR PERFIL'));
      await tester.tap(find.text('GUARDAR PERFIL'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu alias.'), findsOneWidget);
      expect(repository.saves, 0);
      await tester.enterText(find.byType(TextFormField).first, 'Ana vinilos');
      await _visible(tester, find.text('GUARDAR PERFIL'));
      await tester.tap(find.text('GUARDAR PERFIL'));
      await tester.pumpAndSettle();
      expect(find.text('No se guardó'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Ana vinilos',
      );
      repository.fail = false;
      await _visible(tester, find.text('GUARDAR PERFIL'));
      await tester.tap(find.text('GUARDAR PERFIL'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil actualizado.'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileSettingsScreen)),
      );
      expect(container.read(authProvider).requireValue!.name, 'Ana vinilos');
    },
  );
  testWidgets(
    'photo selection requires confirmation and cancellation does not upload',
    (tester) async {
      final repository = _Repository();
      const channel = MethodChannel('side_b/profile');
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAC0lEQVQImWNgQAYAAA4AAbGa6gYAAAAASUVORK5CYII=',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => png,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await _render(
        tester,
        repository,
        const ProfileSettingsScreen(user: _user),
      );
      await tester.tap(find.text('ACTUALIZAR FOTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(repository.photos, 0);
      await tester.tap(find.text('ACTUALIZAR FOTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USAR ESTA FOTO'));
      await tester.pumpAndSettle();
      expect(repository.photos, 1);
      expect(find.text('Foto actualizada.'), findsOneWidget);
      expect(
        tester.widget<UserAvatar>(find.byType(UserAvatar)).url,
        contains('/perfiles/ana.webp'),
      );
    },
  );
  testWidgets('failed address saves keep the draft for retry', (tester) async {
    await _render(
      tester,
      _Repository()..fail = true,
      const AddressEditorScreen(),
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'Mi dirección completa',
    );
    await _visible(tester, find.text('GUARDAR DIRECCIÓN'));
    await tester.tap(find.text('GUARDAR DIRECCIÓN'));
    await tester.pumpAndSettle();
    expect(find.text('No se guardó'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      'Mi dirección completa',
    );
  });
  testWidgets(
    'address default and deletion use the current list and require confirmation',
    (tester) async {
      final repository = _Repository();
      await _render(tester, repository, const AddressBookScreen());
      await _visible(tester, find.text('USAR COMO PRINCIPAL'));
      await tester.tap(find.text('USAR COMO PRINCIPAL'));
      await tester.pumpAndSettle();
      expect(find.text('Trabajo · Principal'), findsOneWidget);
      await _visible(tester, find.byTooltip('Eliminar Trabajo'));
      await tester.tap(find.byTooltip('Eliminar Trabajo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      await tester.tap(find.byTooltip('Eliminar Trabajo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ELIMINAR'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 1);
      expect(find.text('Casa · Principal'), findsOneWidget);
    },
  );
  testWidgets('password mismatch makes no request and success signs out', (
    tester,
  ) async {
    final repository = _Repository();
    await _render(tester, repository, const ChangePasswordScreen());
    await tester.enterText(find.byType(TextFormField).at(0), 'current123');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await _visible(tester, find.text('CAMBIAR CONTRASEÑA'));
    await tester.tap(find.text('CAMBIAR CONTRASEÑA'));
    await tester.pumpAndSettle();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(repository.passwords, 0);
    await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
    await _visible(tester, find.text('CAMBIAR CONTRASEÑA'));
    await tester.tap(find.text('CAMBIAR CONTRASEÑA'));
    await tester.pumpAndSettle();
    expect(repository.passwords, 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChangePasswordScreen)),
    );
    expect(
      (container.read(authProvider.notifier) as _Session).loggedOut,
      isTrue,
    );
  });
}
