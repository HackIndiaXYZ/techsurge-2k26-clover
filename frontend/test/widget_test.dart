import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clover_frontend/main.dart';
import 'package:clover_frontend/mock_backend.dart';

void main() {
  testWidgets('App starts without errors', (WidgetTester tester) async {
    await tester.pumpWidget(CloverApp(service: MockBackend()));
    await tester.pumpAndSettle();
    // Disclaimer banner should be visible
    expect(find.textContaining('Research prototype'), findsOneWidget);
    // Bottom nav should have 4 tabs
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
