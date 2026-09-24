import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LocalStorageService {
  LocalStorageService({Future<SharedPreferences> Function()? preferencesFactory})
      : _preferencesFactory = preferencesFactory ?? SharedPreferences.getInstance;

  static const _accountsKey = 'accounts';
  static const _sessionEmailKey = 'sessionEmail';
  static const _settingsPrefix = 'settings:';
  static const _telescopePrefix = 'telescope:';

  final Future<SharedPreferences> Function() _preferencesFactory;

  Future<List<StoredAccount>> loadAccounts() async {
    final preferences = await _preferencesFactory();
    final rawAccounts = preferences.getStringList(_accountsKey) ?? const <String>[];
    return rawAccounts
        .map((entry) => StoredAccount.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  Future<void> saveAccounts(List<StoredAccount> accounts) async {
    final preferences = await _preferencesFactory();
    await preferences.setStringList(
      _accountsKey,
      accounts.map((account) => jsonEncode(account.toJson())).toList(),
    );
  }

  Future<void> upsertAccount(StoredAccount updatedAccount) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere(
      (account) => account.profile.email == updatedAccount.profile.email,
    );
    final next = List<StoredAccount>.from(accounts);
    if (index == -1) {
      next.add(updatedAccount);
    } else {
      next[index] = updatedAccount;
    }
    await saveAccounts(next);
  }

  Future<String?> loadSessionEmail() async {
    final preferences = await _preferencesFactory();
    return preferences.getString(_sessionEmailKey);
  }

  Future<void> saveSessionEmail(String? email) async {
    final preferences = await _preferencesFactory();
    if (email == null) {
      await preferences.remove(_sessionEmailKey);
      return;
    }
    await preferences.setString(_sessionEmailKey, email);
  }

  Future<AppSettings> loadSettings(String email) async {
    final preferences = await _preferencesFactory();
    final raw = preferences.getString('$_settingsPrefix$email');
    if (raw == null) {
      return AppSettings.defaults();
    }
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(String email, AppSettings settings) async {
    final preferences = await _preferencesFactory();
    await preferences.setString(
      '$_settingsPrefix$email',
      jsonEncode(settings.toJson()),
    );
  }

  Future<TelescopeProfile?> loadTelescope(String email) async {
    final preferences = await _preferencesFactory();
    final raw = preferences.getString('$_telescopePrefix$email');
    if (raw == null) {
      return null;
    }
    return TelescopeProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTelescope(String email, TelescopeProfile? telescope) async {
    final preferences = await _preferencesFactory();
    final key = '$_telescopePrefix$email';
    if (telescope == null) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(key, jsonEncode(telescope.toJson()));
  }
}
