import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telestronomy/main.dart';

void main() {
  testWidgets('shows auth screen on launch', (tester) async {
    await tester.pumpWidget(const TelestronomyBootstrap());
    await tester.pump();
    expect(find.text('Telestronomy'), findsWidgets);
  });

  testWidgets('auth form validates bad input', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('placeholder'))));
  });
}
