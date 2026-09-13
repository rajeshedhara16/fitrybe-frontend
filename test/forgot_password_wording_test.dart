import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/screens/forgot_password_screen.dart';

/// The screen serves two entry points with identical mechanics and different
/// words. Someone who signed up with Google never had a password, so telling
/// them not to worry about having forgotten one sends them back to check they
/// tapped the right thing.
void main() {
  Future<void> pump(WidgetTester tester, {required bool firstPassword}) async {
    await tester.pumpWidget(MaterialApp(
      home: ForgotPasswordScreen(
        initialEmail: 'athlete@example.com',
        isSettingFirstPassword: firstPassword,
      ),
    ));
    await tester.pump();
  }

  /// Matches across the RichText spans the headline is built from.
  bool showsText(String needle) {
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .join(' ');
    final spans = find
        .byType(RichText)
        .evaluate()
        .map((e) => (e.widget as RichText).text.toPlainText())
        .join(' ');
    return '$texts $spans'.contains(needle);
  }

  testWidgets('reached from sign-in, it talks about a forgotten password',
      (tester) async {
    await pump(tester, firstPassword: false);

    expect(showsText('FORGOT'), isTrue);
    expect(showsText('ACCOUNT RECOVERY'), isTrue);
    expect(showsText('Send Reset Code'), isTrue);
    expect(showsText('SET A'), isFalse);
  });

  testWidgets('reached from settings, it talks about setting a first one',
      (tester) async {
    await pump(tester, firstPassword: true);

    expect(showsText('SET A'), isTrue);
    expect(showsText('PASSWORD'), isTrue);
    expect(showsText('ACCOUNT SECURITY'), isTrue);
    expect(showsText('Send Code'), isTrue);

    // The wrong-turn wording specifically.
    expect(showsText('Forgot'), isFalse);
    expect(showsText('worry'), isFalse);
  });

  testWidgets('the default is the forgotten-password wording', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.pump();

    expect(showsText('FORGOT'), isTrue);
  });
}
