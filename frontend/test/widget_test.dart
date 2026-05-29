import 'package:caterpro/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CaterPro login opens dashboard', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    await tester.pumpWidget(const CaterProApp());

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Authenticate with Fingerprint'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Authenticate with Fingerprint'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Authenticate with Fingerprint'));
    await tester.pumpAndSettle();

    expect(find.text('Good Morning, Ravi'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });
}
