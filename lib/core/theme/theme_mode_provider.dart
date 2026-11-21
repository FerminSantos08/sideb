import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final darkThemeProvider = NotifierProvider<DarkThemePreference, bool>(
  DarkThemePreference.new,
);

class DarkThemePreference extends Notifier<bool> {
  static const _key = 'side_b_dark_theme';
  static const _storage = FlutterSecureStorage();
  bool _changed = false;
  Future<void> _pendingWrite = Future.value();

  @override
  bool build() {
    unawaited(_restore());
    return false;
  }

  Future<void> _restore() async {
    try {
      final value = await _storage.read(key: _key);
      if (ref.mounted && !_changed) state = value == 'true';
    } on Exception {
      // Keep the default theme if device storage is unavailable.
    }
  }

  void toggle() {
    _changed = true;
    final dark = !state;
    state = dark;
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _storage.write(key: _key, value: dark.toString());
      } on Exception {
        // The current theme stays active for this session.
      }
    });
  }
}
