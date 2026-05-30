import 'package:caterpro/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('CaterPro login renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    await tester.pumpWidget(const CaterProApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Authenticate with Fingerprint'), findsOneWidget);
  });
}
