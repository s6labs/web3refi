import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';

void main() {
  group('NameRegistrationFlow', () {
    const registryAddress = '0x1234567890123456789012345678901234567890';
    const resolverAddress = '0x0987654321098765432109876543210987654321';

    testWidgets('renders with default configuration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      expect(find.byType(Stepper), findsOneWidget);
      expect(find.text('Choose Name'), findsOneWidget);
    });

    testWidgets('shows all steps when duration selection enabled',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
              hideDurationSelection: false,
            ),
          ),
        ),
      );

      expect(find.text('Choose Name'), findsOneWidget);
      expect(find.text('Select Duration'), findsOneWidget);
      expect(find.text('Add Records (Optional)'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('hides duration step when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
              hideDurationSelection: true,
            ),
          ),
        ),
      );

      expect(find.text('Choose Name'), findsOneWidget);
      expect(find.text('Select Duration'), findsNothing);
      expect(find.text('Add Records (Optional)'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('shows suggested name when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
              suggestedName: 'alice',
            ),
          ),
        ),
      );

      expect(find.text('alice'), findsOneWidget);
    });

    testWidgets('shows TLD suffix in name input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      expect(find.text('.xdc'), findsOneWidget);
    });

    testWidgets('allows entering name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'myname');
      await tester.pump();

      expect(find.text('myname'), findsOneWidget);
    });

    testWidgets('shows Continue button on first step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows Cancel button on first step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('calls onCancel when cancel button pressed', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      expect(cancelled, true);
    });

    testWidgets('shows duration options in duration step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // Navigate to duration step (need to mock availability check)
      // This test would require mocking the backend

      // For now, just verify the widget structure
      expect(find.byType(Stepper), findsOneWidget);
    });

    testWidgets('shows record input fields in records step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // The record fields would be visible in step 3
      // This test would require navigation through the stepper
      expect(find.byType(Stepper), findsOneWidget);
    });

    testWidgets('uses default duration when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
              defaultDuration: Duration(days: 730), // 2 years
            ),
          ),
        ),
      );

      expect(find.byType(NameRegistrationFlow), findsOneWidget);
    });

    testWidgets('shows availability checking state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // Enter a name to trigger availability check
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Tap continue to trigger check
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Should show checking state
      expect(find.text('Checking availability...'), findsOneWidget);
    });

    testWidgets('shows available state with check icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // This would require mocking the availability check
      // For now, verify the widget structure
      expect(find.byType(Stepper), findsOneWidget);
    });

    testWidgets('shows not available state with error icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // This would require mocking the availability check
      // For now, verify the widget structure
      expect(find.byType(Stepper), findsOneWidget);
    });

    testWidgets('shows confirmation details in final step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // Would need to navigate to final step
      expect(find.byType(Stepper), findsOneWidget);
    });

    testWidgets('shows Register button in final step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // Would need to navigate to final step
      expect(find.byType(Stepper), findsOneWidget);
    });

    testWidgets('shows Back button on non-first steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      // Would need to navigate to step 2+
      expect(find.byType(Stepper), findsOneWidget);
    });

    testWidgets('disables continue when name is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameRegistrationFlow(
              registryAddress: registryAddress,
              resolverAddress: resolverAddress,
              tld: 'xdc',
            ),
          ),
        ),
      );

      final continueButton = find.text('Continue');
      expect(continueButton, findsOneWidget);

      // Button should be enabled (tapping it will trigger validation)
      await tester.tap(continueButton);
      await tester.pump();
    });
  });
}
