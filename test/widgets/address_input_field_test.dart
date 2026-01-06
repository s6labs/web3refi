import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';

void main() {
  group('AddressInputField', () {
    testWidgets('renders with default configuration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Address or Name'), findsOneWidget);
    });

    testWidgets('renders with custom label and hint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(
              label: 'Recipient',
              hint: 'Enter recipient address',
            ),
          ),
        ),
      );

      expect(find.text('Recipient'), findsOneWidget);
      expect(find.text('Enter recipient address'), findsOneWidget);
    });

    testWidgets('shows loading indicator while resolving', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(),
          ),
        ),
      );

      // Enter text to trigger resolution
      await tester.enterText(find.byType(TextField), 'vitalik.eth');
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onAddressResolved when valid address entered',
        (tester) async {
      String? resolvedAddress;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressInputField(
              onAddressResolved: (address) => resolvedAddress = address,
            ),
          ),
        ),
      );

      // Enter valid address
      const testAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';
      await tester.enterText(find.byType(TextField), testAddress);
      await tester.pump(const Duration(milliseconds: 600));

      expect(resolvedAddress, testAddress);
    });

    testWidgets('shows resolved address when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(
              showResolvedAddress: true,
            ),
          ),
        ),
      );

      // Enter valid address
      await tester.enterText(
        find.byType(TextField),
        '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // Should show resolved address container
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('hides resolved address when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(
              showResolvedAddress: false,
            ),
          ),
        ),
      );

      // Enter valid address
      await tester.enterText(
        find.byType(TextField),
        '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // Should not show resolved address container
      expect(find.text('Resolved:'), findsNothing);
    });

    testWidgets('shows error icon for invalid input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(),
          ),
        ),
      );

      // Enter invalid input
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // Should show error icon
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('clears state when input is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(),
          ),
        ),
      );

      // Enter text
      await tester.enterText(
        find.byType(TextField),
        '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Clear text
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Should not show any icons
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.error), findsNothing);
    });

    testWidgets('respects custom resolution delay', (tester) async {
      String? resolvedAddress;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressInputField(
              resolutionDelay: const Duration(seconds: 1),
              onAddressResolved: (address) => resolvedAddress = address,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
      );

      // Should not resolve before delay
      await tester.pump(const Duration(milliseconds: 500));
      expect(resolvedAddress, isNull);

      // Should resolve after delay
      await tester.pump(const Duration(milliseconds: 600));
      expect(resolvedAddress, isNotNull);
    });

    testWidgets('shows copy button when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddressInputField(
              enableCopy: true,
              showResolvedAddress: true,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('calls onChanged callback', (tester) async {
      String? changedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressInputField(
              onChanged: (text) => changedText = text,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      expect(changedText, 'test');
    });
  });
}
