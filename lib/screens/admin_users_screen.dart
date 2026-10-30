import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'user_profile_screen.dart';

/// Administrators only: GET /api/admin/users?query= and POST /api/admin/users/{id}/suspension.
/// Mirrors pages/authority/Users.jsx.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  late Future<List<AdminUser>> _future = _load();
  int? _busyId;

  Future<List<AdminUser>> _load() async =>
      (await widget.auth.api.get(
                '/api/admin/users',
                query: {'query': _search.text.trim()},
              )
              as List)
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();

  void _reload() => setState(() {
    _future = _load();
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(AdminUser u) async {
    if (_busyId != null) return;
    String? reason;
    if (!u.suspended) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _SuspendDialog(name: u.fullName),
      );
      if (reason == null) return;
    } else {
      final ok = await confirmDialog(
        context,
        title: 'Restore ${u.fullName}?',
        message: 'They will be able to sign in again.',
        confirmLabel: 'Restore',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() {
      _busyId = u.id;
    });
    try {
      await widget.auth.api.post(
        '/api/admin/users/${u.id}/suspension',
        body: {'suspended': !u.suspended, 'reason': reason},
      );
      if (mounted) {
        showToast(
          context,
          u.suspended ? 'Account restored.' : 'Account suspended.',
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
      appBar: AppBar(title: const Text('Users')),
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
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _reload,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AsyncView<List<AdminUser>>(
              future: _future,
              onRetry: _reload,
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.people_outline,
              emptyMessage: 'No users match that search.',
              builder: (context, users) => Column(
                children: [
                  for (final u in users)
                    TLCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            auth: widget.auth,
                            userId: u.id,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserAvatar(name: u.fullName, url: u.avatarUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.fullName, style: text.titleMedium),
                                    Text(u.email, style: text.bodySmall),
                                  ],
                                ),
                              ),
                              if (u.suspended)
                                const StatusPill(
                                  'Suspended',
                                  fg: TL.coral700,
                                  bg: TL.coral100,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              roleLabels[u.role] ?? u.role,
                              humanize(u.accountStatus),
                              [u.city, u.province]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(', '),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: text.bodySmall,
                          ),
                          if (u.suspended && u.suspensionReason != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${u.suspensionReason}',
                              style: text.bodySmall,
                            ),
                          ],
                          // The API refuses to suspend administrators; do not offer it.
                          if (u.role != 'ADMIN' && u.id != widget.auth.user!.id)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busyId == u.id
                                    ? null
                                    : () => _toggle(u),
                                child: Text(
                                  u.suspended
                                      ? 'Restore account'
                                      : 'Suspend account',
                                  style: TextStyle(
                                    color: u.suspended
                                        ? TL.tide700
                                        : TL.coral700,
                                  ),
                                ),
                              ),
                            ),
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
}

class _SuspendDialog extends StatefulWidget {
  const _SuspendDialog({required this.name});
  final String name;

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Suspend ${widget.name}?'),
    content: TextField(
      controller: _reason,
      maxLength: 500,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Reason',
        helperText: 'Required — other administrators can see it',
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
        child: const Text('Suspend'),
      ),
    ],
  );
}
