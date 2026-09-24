import 'package:flutter_test/flutter_test.dart';
import 'package:telestronomy/src/astronomy_engine.dart';
import 'package:telestronomy/src/models.dart';

void main() {
  const engine = AstronomyEngine();

  test('maps azimuth into cardinal direction', () {
    expect(engine.directionFromAzimuth(10), 'North');
    expect(engine.directionFromAzimuth(90), 'East');
    expect(engine.directionFromAzimuth(225), 'South-West');
  });

  test('predicts next transit after a given time', () {
    const target = CelestialTarget(
      id: 'exo:test',
      name: 'Test b',
      type: TargetType.exoplanet,
      catalog: 'Unit Test',
      raDegrees: 0,
      decDegrees: 0,
      orbitalPeriodDays: 2,
      transitMidpointJulian: 2460000,
    );

    final nextTransit = engine.predictNextTransit(
      target,
      DateTime.utc(2023, 2, 25),
    );

    expect(nextTransit, isNotNull);
    expect(nextTransit!.isAfter(DateTime.utc(2023, 2, 25)), isTrue);
  });

  test('classifies solar darkness', () {
    final snapshot = engine.solarSnapshot(
      ObservationContext(
        latitude: 51.5,
        longitude: -0.1,
        dateTime: DateTime.utc(2026, 1, 1, 0),
      ),
    );

    expect(snapshot.label, isNotEmpty);
  });
}
