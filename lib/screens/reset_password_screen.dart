import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

/// The token from a reset link (".../reset-password?token=abc") or the bare code itself.
String? resetTokenFrom(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final fromLink = Uri.tryParse(value)?.queryParameters['token'];
  if (fromLink != null && fromLink.isNotEmpty) return fromLink;
  return value.contains(RegExp(r'[\s/?=]')) ? null : value;
}

/// POST /api/auth/reset-password {token, password} — mirrors pages/auth/ResetPassword.jsx.
/// The emailed link normally opens the website; here the same link can be pasted instead.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _link = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.api.post(
        '/api/auth/reset-password',
        body: {'token': resetTokenFrom(_link.text), 'password': _password.text},
        auth: false,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      // Expired or already-used links come back as a 400 with the server's explanation.
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: TL.sand50,
      appBar: AppBar(backgroundColor: TL.sand50, scrolledUnderElevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: TidelineWordmark(size: 22)),
                  const SizedBox(height: 24),
                  TLCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(24),
                    child: _done ? _success(text) : _formBody(text),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success(TextTheme text) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.check_circle_outline, color: TL.kelp600, size: 40),
      const SizedBox(height: 12),
      Text('Password changed', style: text.headlineSmall),
      const SizedBox(height: 6),
      Text('Sign in with your new password.', style: text.bodyMedium),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Back to sign in'),
      ),
    ],
  );

  Widget _formBody(TextTheme text) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a new password', style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Paste the link from the reset email. Links work once and expire after 30 minutes.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _link,
          decoration: const InputDecoration(labelText: 'Reset link or code'),
          keyboardType: TextInputType.url,
          autocorrect: false,
          validator: (v) => resetTokenFrom(v ?? '') == null
              ? 'Paste the whole link from the email.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'New password',
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) =>
              (v ?? '').length < 8 ? 'Use at least 8 characters.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirm,
          obscureText: _obscure,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
          validator: (v) =>
              v != _password.text ? 'The passwords do not match.' : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          NoticeBanner(_error!, tone: BannerTone.error),
        ],
        const SizedBox(height: 20),
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
              : const Text('Change password'),
        ),
      ],
    ),
  );
}
