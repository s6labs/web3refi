import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';

void main() {
  group('NameDisplay', () {
    const testAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';

    testWidgets('renders with default configuration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(address: testAddress),
          ),
        ),
      );

      expect(find.byType(NameDisplay), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(address: testAddress),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Resolving...'), findsOneWidget);
    });

    testWidgets('displays address in row layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              layout: NameDisplayLayout.row,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.textContaining('0x742d'), findsOneWidget);
    });

    testWidgets('displays address in column layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              layout: NameDisplayLayout.column,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.textContaining('0x742d'), findsOneWidget);
    });

    testWidgets('displays address in card layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              layout: NameDisplayLayout.card,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
      expect(find.textContaining('0x742d'), findsOneWidget);
    });

    testWidgets('shows avatar when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              showAvatar: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('hides avatar when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              showAvatar: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('displays pre-resolved name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              name: 'alice.xdc',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('alice.xdc'), findsOneWidget);
    });

    testWidgets('shows copy button when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              enableCopy: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('hides copy button when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              enableCopy: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.copy), findsNothing);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, true);
    });

    testWidgets('uses custom avatar size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              avatarSize: 60,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 30); // radius is half of size
    });

    testWidgets('uses custom name style', (tester) async {
      const customStyle = TextStyle(fontSize: 24, color: Colors.red);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              name: 'alice.xdc',
              nameStyle: customStyle,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final nameText = tester.widget<Text>(
        find.text('alice.xdc'),
      );
      expect(nameText.style?.fontSize, 24);
      expect(nameText.style?.color, Colors.red);
    });

    testWidgets('shows metadata in card layout when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(
              address: testAddress,
              layout: NameDisplayLayout.card,
              showMetadata: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('shortens address correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(address: testAddress),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Should show shortened address: 0x742d...0bEb
      expect(find.textContaining('0x742d'), findsOneWidget);
      expect(find.textContaining('0bEb'), findsOneWidget);
    });

    testWidgets('updates when address changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(address: testAddress),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      const newAddress = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NameDisplay(address: newAddress),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.textContaining('0xd8dA'), findsOneWidget);
    });
  });
}
