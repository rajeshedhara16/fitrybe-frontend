import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// One completed Apple authorization.
///
/// The name is separate from the token on purpose. Apple does not put it in the
/// identity token, and hands it over exactly once — on the very first
/// authorization for this app, and never again, not even after a reinstall.
class AppleCredential {
  const AppleCredential({
    required this.identityToken,
    this.firstName,
    this.lastName,
  });

  /// The signed token the backend verifies. The only part that proves anything.
  final String identityToken;

  /// Cosmetic, and usually null. Only present on a first authorization.
  final String? firstName;
  final String? lastName;
}

/// Obtains an Apple identity token for the API to verify.
///
/// As with Google, the app proves nothing here. It collects the token Apple
/// signed and passes it on; the backend checks the signature against Apple's
/// published keys and reads the identity out of the verified token itself.
class AppleAuth {
  const AppleAuth._();

  /// Whether to offer the button at all.
  ///
  /// Apple platforms only. On Android the same sign-in exists, but only as a
  /// browser redirect that needs a Services ID and a server callback bouncing
  /// back through a deep link — a different flow, not wired up here. Showing a
  /// button that cannot work would be worse than showing none.
  ///
  /// The iOS deployment target is 13.0, which is the version Sign in with Apple
  /// arrived in, so no runtime version check is needed on top of this.
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Runs the Apple sheet and returns the credential, or null if the athlete
  /// backs out. Cancelling is not a failure and shows nothing.
  static Future<AppleCredential?> authorize() async {
    if (!isSupported) {
      throw Exception('Sign in with Apple is not available on this device.');
    }

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('AppleAuth authorization failed: ${e.code} ${e.message}');
      throw Exception(_messageFor(e.code));
    } on SignInWithAppleNotSupportedException catch (e) {
      debugPrint('AppleAuth unsupported: ${e.message}');
      throw Exception('Sign in with Apple is not available on this device.');
    }

    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      // Nothing to verify, so there is nothing to sign in with. Usually the
      // Sign in with Apple capability missing from the build.
      throw Exception(
        'Apple did not return an identity token. Check that the Sign in with '
        'Apple capability is enabled for this app.',
      );
    }

    return AppleCredential(
      identityToken: token,
      firstName: _trimToNull(credential.givenName),
      lastName: _trimToNull(credential.familyName),
    );
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _messageFor(AuthorizationErrorCode code) {
    return switch (code) {
      AuthorizationErrorCode.notInteractive ||
      AuthorizationErrorCode.notHandled =>
        'Sign in with Apple could not be shown. Try again.',
      AuthorizationErrorCode.invalidResponse =>
        'Apple sent back a response we could not read. Try again.',
      _ => 'Could not sign in with Apple. Try again.',
    };
  }
}
