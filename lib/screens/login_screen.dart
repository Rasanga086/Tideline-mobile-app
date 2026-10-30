import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/api_client.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../core/theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.login(_email.text.trim(), _password.text, _remember);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ACCOUNT_PENDING' || e.code == 'ACCOUNT_REJECTED') {
        await _showReviewDialog(e);
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      // Anything else (e.g. an unexpected response) must still be reported.
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initial: _email.text.trim()),
    );
    if (email == null || !mounted) return;
    try {
      await widget.auth.forgotPassword(email);
      if (mounted) {
        showToast(
          context,
          'If that email has an account, a reset link is on its way.',
        );
        _openReset();
      }
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    }
  }

  /// The emailed link opens the website; the app accepts the same link (or its code) too.
  void _openReset() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ResetPasswordScreen(auth: widget.auth)),
  );

  Future<void> _showReviewDialog(ApiException e) {
    final rejected = e.code == 'ACCOUNT_REJECTED';
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          rejected
              ? "Your registration wasn't approved"
              : 'Your account is pending verification',
        ),
        content: Text(
          rejected
              ? e.message
              : "An administrator is checking your certificates or website. You'll be able to sign in once it's approved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(rejected ? 'Close' : 'Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pushed = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: TL.sand50,
      // Opened from a guest screen: offer a way back without signing in.
      appBar: pushed
          ? AppBar(backgroundColor: TL.sand50, scrolledUnderElevation: 0)
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: TidelineWordmark(size: 22)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(TL.radiusLg),
                      boxShadow: TL.cardShadow,
                    ),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Sign in', style: text.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Report and track coastal cleanup activity near you.',
                            style: text.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TL.coral100,
                                borderRadius: BorderRadius.circular(
                                  TL.radiusMd,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Could not sign in',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: TL.coral700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: TL.coral700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.lk',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your password'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _remember,
                                onChanged: (v) =>
                                    setState(() => _remember = v ?? false),
                              ),
                              const Text('Remember me'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                          const SizedBox(height: 12),
                          // Existing accounts the server chose to offer; tapping one fills the email only.
                          _DemoAccountsSection(
                            auth: widget.auth,
                            enabled: !_busy,
                            onUse: (email) =>
                                setState(() => _email.text = email),
                          ),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _busy ? null : _forgotPassword,
                                child: const Text('Forgot password?'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RegisterScreen(auth: widget.auth),
                                        ),
                                      ),
                                child: const Text('Create account'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    child: TextButton(
                      onPressed: _busy ? null : _openReset,
                      child: const Text('I have a reset link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initial});
  final String initial;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final _email = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset your password'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email'),
        validator: validateEmail,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _email.text.trim());
          }
        },
        child: const Text('Send link'),
      ),
    ],
  );
}

/// "Demo Accounts": GET /api/auth/demo-accounts, requested once when the sign-in screen opens.
/// It lists role and email for accounts that already exist and that the server was told to offer.
/// "Use account" fills in the email field only; the password is never shown or filled in. A failed
/// request shows a small note and leaves the sign-in form fully usable.
class _DemoAccountsSection extends StatefulWidget {
  const _DemoAccountsSection({
    required this.auth,
    required this.onUse,
    this.enabled = true,
  });
  final AuthController auth;
  final void Function(String email) onUse;
  final bool enabled;

  @override
  State<_DemoAccountsSection> createState() => _DemoAccountsSectionState();
}

class _DemoAccountsSectionState extends State<_DemoAccountsSection> {
  late Future<List<DemoAccount>> _accounts = _load();

  Future<List<DemoAccount>> _load() async {
    final json = await widget.auth.api.get(
      '/api/auth/demo-accounts',
      auth: false,
    );
    if (json is! List) return const [];
    return [for (final row in json) ?DemoAccount.tryParse(row)];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Demo Accounts', style: text.titleMedium),
        const SizedBox(height: 6),
        FutureBuilder<List<DemoAccount>>(
          future: _accounts,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Loading demo accounts…',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              );
            }
            if (snap.hasError) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      "Demo accounts couldn't be loaded. You can still sign in.",
                      style: text.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _accounts = _load();
                    }),
                    child: const Text('Try again'),
                  ),
                ],
              );
            }
            final accounts = snap.data ?? const <DemoAccount>[];
            if (accounts.isEmpty) {
              return Text('No demo accounts available.', style: text.bodySmall);
            }
            return Column(
              children: [
                for (final account in accounts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(account.roleText, style: text.bodySmall),
                              Text(
                                account.email,
                                style: text.bodyMedium?.copyWith(
                                  color: TL.textStrong,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: widget.enabled
                              ? () => widget.onUse(account.email)
                              : null,
                          child: const Text('Use account'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
