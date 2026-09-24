import 'package:flutter/material.dart';

enum ThemePreference { system, light, dark }

enum TargetType { exoplanet, guideStar }

class CelestialTarget {
  const CelestialTarget({
    required this.id,
    required this.name,
    required this.type,
    required this.catalog,
    required this.raDegrees,
    required this.decDegrees,
    this.visualMagnitude,
    this.planetRadiusEarth,
    this.orbitalPeriodDays,
    this.transitMidpointJulian,
    this.transitDurationHours,
  });

  final String id;
  final String name;
  final TargetType type;
  final String catalog;
  final double raDegrees;
  final double decDegrees;
  final double? visualMagnitude;
  final double? planetRadiusEarth;
  final double? orbitalPeriodDays;
  final double? transitMidpointJulian;
  final double? transitDurationHours;

  String get typeLabel => switch (type) {
        TargetType.exoplanet => 'Exoplanet transit',
        TargetType.guideStar => 'Guide star',
      };
}

class VisibilityReport {
  const VisibilityReport({
    required this.target,
    required this.altitude,
    required this.azimuth,
    required this.direction,
    required this.score,
    required this.isObservable,
    required this.visibilityLabel,
    required this.summary,
    this.nextTransit,
  });

  final CelestialTarget target;
  final double altitude;
  final double azimuth;
  final String direction;
  final double score;
  final bool isObservable;
  final String visibilityLabel;
  final String summary;
  final DateTime? nextTransit;
}

class ObservationContext {
  const ObservationContext({
    required this.latitude,
    required this.longitude,
    required this.dateTime,
  });

  final double latitude;
  final double longitude;
  final DateTime dateTime;
}

class TelescopeProfile {
  const TelescopeProfile({
    required this.name,
    required this.type,
    required this.apertureMm,
    required this.focalLengthMm,
    required this.mountType,
    required this.trackingEnabled,
    required this.gotoEnabled,
    required this.pushToEnabled,
    required this.eyepieceFocalLengthMm,
    required this.eyepieceApparentFieldDeg,
  });

  final String name;
  final String type;
  final double apertureMm;
  final double focalLengthMm;
  final String mountType;
  final bool trackingEnabled;
  final bool gotoEnabled;
  final bool pushToEnabled;
  final double eyepieceFocalLengthMm;
  final double eyepieceApparentFieldDeg;

  double get magnification => focalLengthMm / eyepieceFocalLengthMm;
  double get focalRatio => focalLengthMm / apertureMm;
  double get trueFieldOfView => eyepieceApparentFieldDeg / magnification;
  double get maxUsefulMagnification => apertureMm * 2;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'apertureMm': apertureMm,
        'focalLengthMm': focalLengthMm,
        'mountType': mountType,
        'trackingEnabled': trackingEnabled,
        'gotoEnabled': gotoEnabled,
        'pushToEnabled': pushToEnabled,
        'eyepieceFocalLengthMm': eyepieceFocalLengthMm,
        'eyepieceApparentFieldDeg': eyepieceApparentFieldDeg,
      };

  factory TelescopeProfile.fromJson(Map<String, dynamic> json) => TelescopeProfile(
        name: json['name'] as String,
        type: json['type'] as String,
        apertureMm: (json['apertureMm'] as num).toDouble(),
        focalLengthMm: (json['focalLengthMm'] as num).toDouble(),
        mountType: json['mountType'] as String,
        trackingEnabled: json['trackingEnabled'] as bool? ?? false,
        gotoEnabled: json['gotoEnabled'] as bool? ?? false,
        pushToEnabled: json['pushToEnabled'] as bool? ?? false,
        eyepieceFocalLengthMm:
            (json['eyepieceFocalLengthMm'] as num).toDouble(),
        eyepieceApparentFieldDeg:
            (json['eyepieceApparentFieldDeg'] as num).toDouble(),
      );
}

class UserProfile {
  const UserProfile({
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.favoriteTargetIds,
    this.homeLatitude,
    this.homeLongitude,
  });

  final String email;
  final String displayName;
  final DateTime createdAt;
  final double? homeLatitude;
  final double? homeLongitude;
  final List<String> favoriteTargetIds;

  UserProfile copyWith({
    String? displayName,
    DateTime? createdAt,
    double? homeLatitude,
    double? homeLongitude,
    bool clearHomeLatitude = false,
    bool clearHomeLongitude = false,
    List<String>? favoriteTargetIds,
  }) {
    return UserProfile(
      email: email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      homeLatitude:
          clearHomeLatitude ? null : (homeLatitude ?? this.homeLatitude),
      homeLongitude:
          clearHomeLongitude ? null : (homeLongitude ?? this.homeLongitude),
      favoriteTargetIds: favoriteTargetIds ?? this.favoriteTargetIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
        'homeLatitude': homeLatitude,
        'homeLongitude': homeLongitude,
        'favoriteTargetIds': favoriteTargetIds,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        homeLatitude: (json['homeLatitude'] as num?)?.toDouble(),
        homeLongitude: (json['homeLongitude'] as num?)?.toDouble(),
        favoriteTargetIds: List<String>.from(
          json['favoriteTargetIds'] as List<dynamic>? ?? const <String>[],
        ),
      );
}

class StoredAccount {
  const StoredAccount({required this.profile, required this.passwordHash});

  final UserProfile profile;
  final String passwordHash;

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'passwordHash': passwordHash,
      };

  factory StoredAccount.fromJson(Map<String, dynamic> json) => StoredAccount(
        profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
        passwordHash: json['passwordHash'] as String,
      );
}

class AppSettings {
  const AppSettings({
    required this.themePreference,
    required this.useDeviceLocation,
    required this.showOnlyObservable,
    required this.notificationsEnabled,
  });

  final ThemePreference themePreference;
  final bool useDeviceLocation;
  final bool showOnlyObservable;
  final bool notificationsEnabled;

  factory AppSettings.defaults() => const AppSettings(
        themePreference: ThemePreference.system,
        useDeviceLocation: false,
        showOnlyObservable: true,
        notificationsEnabled: true,
      );

  ThemeMode get themeMode => switch (themePreference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  AppSettings copyWith({
    ThemePreference? themePreference,
    bool? useDeviceLocation,
    bool? showOnlyObservable,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      useDeviceLocation: useDeviceLocation ?? this.useDeviceLocation,
      showOnlyObservable: showOnlyObservable ?? this.showOnlyObservable,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'themePreference': themePreference.name,
        'useDeviceLocation': useDeviceLocation,
        'showOnlyObservable': showOnlyObservable,
        'notificationsEnabled': notificationsEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themePreference: ThemePreference.values.firstWhere(
          (value) => value.name == json['themePreference'],
          orElse: () => ThemePreference.system,
        ),
        useDeviceLocation: json['useDeviceLocation'] as bool? ?? false,
        showOnlyObservable: json['showOnlyObservable'] as bool? ?? true,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      );
}

class SolarSnapshot {
  const SolarSnapshot({required this.altitude, required this.label});

  final double altitude;
  final String label;
}
