import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

const _statuses = [
  ('PENDING_REVIEW', 'Waiting'),
  ('APPROVED', 'Approved'),
  ('REJECTED', 'Rejected'),
];

/// Administrators only: divers, organisations and officials waiting for verification.
/// GET /api/admin/verifications?status=, POST /api/admin/verifications/{id} {approved, reason}
/// (a reason is required to reject), and GET /api/admin/documents/{id} for uploaded files.
/// Mirrors pages/authority/Verifications.jsx.
class AdminVerificationsScreen extends StatefulWidget {
  const AdminVerificationsScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AdminVerificationsScreen> createState() =>
      _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> {
  String _status = 'PENDING_REVIEW';
  late Future<List<AccountReview>> _future = _load();
  int? _busyId;

  Future<List<AccountReview>> _load() async =>
      (await widget.auth.api.get(
                '/api/admin/verifications',
                query: {'status': _status},
              )
              as List)
          .map((e) => AccountReview.fromJson(e as Map<String, dynamic>))
          .toList();

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _review(AccountReview a, bool approved) async {
    if (_busyId != null) return;
    String? reason;
    if (!approved) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _RejectDialog(name: a.fullName),
      );
      if (reason == null) return;
    } else {
      final ok = await confirmDialog(
        context,
        title: 'Approve ${a.fullName}?',
        message:
            'They will be able to sign in and use their account right away.',
        confirmLabel: 'Approve',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() {
      _busyId = a.id;
    });
    try {
      await widget.auth.api.post(
        '/api/admin/verifications/${a.id}',
        body: {'approved': approved, 'reason': reason},
      );
      if (mounted) {
        showToast(
          context,
          approved ? 'Account approved.' : 'Registration rejected.',
        );
        _reload();
      }
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) {
        setState(() {
          _busyId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          try {
            await _future;
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                for (final (value, label) in _statuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) {
                        _status = value;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AsyncView<List<AccountReview>>(
              future: _future,
              onRetry: _reload,
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.badge_outlined,
              emptyMessage: 'Nobody here — no accounts in this state.',
              builder: (context, list) => Column(
                children: [
                  for (final a in list)
                    TLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.fullName,
                                  style: text.titleMedium,
                                ),
                              ),
                              StatusPill(
                                roleLabels[a.role] ?? a.role,
                                fg: TL.tide700,
                                bg: TL.tide100,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                                  a.email,
                                  a.phone,
                                  [a.city, a.province]
                                      .where((s) => s != null && s.isNotEmpty)
                                      .join(', '),
                                ]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: text.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          if (a.certificationLevel != null)
                            Text(
                              'Certification: ${certificationLabels[a.certificationLevel] ?? a.certificationLevel}'
                              '${a.experienceYears != null ? ' · ${a.experienceYears} yrs' : ''}',
                            ),
                          if (a.organizationName != null)
                            Text(
                              '${organizationLabels[a.organizationType] ?? 'Organisation'}: ${a.organizationName}',
                            ),
                          if (a.websiteUrl != null)
                            Text('Website: ${a.websiteUrl}'),
                          if (a.reviewNote != null && a.reviewNote!.isNotEmpty)
                            Text(
                              'Review note: ${a.reviewNote}',
                              style: text.bodySmall,
                            ),
                          if (a.documents.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Documents', style: text.labelLarge),
                            for (final (id, name, type) in a.documents)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  type.startsWith('image/')
                                      ? Icons.image_outlined
                                      : Icons.picture_as_pdf_outlined,
                                ),
                                title: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: type.startsWith('image/')
                                    ? const Icon(Icons.open_in_full, size: 18)
                                    : const Text('View on website'),
                                onTap: type.startsWith('image/')
                                    ? () => _viewDocument(id, name)
                                    : null,
                              ),
                          ],
                          if (a.accountStatus != 'APPROVED') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _busyId == a.id
                                        ? null
                                        : () => _review(a, true),
                                    child: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      foregroundColor: TL.coral700,
                                    ),
                                    onPressed:
                                        _busyId == a.id ||
                                            a.accountStatus == 'REJECTED'
                                        ? null
                                        : () => _review(a, false),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Documents are private: the image request carries the administrator's session token.
  void _viewDocument(int id, String name) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(12), child: Text(name)),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  '${AppConfig.apiBaseUrl}/api/admin/documents/$id',
                  headers: widget.auth.api.authHeaders,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Could not load this document.'),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.name});
  final String name;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Reject ${widget.name}?'),
    content: TextField(
      controller: _reason,
      maxLength: 500,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Reason',
        helperText: 'The applicant sees this when they try to sign in',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(100, 44),
          backgroundColor: TL.coral600,
        ),
        onPressed: _reason.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _reason.text.trim()),
        child: const Text('Reject'),
      ),
    ],
  );
}
