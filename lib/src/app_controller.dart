import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'astronomy_engine.dart';
import 'local_storage_service.dart';
import 'models.dart';

class AppController extends ChangeNotifier {
  AppController({
    LocalStorageService? storage,
    AstronomyEngine? astronomyEngine,
  })  : _storage = storage ?? LocalStorageService(),
        _astronomyEngine = astronomyEngine ?? const AstronomyEngine();

  final LocalStorageService _storage;
  final AstronomyEngine _astronomyEngine;

  bool isInitializing = true;
  bool isBusy = false;
  String? errorMessage;
  List<CelestialTarget> targets = const <CelestialTarget>[];
  UserProfile? currentUser;
  AppSettings settings = AppSettings.defaults();
  TelescopeProfile? telescopeProfile;
  Position? currentPosition;

  bool get isAuthenticated => currentUser != null;

  ObservationContext? get observationContext {
    final DateTime now = DateTime.now();
    if (settings.useDeviceLocation && currentPosition != null) {
      return ObservationContext(
        latitude: currentPosition!.latitude,
        longitude: currentPosition!.longitude,
        dateTime: now,
      );
    }
    final user = currentUser;
    if (user?.homeLatitude != null && user?.homeLongitude != null) {
      return ObservationContext(
        latitude: user!.homeLatitude!,
        longitude: user.homeLongitude!,
        dateTime: now,
      );
    }
    return null;
  }

  String get authModeLabel => 'Local-only account';

  Future<void> initialize() async {
    isInitializing = true;
    notifyListeners();
    try {
      targets = await _loadTargets();
      final sessionEmail = await _storage.loadSessionEmail();
      if (sessionEmail != null) {
        final accounts = await _storage.loadAccounts();
        final account = accounts.where((item) => item.profile.email == sessionEmail).firstOrNull;
        if (account != null) {
          await _restoreAccount(account.profile);
        }
      }
    } catch (error) {
      errorMessage = 'Failed to load Telestronomy: $error';
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<String?> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    return _wrapBusy(() async {
      final normalizedEmail = email.trim().toLowerCase();
      final accounts = await _storage.loadAccounts();
      final exists = accounts.any(
        (account) => account.profile.email.toLowerCase() == normalizedEmail,
      );
      if (exists) {
        return 'An account with that email already exists on this device.';
      }
      final profile = UserProfile(
        email: normalizedEmail,
        displayName: displayName.trim(),
        createdAt: DateTime.now(),
        favoriteTargetIds: const <String>[],
      );
      final account = StoredAccount(
        profile: profile,
        passwordHash: _hashPassword(password),
      );
      await _storage.upsertAccount(account);
      await _storage.saveSettings(profile.email, AppSettings.defaults());
      await _storage.saveSessionEmail(profile.email);
      currentUser = profile;
      settings = AppSettings.defaults();
      telescopeProfile = null;
      return null;
    });
  }

  Future<String?> signIn({required String email, required String password}) async {
    return _wrapBusy(() async {
      final normalizedEmail = email.trim().toLowerCase();
      final passwordHash = _hashPassword(password);
      final accounts = await _storage.loadAccounts();
      final account = accounts.where((item) {
        return item.profile.email.toLowerCase() == normalizedEmail &&
            item.passwordHash == passwordHash;
      }).firstOrNull;
      if (account == null) {
        return 'Incorrect email or password for this device.';
      }
      await _restoreAccount(account.profile);
      await _storage.saveSessionEmail(account.profile.email);
      return null;
    });
  }

  Future<void> signOut() async {
    currentUser = null;
    settings = AppSettings.defaults();
    telescopeProfile = null;
    currentPosition = null;
    await _storage.saveSessionEmail(null);
    notifyListeners();
  }

  Future<void> saveProfile({
    required String displayName,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    final updated = user.copyWith(
      displayName: displayName.trim(),
      homeLatitude: latitude,
      homeLongitude: longitude,
      clearHomeLatitude: clearCoordinates,
      clearHomeLongitude: clearCoordinates,
    );
    await _persistUser(updated);
  }

  Future<void> saveSettings(AppSettings nextSettings) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    settings = nextSettings;
    await _storage.saveSettings(user.email, nextSettings);
    notifyListeners();
  }

  Future<void> saveTelescopeProfile(TelescopeProfile? profile) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    telescopeProfile = profile;
    await _storage.saveTelescope(user.email, profile);
    notifyListeners();
  }

  Future<String?> refreshLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Location permission was not granted.';
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Location services are disabled.';
      }
      currentPosition = await Geolocator.getCurrentPosition();
      notifyListeners();
      return null;
    } catch (error) {
      return 'Unable to read device location: $error';
    }
  }

  Future<void> toggleFavorite(String targetId) async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    final favorites = List<String>.from(user.favoriteTargetIds);
    if (favorites.contains(targetId)) {
      favorites.remove(targetId);
    } else {
      favorites.add(targetId);
    }
    await _persistUser(user.copyWith(favoriteTargetIds: favorites));
  }

  bool isFavorite(String targetId) =>
      currentUser?.favoriteTargetIds.contains(targetId) ?? false;

  List<VisibilityReport> recommendations({
    String query = '',
    bool favoritesOnly = false,
    int? limit,
  }) {
    final context = observationContext;
    if (context == null) {
      return const <VisibilityReport>[];
    }
    final normalizedQuery = query.trim().toLowerCase();
    final filteredTargets = targets.where((target) {
      final matchesQuery = normalizedQuery.isEmpty ||
          target.name.toLowerCase().contains(normalizedQuery) ||
          target.catalog.toLowerCase().contains(normalizedQuery);
      final matchesFavorite = !favoritesOnly || isFavorite(target.id);
      return matchesQuery && matchesFavorite;
    });

    final reports = filteredTargets
        .map(
          (target) => _astronomyEngine.evaluateTarget(
            target: target,
            context: context,
            telescope: telescopeProfile,
          ),
        )
        .where(
          (report) => !settings.showOnlyObservable || report.isObservable,
        )
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));

    if (limit != null && reports.length > limit) {
      return reports.take(limit).toList(growable: false);
    }
    return reports;
  }

  SolarSnapshot? get solarSnapshot {
    final context = observationContext;
    if (context == null) {
      return null;
    }
    return _astronomyEngine.solarSnapshot(context);
  }

  String? get locationLabel {
    if (settings.useDeviceLocation && currentPosition != null) {
      return 'Device location • ${currentPosition!.latitude.toStringAsFixed(2)}, '
          '${currentPosition!.longitude.toStringAsFixed(2)}';
    }
    final user = currentUser;
    if (user?.homeLatitude != null && user?.homeLongitude != null) {
      return 'Saved location • ${user!.homeLatitude!.toStringAsFixed(2)}, '
          '${user.homeLongitude!.toStringAsFixed(2)}';
    }
    return null;
  }

  Future<void> _restoreAccount(UserProfile profile) async {
    currentUser = profile;
    settings = await _storage.loadSettings(profile.email);
    telescopeProfile = await _storage.loadTelescope(profile.email);
    if (settings.useDeviceLocation) {
      await refreshLocation();
    }
    notifyListeners();
  }

  Future<void> _persistUser(UserProfile profile) async {
    final accounts = await _storage.loadAccounts();
    final existing = accounts.where((item) => item.profile.email == profile.email).firstOrNull;
    if (existing == null) {
      return;
    }
    await _storage.upsertAccount(
      StoredAccount(profile: profile, passwordHash: existing.passwordHash),
    );
    currentUser = profile;
    notifyListeners();
  }

  String _hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<String?> _wrapBusy(Future<String?> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      errorMessage = error.toString();
      return errorMessage;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<List<CelestialTarget>> _loadTargets() async {
    final jsonContent = await rootBundle.loadString('exoplanets_catalogue.json');
    final rawItems = jsonDecode(jsonContent) as List<dynamic>;
    final exoplanets = rawItems
        .map((item) => item as Map<String, dynamic>)
        .where(
          (item) => item['ra'] != null && item['dec'] != null && item['pl_name'] != null,
        )
        .map(
          (item) => CelestialTarget(
            id: 'exo:${item['pl_name']}',
            name: item['pl_name'] as String,
            type: TargetType.exoplanet,
            catalog: 'NASA Exoplanet Archive',
            raDegrees: double.parse(item['ra'] as String),
            decDegrees: double.parse(item['dec'] as String),
            visualMagnitude: double.tryParse('${item['sy_vmag'] ?? ''}'),
            planetRadiusEarth: double.tryParse('${item['pl_rade'] ?? ''}'),
            orbitalPeriodDays: double.tryParse('${item['pl_orbper'] ?? ''}'),
            transitMidpointJulian:
                double.tryParse('${item['pl_tranmid'] ?? ''}'),
            transitDurationHours:
                double.tryParse('${item['pl_trandur'] ?? ''}'),
          ),
        )
        .where((target) => target.visualMagnitude == null || target.visualMagnitude! < 16)
        .toList(growable: false);

    final guideStars = await _loadGuideStars();
    return [...guideStars, ...exoplanets];
  }

  Future<List<CelestialTarget>> _loadGuideStars() async {
    final text = await rootBundle.loadString('scopey_complete_astronomy_data.txt');
    final exp = RegExp(
      r'RA\s+(\d+)h\s+(\d+)m\s+([\d.]+)s\s+Dec\s+([+-]?\d+)°\s+(\d+)\'\s+([\d.]+)\'\'([^`]+)`[A-Z0-9]+`([^V]+)View sky map',
    );
    final matches = exp.allMatches(text).take(30);
    return matches.map((match) {
      final raHours = double.parse(match.group(1)!);
      final raMinutes = double.parse(match.group(2)!);
      final raSeconds = double.parse(match.group(3)!);
      final decDegreesRaw = double.parse(match.group(4)!);
      final decMinutes = double.parse(match.group(5)!);
      final decSeconds = double.parse(match.group(6)!);
      final constellation = match.group(7)!.trim();
      final name = match.group(8)!.trim();
      final sign = decDegreesRaw < 0 ? -1 : 1;
      final ra = (raHours + (raMinutes / 60) + (raSeconds / 3600)) * 15;
      final dec = decDegreesRaw + sign * (decMinutes / 60) + sign * (decSeconds / 3600);
      return CelestialTarget(
        id: 'guide:$name',
        name: name,
        type: TargetType.guideStar,
        catalog: 'Scopey guide star • $constellation',
        raDegrees: ra,
        decDegrees: dec,
      );
    }).toList(growable: false);
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
