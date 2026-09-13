import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'change_password_screen.dart';
import 'forgot_password_screen.dart';
import '../services/api_service.dart';
import '../services/apple_auth.dart';
import '../services/google_auth.dart';
import '../services/session_service.dart';

/// How the account is signed in to: its password, and the providers attached.
///
/// The rule this screen exists to enforce is that there is always a way back
/// in. The server refuses to remove the last method and says which ones may go,
/// so nothing here has to guess.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  static const Color _bg = Color(0xFF0B0B0D);
  static const Color _cardBg = Color(0xFF1C1C1E);
  static const Color _accent = Color(0xFFFF5722);

  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isBusy = false;
  String _email = '';
  bool _hasPassword = false;
  List<Map<String, dynamic>> _identities = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getSignInMethods();
    if (!mounted) return;

    // Say it failed rather than drawing a guess. An empty list would read as
    // "no password, nothing connected" and offer the wrong buttons.
    if (data == null) {
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _loadFailed = false;
      _email = '${data['email'] ?? SessionService().user?['email'] ?? ''}';
      _hasPassword = data['hasPassword'] == true;
      _identities = (data['identities'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _isLoading = false;
    });
  }

  Map<String, dynamic>? _identityFor(String provider) {
    for (final i in _identities) {
      if ('${i['provider']}' == provider) return i;
    }
    return null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _cardBg,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.hankenGrotesk(color: Colors.white70),
        ),
      ),
    );
  }

  /// Connects a provider to this account.
  ///
  /// Collecting the token is the same as signing in; what happens to it is not.
  /// This one is sent to the link endpoint, which attaches it to whoever is
  /// already signed in rather than looking up an account by address.
  Future<void> _connect(String provider) async {
    setState(() => _isBusy = true);
    try {
      if (provider == 'GOOGLE') {
        final idToken = await GoogleAuth.idToken();
        if (idToken == null) {
          if (mounted) setState(() => _isBusy = false);
          return;
        }
        await ApiService.linkSignInMethod('GOOGLE', idToken);
      } else {
        final credential = await AppleAuth.authorize();
        if (credential == null) {
          if (mounted) setState(() => _isBusy = false);
          return;
        }
        await ApiService.linkSignInMethod(
          'APPLE',
          credential.identityToken,
          authorizationCode: credential.authorizationCode,
        );
      }
      await _load();
      _toast('Connected.');
    } catch (e) {
      _toast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _disconnect(String provider, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Disconnect $label?',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You will no longer be able to sign in with $label. Your account and '
          'everything in it stays exactly as it is.',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep',
                style: GoogleFonts.hankenGrotesk(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Disconnect',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      await ApiService.unlinkSignInMethod(provider);
      await _load();
      _toast('$label disconnected.');
    } catch (e) {
      _toast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Sets a first password on an account that has never had one.
  ///
  /// Routed through the emailed-code flow rather than simply asking for a new
  /// password here. There is no current password to prove this is really them,
  /// and a stolen phone should not be enough to add a permanent way in. Proving
  /// control of the address is.
  Future<void> _setFirstPassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _email,
          // Same mechanics as a reset, different words: nothing has been
          // forgotten here, a first password is being added.
          isSettingFirstPassword: true,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Account & Security',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _loadFailed
          ? _buildLoadError()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeader('EMAIL'),
                    const SizedBox(height: 10),
                    _card(
                      child: ListTile(
                        leading: const Icon(Icons.mail_outline_rounded,
                            color: Colors.white70, size: 21),
                        title: Text(
                          _email,
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Used to sign in and to reset your password',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('PASSWORD'),
                    const SizedBox(height: 10),
                    _card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_outline_rounded,
                            color: Colors.white70, size: 21),
                        title: Text(
                          _hasPassword ? 'Change password' : 'Set a password',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _hasPassword
                              ? 'Signs you out on every other device'
                              : 'You sign in with a connected account. Adding a '
                                  'password gives you a second way in.',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: Colors.white24),
                        onTap: _isBusy
                            ? null
                            : () async {
                                HapticFeedback.lightImpact();
                                if (_hasPassword) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ChangePasswordScreen(),
                                    ),
                                  );
                                  if (mounted) _load();
                                } else {
                                  await _setFirstPassword();
                                }
                              },
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('CONNECTED ACCOUNTS'),
                    const SizedBox(height: 10),
                    _card(
                      child: Column(
                        children: [
                          _providerRow('GOOGLE', 'Google', Icons.g_mobiledata),
                          if (AppleAuth.isSupported) ...[
                            Divider(
                              height: 1,
                              indent: 56,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            _providerRow('APPLE', 'Apple', Icons.apple),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You always keep at least one way to sign in, so the last '
                      'one cannot be removed.',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _providerRow(String provider, String label, IconData icon) {
    final identity = _identityFor(provider);
    final connected = identity != null;
    final canDisconnect = identity?['canDisconnect'] == true;
    final providerEmail = '${identity?['email'] ?? ''}';

    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 23),
      title: Text(
        label,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        connected
            ? (providerEmail.isEmpty ? 'Connected' : providerEmail)
            : 'Not connected',
        style: GoogleFonts.hankenGrotesk(
          color: connected ? Colors.white54 : Colors.white24,
          fontSize: 12,
        ),
      ),
      trailing: TextButton(
        onPressed: _isBusy || (connected && !canDisconnect)
            ? null
            : () {
                HapticFeedback.lightImpact();
                if (connected) {
                  _disconnect(provider, label);
                } else {
                  _connect(provider);
                }
              },
        child: Text(
          connected ? (canDisconnect ? 'Disconnect' : 'Only method') : 'Connect',
          style: GoogleFonts.hankenGrotesk(
            color: !connected
                ? _accent
                : (canDisconnect ? Colors.redAccent : Colors.white24),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white24, size: 40),
            const SizedBox(height: 14),
            Text(
              'Could not load your sign-in methods.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white70,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _load();
              },
              child: Text(
                'Try again',
                style: GoogleFonts.hankenGrotesk(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}
