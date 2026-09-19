import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:credify_frontend/theme/credify_theme.dart';
import 'package:credify_frontend/widgets/credify_shell_widgets.dart';

/// The slide is the only way from Consent into the rest of the app, so its
/// gesture handling is covered directly rather than only through the UI.
void main() {
  Future<void> pumpSlider(
    WidgetTester tester, {
    required VoidCallback onAuthorized,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CredifyTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: SlideToAuthorize(
                label: 'Slide to authorise',
                doneLabel: 'Consent granted',
                onAuthorized: onAuthorized,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a full drag authorises and swaps to the done state',
      (tester) async {
    var authorised = 0;
    await pumpSlider(tester, onAuthorized: () => authorised++);

    expect(find.text('Slide to authorise'), findsOneWidget);

    // Track is 400 wide, thumb 56 -> maxDrag 344. Drag well past the
    // three-quarter threshold.
    await tester.drag(
      find.byIcon(Icons.arrow_forward_rounded),
      const Offset(340, 0),
    );
    await tester.pumpAndSettle();

    expect(authorised, 1);
    expect(find.text('Consent granted'), findsOneWidget);
    expect(find.text('Slide to authorise'), findsNothing);
  });

  testWidgets('a short drag springs back without authorising', (tester) async {
    var authorised = 0;
    await pumpSlider(tester, onAuthorized: () => authorised++);

    // Well under the 75% threshold.
    await tester.drag(
      find.byIcon(Icons.arrow_forward_rounded),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();

    expect(authorised, 0);
    expect(find.text('Slide to authorise'), findsOneWidget);
  });

  testWidgets('authorises exactly once even if dragged again', (tester) async {
    var authorised = 0;
    await pumpSlider(tester, onAuthorized: () => authorised++);

    await tester.drag(
      find.byIcon(Icons.arrow_forward_rounded),
      const Offset(340, 0),
    );
    await tester.pumpAndSettle();
    expect(authorised, 1);

    // The thumb is gone in the done state, so there is nothing left to drag.
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    expect(authorised, 1);
  });
}
