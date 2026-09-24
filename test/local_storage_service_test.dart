import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telestronomy/src/local_storage_service.dart';
import 'package:telestronomy/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores and restores accounts and settings', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    const settings = AppSettings(
      themePreference: ThemePreference.dark,
      useDeviceLocation: true,
      showOnlyObservable: false,
      notificationsEnabled: true,
    );
    final account = StoredAccount(
      profile: UserProfile(
        email: 'astro@example.com',
        displayName: 'Astronomer',
        createdAt: DateTime.utc(2026, 1, 1),
        homeLatitude: 40,
        homeLongitude: -75,
        favoriteTargetIds: const ['exo:1'],
      ),
      passwordHash: 'hash',
    );

    await storage.upsertAccount(account);
    await storage.saveSessionEmail(account.profile.email);
    await storage.saveSettings(account.profile.email, settings);

    final accounts = await storage.loadAccounts();
    final session = await storage.loadSessionEmail();
    final restoredSettings = await storage.loadSettings(account.profile.email);

    expect(accounts.single.profile.displayName, 'Astronomer');
    expect(session, account.profile.email);
    expect(restoredSettings.themePreference, ThemePreference.dark);
    expect(restoredSettings.useDeviceLocation, isTrue);
  });
}
