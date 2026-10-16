import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war/main.dart';

void main() {
  testWidgets('shows sign-in form and can switch to account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.byKey(const Key('nameField')), findsNothing);

    final createAccountLink = find.text('New here? Create an account');
    await tester.ensureVisible(createAccountLink);
    await tester.pumpAndSettle();
    await tester.tap(createAccountLink);
    await tester.pump();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
    expect(find.byKey(const Key('nameField')), findsOneWidget);
  });

  testWidgets('validates required sign-in fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('product form includes photo and warranty sheet uploads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddProductPage()));

    await tester.tap(find.text('Mobile'));
    await tester.pump();
    await tester.tap(find.text('Continue  →'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'My phone');
    await tester.tap(find.text('Continue  →'));
    await tester.pumpAndSettle();

    expect(find.text('Product photo'), findsOneWidget);
    expect(find.text('Warranty sheet'), findsOneWidget);
    expect(find.text('Save to Wallet'), findsOneWidget);
    expect(find.text('Skip photos and warranty sheet'), findsOneWidget);
  });
}
