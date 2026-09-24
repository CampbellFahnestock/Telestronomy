import 'dart:math';

import 'models.dart';

class AstronomyEngine {
  const AstronomyEngine();

  VisibilityReport evaluateTarget({
    required CelestialTarget target,
    required ObservationContext context,
    TelescopeProfile? telescope,
  }) {
    final position = equatorialToHorizontal(
      raDegrees: target.raDegrees,
      decDegrees: target.decDegrees,
      context: context,
    );
    final score = _scoreTarget(
      target: target,
      altitude: position.altitude,
      telescope: telescope,
    );
    final observable = position.altitude > 0;
    final visibilityLabel = _visibilityLabel(position.altitude);
    final nextTransit = predictNextTransit(target, context.dateTime.toUtc());
    final summary = _summaryFor(
      altitude: position.altitude,
      azimuth: position.azimuth,
      target: target,
      telescope: telescope,
      nextTransit: nextTransit,
    );

    return VisibilityReport(
      target: target,
      altitude: position.altitude,
      azimuth: position.azimuth,
      direction: directionFromAzimuth(position.azimuth),
      score: score,
      isObservable: observable,
      visibilityLabel: visibilityLabel,
      summary: summary,
      nextTransit: nextTransit,
    );
  }

  SolarSnapshot solarSnapshot(ObservationContext context) {
    final altitude = solarAltitude(
      latitude: context.latitude,
      longitude: context.longitude,
      dateTimeUtc: context.dateTime.toUtc(),
    );

    final label = switch (altitude) {
      <= -18 => 'Astronomical darkness',
      <= -12 => 'Nautical twilight',
      <= -6 => 'Civil twilight',
      <= 0 => 'Sun below horizon',
      _ => 'Daylight',
    };

    return SolarSnapshot(altitude: altitude, label: label);
  }

  HorizontalPosition equatorialToHorizontal({
    required double raDegrees,
    required double decDegrees,
    required ObservationContext context,
  }) {
    final lst = localSiderealTime(
      dateTimeUtc: context.dateTime.toUtc(),
      longitudeDegrees: context.longitude,
    );
    final hourAngle = _normalizeDegrees(lst - raDegrees);
    final haRad = _degToRad(hourAngle > 180 ? hourAngle - 360 : hourAngle);
    final decRad = _degToRad(decDegrees);
    final latRad = _degToRad(context.latitude);

    final altitudeRad = asin(
      sin(decRad) * sin(latRad) +
          cos(decRad) * cos(latRad) * cos(haRad),
    );
    final azimuthRad = atan2(
      -sin(haRad),
      tan(decRad) * cos(latRad) - sin(latRad) * cos(haRad),
    );

    return HorizontalPosition(
      altitude: _radToDeg(altitudeRad),
      azimuth: _normalizeDegrees(_radToDeg(azimuthRad)),
    );
  }

  DateTime? predictNextTransit(CelestialTarget target, DateTime afterUtc) {
    if (target.orbitalPeriodDays == null || target.transitMidpointJulian == null) {
      return null;
    }
    final currentJulian = julianDay(afterUtc);
    var cycles = ((currentJulian - target.transitMidpointJulian!) /
            target.orbitalPeriodDays!)
        .floor();
    var nextJulian =
        target.transitMidpointJulian! + ((cycles + 1) * target.orbitalPeriodDays!);
    while (nextJulian <= currentJulian) {
      cycles += 1;
      nextJulian =
          target.transitMidpointJulian! + ((cycles + 1) * target.orbitalPeriodDays!);
    }
    return dateTimeFromJulian(nextJulian);
  }

  double solarAltitude({
    required double latitude,
    required double longitude,
    required DateTime dateTimeUtc,
  }) {
    final jd = julianDay(dateTimeUtc);
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = _normalizeDegrees(280.46646 + t * (36000.76983 + t * 0.0003032));
    final m = _normalizeDegrees(357.52911 + t * (35999.05029 - 0.0001537 * t));
    final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    final c = sin(_degToRad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        sin(_degToRad(2 * m)) * (0.019993 - 0.000101 * t) +
        sin(_degToRad(3 * m)) * 0.000289;
    final trueLongitude = l0 + c;
    final omega = 125.04 - 1934.136 * t;
    final lambda = trueLongitude - 0.00569 - 0.00478 * sin(_degToRad(omega));
    final epsilon0 = 23 +
        (26 +
                ((21.448 -
                            t *
                                (46.815 + t * (0.00059 - t * 0.001813))) /
                        60)) /
            60;
    final epsilon = epsilon0 + 0.00256 * cos(_degToRad(omega));

    final declination = _radToDeg(
      asin(sin(_degToRad(epsilon)) * sin(_degToRad(lambda))),
    );

    final y = tan(_degToRad(epsilon) / 2) * tan(_degToRad(epsilon) / 2);
    final equationOfTime = 4 *
        _radToDeg(
          y * sin(2 * _degToRad(l0)) -
              2 * e * sin(_degToRad(m)) +
              4 * e * y * sin(_degToRad(m)) * cos(2 * _degToRad(l0)) -
              0.5 * y * y * sin(4 * _degToRad(l0)) -
              1.25 * e * e * sin(2 * _degToRad(m)),
        );

    final minutes = dateTimeUtc.hour * 60 +
        dateTimeUtc.minute +
        dateTimeUtc.second / 60 +
        dateTimeUtc.millisecond / 60000;
    final trueSolarTime =
        (minutes + equationOfTime + 4 * longitude).remainder(1440);
    final hourAngle = trueSolarTime / 4 < 0
        ? trueSolarTime / 4 + 180
        : trueSolarTime / 4 - 180;

    final latitudeRad = _degToRad(latitude);
    final declinationRad = _degToRad(declination);
    final hourAngleRad = _degToRad(hourAngle);

    return _radToDeg(
      asin(
        sin(latitudeRad) * sin(declinationRad) +
            cos(latitudeRad) * cos(declinationRad) * cos(hourAngleRad),
      ),
    );
  }

  double julianDay(DateTime utc) {
    final time = utc.toUtc();
    return time.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
  }

  DateTime dateTimeFromJulian(double julian) {
    final milliseconds = ((julian - 2440587.5) * 86400000).round();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  double localSiderealTime({
    required DateTime dateTimeUtc,
    required double longitudeDegrees,
  }) {
    final jd = julianDay(dateTimeUtc);
    final t = (jd - 2451545.0) / 36525.0;
    final gmst = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000.0;
    return _normalizeDegrees(gmst + longitudeDegrees);
  }

  String directionFromAzimuth(double azimuth) {
    if (azimuth >= 337.5 || azimuth < 22.5) {
      return 'North';
    }
    if (azimuth < 67.5) {
      return 'North-East';
    }
    if (azimuth < 112.5) {
      return 'East';
    }
    if (azimuth < 157.5) {
      return 'South-East';
    }
    if (azimuth < 202.5) {
      return 'South';
    }
    if (azimuth < 247.5) {
      return 'South-West';
    }
    if (azimuth < 292.5) {
      return 'West';
    }
    return 'North-West';
  }

  double _scoreTarget({
    required CelestialTarget target,
    required double altitude,
    TelescopeProfile? telescope,
  }) {
    final altitudeScore = altitude <= 0
        ? 0
        : altitude < 15
            ? altitude
            : altitude < 45
                ? 15 + (altitude - 15) * 0.8
                : 39 + (altitude - 45) * 0.35;
    final magnitude = target.visualMagnitude ?? 12;
    final brightnessScore = ((16 - magnitude).clamp(0, 16) / 16) * 25;
    final telescopeScore = telescope == null
        ? 10.0
        : (telescope.apertureMm.clamp(60, 400) / 400) * 20 +
            (telescope.trackingEnabled ? 4 : 0) +
            (telescope.gotoEnabled ? 3 : 0);
    final transitBonus = target.orbitalPeriodDays != null ? 10.0 : 0.0;
    return (altitudeScore + brightnessScore + telescopeScore + transitBonus)
        .clamp(0, 100)
        .toDouble();
  }

  String _visibilityLabel(double altitude) {
    if (altitude <= 0) {
      return 'Below horizon';
    }
    if (altitude < 15) {
      return 'Very low';
    }
    if (altitude < 30) {
      return 'Low altitude';
    }
    if (altitude < 60) {
      return 'Good altitude';
    }
    return 'Excellent altitude';
  }

  String _summaryFor({
    required double altitude,
    required double azimuth,
    required CelestialTarget target,
    required TelescopeProfile? telescope,
    required DateTime? nextTransit,
  }) {
    final buffer = StringBuffer();
    buffer.write('${target.typeLabel} ${altitude > 0 ? 'is' : 'is not'} above the horizon ');
    buffer.write('at ${altitude.toStringAsFixed(1)}° altitude toward ');
    buffer.write('${directionFromAzimuth(azimuth)}.');
    if (nextTransit != null) {
      buffer.write(' Next predicted transit starts near ${nextTransit.toLocal()}.' );
    }
    if (telescope != null && target.visualMagnitude != null) {
      final suitable = telescope.apertureMm >= 80 || target.visualMagnitude! <= 8;
      buffer.write(
        suitable
            ? ' Your telescope profile is suitable for a follow-up session.'
            : ' A larger aperture will improve the chance of a clean observation.',
      );
    }
    return buffer.toString();
  }

  double _normalizeDegrees(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double _degToRad(double value) => value * pi / 180;
  double _radToDeg(double value) => value * 180 / pi;
}

class HorizontalPosition {
  const HorizontalPosition({required this.altitude, required this.azimuth});

  final double altitude;
  final double azimuth;
}
