import 'package:flutter_test/flutter_test.dart';
import 'package:telestronomy/src/validators.dart';

void main() {
  group('Validators', () {
    test('validates email shape', () {
      expect(Validators.email('astro@example.com'), isNull);
      expect(Validators.email('broken-email'), isNotNull);
    });

    test('requires stronger passwords', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('StrongPass1'), isNull);
    });

    test('checks coordinate ranges', () {
      expect(Validators.latitude('120'), isNotNull);
      expect(Validators.longitude('-74.0'), isNull);
    });
  });
}
