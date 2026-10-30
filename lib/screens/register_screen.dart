import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/api_client.dart';
import '../core/format.dart';
import '../core/uploads.dart';
import '../widgets/common.dart';
import '../widgets/upload_picker.dart';

const _roles = [
  ('CITIZEN', 'Community member', 'Report sites and join cleanups.'),
  (
    'DIVER',
    'Volunteer diver',
    'Underwater cleanups. Needs a diving certificate and approval.',
  ),
  (
    'ORGANIZATION',
    'Organisation',
    'Post volunteer opportunities. Needs approval.',
  ),
  (
    'AUTHORITY',
    'Government officer',
    'Review verified reports. Needs proof of appointment and approval.',
  ),
  (
    'ADMIN',
    'Administrator',
    'Moderate reports and accounts. Needs proof of appointment and approval.',
  ),
];

const _official = ['AUTHORITY', 'ADMIN'];

/// Adds http:// when the user typed a bare domain (same as withScheme in Register.jsx).
String withScheme(String url) {
  final t = url.trim();
  if (t.isEmpty) return t;
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(t)
      ? t
      : 'https://$t';
}

/// POST /api/auth/register. Mirrors frontend/src/pages/auth/Register.jsx.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.auth,
    this.pickFiles = pickDocuments,
  });
  final AuthController auth;

  /// Opens the file chooser; replaceable so the upload flow can be tested.
  final Future<List<PickedUpload>> Function() pickFiles;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _nic = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _orgName = TextEditingController();
  final _website = TextEditingController();

  String _role = 'CITIZEN';
  String? _province;
  String? _certification;
  String? _orgType;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _docsError;
  final _docsKey = GlobalKey();
  final List<PickedUpload> _certificates = [];
  final List<PickedUpload> _licences = [];

  bool get _needsDocuments => _role == 'DIVER' || _official.contains(_role);

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _email,
      _nic,
      _password,
      _phone,
      _city,
      _orgName,
      _website,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _blank(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    if (_needsDocuments && _certificates.isEmpty) {
      setState(
        () => _docsError = _role == 'DIVER'
            ? 'Attach at least one diving certificate so an administrator can verify you.'
            : 'Attach proof of your appointment, such as a staff ID or appointment letter.',
      );
      // The upload section is far down the form; bring it into view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _docsKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.3);
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _docsError = null;
    });
    try {
      // Field names follow AuthDtos.RegisterRequest.
      final result = await widget.auth.register(
        {
          'firstName': _first.text.trim(),
          'lastName': _last.text.trim(),
          'email': _email.text.trim(),
          'nic': _nic.text.trim(),
          'password': _password.text,
          'phone': _blank(_phone),
          'role': _role,
          'province': _province,
          'city': _blank(_city),
          'certificationLevel': _role == 'DIVER' ? _certification : null,
          'organizationName':
              (_role == 'ORGANIZATION' || _official.contains(_role))
              ? _blank(_orgName)
              : null,
          'organizationType': _role == 'ORGANIZATION' ? _orgType : null,
          'websiteUrl': _role == 'ORGANIZATION'
              ? withScheme(_website.text)
              : null,
        },
        certificates: [
          for (final f in _certificates) await uploadPart('certificates', f),
        ],
        licences: [
          if (_role == 'DIVER')
            for (final f in _licences) await uploadPart('licences', f),
        ],
      );
      if (!mounted) return;
      if (result.token != null) {
        // Signed in: the auth gate swaps this stack for the app.
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Registration received'),
            content: const Text(
              'An administrator will check your details. You will be able to sign in once your account is approved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read one of the selected files.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            // On a wide browser window keep the form a readable column, centred.
            padding: EdgeInsets.symmetric(
              vertical: 16,
              horizontal: math.max(
                16,
                (MediaQuery.sizeOf(context).width - 600) / 2,
              ),
            ),
            children: [
              if (_error != null) ...[
                NoticeBanner(_error!),
                const SizedBox(height: 16),
              ],
              Text('I am joining as', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label, _) in _roles)
                    ChoiceChip(
                      label: Text(label),
                      selected: _role == value,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                              _role = value;
                              _docsError = null; // belongs to the previous role
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _roles.firstWhere((r) => r.$1 == _role).$3,
                style: text.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _first,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: (v) => validateName(v, 'first name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _last,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (v) => validateName(v, 'last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nic,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'NIC number',
                  helperText: '12 digits, or 9 digits and V/X',
                ),
                validator: validateNic,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText:
                      'At least 8 characters, with a letter and a number',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: '0771234567',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _province,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Province (optional)',
                ),
                items: [
                  for (final p in provinces)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _province = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _city,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Town or city (optional)',
                ),
              ),
              if (_role == 'DIVER') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _certification,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Certification level',
                  ),
                  items: [
                    for (final e in certificationLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _certification = v),
                  validator: (v) =>
                      v == null ? 'Choose your certification level.' : null,
                ),
              ],
              if (_role == 'ORGANIZATION' || _official.contains(_role)) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _orgName,
                  enabled: !_busy,
                  maxLength: 150,
                  decoration: InputDecoration(
                    labelText: _role == 'ORGANIZATION'
                        ? 'Organisation name'
                        : 'Department or agency',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (_role == 'ORGANIZATION'
                            ? "Enter your organisation's name."
                            : 'Enter the department or agency you work for.')
                      : null,
                ),
              ],
              if (_role == 'ORGANIZATION') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _orgType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Organisation type',
                  ),
                  items: [
                    for (final e in organizationLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _orgType = v),
                  validator: (v) =>
                      v == null ? 'Choose an organisation type.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _website,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                    helperText:
                        'An administrator checks this before approving you',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Enter your organisation's website."
                      : null,
                ),
              ],
              if (_needsDocuments) ...[
                const SizedBox(height: 16),
                UploadPicker(
                  key: _docsKey,
                  label: _role == 'DIVER'
                      ? 'Diving certificates'
                      : 'Proof of appointment',
                  error: _docsError,
                  onChanged: () => setState(() => _docsError = null),
                  hint: 'PDF, JPG or PNG, up to 5 MB each (max 5).',
                  files: _certificates,
                  pick: widget.pickFiles,
                  check: checkDocument,
                  max: 5,
                  enabled: !_busy,
                ),
              ],
              if (_role == 'DIVER') ...[
                const SizedBox(height: 8),
                UploadPicker(
                  label: 'Licences (optional)',
                  hint: 'PDF, JPG or PNG, up to 5 MB each.',
                  files: _licences,
                  pick: widget.pickFiles,
                  check: checkDocument,
                  max: 5,
                  enabled: !_busy,
                ),
              ],
              const SizedBox(height: 24),
              BusyButton(
                label: 'Create account',
                icon: Icons.person_add_alt,
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('I already have an account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
