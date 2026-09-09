import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Obtains a Google ID token for the API to verify.
///
/// The app proves nothing here. All it does is collect the signed token Google
/// mints and hand it to the backend, which checks the signature against
/// Google's own keys before it will issue a Fitrybe session. Nothing this class
/// reads — the email, the name — is trusted by the server; it reads those out
/// of the verified token itself.
class GoogleAuth {
  const GoogleAuth._();

  // ── Paste your client ids here, once ──────────────────────────────────────
  //
  // These belong in source. An OAuth client id is not a credential: it ships
  // inside every copy of the app and anyone can read it out of the binary. What
  // stops it being useful to someone else is that the backend only accepts ID
  // tokens minted for these clients, and that Google only mints them for a
  // build signed with the certificate registered against them.

  /// The **Web** OAuth client id from the Google Cloud console.
  ///
  /// Required on Android: it is the audience Google stamps into the ID token,
  /// and without it no ID token comes back at all. Must match the backend's
  /// `GOOGLE_WEB_CLIENT_ID`, or every sign-in is rejected as the wrong audience.
  static const String _defaultWebClientId =
      '600396189230-8nsmkakbn37iqs7p1ah2j5oodfmud1h1.apps.googleusercontent.com';

  /// The **iOS** OAuth client id.
  ///
  /// Left empty on purpose: iOS needs its reversed form as a URL scheme in
  /// Info.plist regardless, so the plugin reads `GIDClientID` from there and
  /// the id lives in exactly one place instead of two that can disagree.
  static const String _defaultIosClientId = '';

  // ──────────────────────────────────────────────────────────────────────────

  /// Both can be overridden per build, for pointing a flavour at a different
  /// Google project, but neither has to be. This mirrors how `ApiClient`
  /// resolves its host: a working default in source, a `--dart-define` for when
  /// you want something else.
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  static const String _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: _defaultIosClientId,
  );

  /// Whether the web client id above has actually been filled in.
  static bool get isConfigured =>
      _serverClientId.isNotEmpty && !_serverClientId.startsWith('REPLACE_WITH');

  /// Memoized so initialize runs exactly once, as the plugin requires, without
  /// app startup having to wait on it. A misconfigured Google setup then fails
  /// at the button rather than on the splash screen.
  static Future<void>? _initialization;

  static Future<void> _ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance.initialize(
      clientId: _iosClientId.isEmpty ? null : _iosClientId,
      serverClientId: _serverClientId,
    );
  }

  /// Signs in and returns the ID token, or null when the athlete backs out.
  ///
  /// Cancelling is not a failure. It arrives as an exception from the plugin
  /// and is turned into null here so the caller can simply do nothing, leaving
  /// the sign-in screen exactly as it was.
  static Future<String?> idToken() async {
    if (!isConfigured) {
      throw Exception(
        'Google sign-in is not set up yet. Paste your web client id into '
        '_defaultWebClientId in lib/services/google_auth.dart.',
      );
    }

    await _ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception('Google sign-in is not available on this device.');
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('GoogleAuth authenticate failed: ${e.code} ${e.description}');
      throw Exception(_messageFor(e));
    }

    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      // Almost always a missing or mismatched server client id: Google signed
      // the user in but had no audience to mint an ID token for.
      throw Exception(
        'Google did not return an ID token. Check that the web client id '
        'matches the one the server verifies against.',
      );
    }
    return token;
  }

  /// Clears the Google session so the next sign-in asks which account to use.
  /// Failing here must not block signing out of Fitrybe itself.
  static Future<void> signOut() async {
    if (_initialization == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('GoogleAuth signOut error: $e');
    }
  }

  static String _messageFor(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in is not set up correctly for this app.',
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in was interrupted. Try again.',
      _ => 'Could not sign in with Google. Try again.',
    };
  }
}
