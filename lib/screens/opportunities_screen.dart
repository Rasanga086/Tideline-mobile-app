import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

(String, Color, Color) _applicationStatus(String s) => switch (s) {
  'ACCEPTED' => ('Accepted', TL.kelp600, TL.kelp100),
  'DECLINED' => ('Declined', TL.gray600, TL.gray100),
  _ => ('Pending', TL.buoy600, TL.buoy100),
};

/// Volunteer opportunities (GET /api/opportunities). Divers apply; organisations post
/// opportunities and decide on applications. Mirrors pages/volunteer/Opportunities.jsx.
class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  late Future<(List<Opportunity>, List<Application>)> _future = _load();
  int? _busyId;

  AppUser get _me => widget.auth.user!;
  bool get _isOrg => _me.isOrganization;
  bool get _isDiver => _me.isDiver;

  Future<(List<Opportunity>, List<Application>)> _load() async {
    final api = widget.auth.api;
    final all = (await api.get('/api/opportunities') as List)
        .map((e) => Opportunity.fromJson(e as Map<String, dynamic>))
        .toList();
    // Only divers have "my applications"; the API answers 403 to everyone else.
    final mine = _isDiver
        ? (await api.get('/api/opportunities/applications/mine') as List)
              .map((e) => Application.fromJson(e as Map<String, dynamic>))
              .toList()
        : <Application>[];
    return (
      _isOrg ? all.where((o) => o.organizationId == _me.id).toList() : all,
      mine,
    );
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _apply(Opportunity o) async {
    if (_busyId != null) return;
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _ApplyDialog(title: o.title),
    );
    if (message == null || !mounted) return;
    setState(() {
      _busyId = o.id;
    });
    try {
      await widget.auth.api.post(
        '/api/opportunities/${o.id}/applications',
        body: {'message': message},
      );
      if (mounted) {
        showToast(context, 'Application sent to ${o.organizationName}.');
      }
      _reload();
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreateOpportunityScreen(auth: widget.auth),
      ),
    );
    if (created == true && mounted) {
      showToast(context, 'Opportunity posted.');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOrg ? 'Your opportunities' : 'Opportunities'),
      ),
      floatingActionButton: _isOrg || _me.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Post'),
            )
          : null,
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
            if (!_isDiver && !_isOrg)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: NoticeBanner(
                  'Register as a volunteer diver with your certification to apply for these assignments.',
                  tone: BannerTone.info,
                ),
              ),
            AsyncView<(List<Opportunity>, List<Application>)>(
              future: _future,
              onRetry: _reload,
              isEmpty: (d) => d.$1.isEmpty,
              emptyIcon: Icons.anchor,
              emptyMessage: _isOrg
                  ? 'You have not posted any opportunities yet.'
                  : 'No open opportunities right now. Check back soon.',
              builder: (context, data) {
                final (items, mine) = data;
                final byOpportunity = {
                  for (final a in mine) a.opportunityId: a,
                };
                return Column(
                  children: [
                    for (final o in items)
                      TLCard(
                        onTap: _isOrg
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _ApplicationsScreen(
                                    auth: widget.auth,
                                    opportunity: o,
                                  ),
                                ),
                              )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(o.title, style: text.titleMedium),
                                ),
                                StatusPill(
                                  o.paid ? 'Paid' : 'Volunteer',
                                  fg: o.paid ? TL.kelp600 : TL.sea600,
                                  bg: o.paid ? TL.kelp100 : TL.sea100,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${o.organizationName} · ${o.region}',
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(o.description, style: text.bodyMedium),
                            if (o.requiredCertification != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Requires ${certificationLabels[o.requiredCertification] ?? o.requiredCertification}',
                                style: text.bodySmall,
                              ),
                            ],
                            if (_isDiver) ...[
                              const SizedBox(height: 12),
                              if (byOpportunity[o.id] case final app?)
                                Builder(
                                  builder: (_) {
                                    final (label, fg, bg) = _applicationStatus(
                                      app.status,
                                    );
                                    return StatusPill(
                                      'Application: $label',
                                      fg: fg,
                                      bg: bg,
                                    );
                                  },
                                )
                              else
                                BusyButton(
                                  label: 'Apply',
                                  icon: Icons.send_outlined,
                                  busy: _busyId == o.id,
                                  onPressed: () => _apply(o),
                                ),
                            ],
                            if (_isOrg)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Tap to review applications',
                                  style: TextStyle(
                                    color: TL.tide700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyDialog extends StatefulWidget {
  const _ApplyDialog({required this.title});
  final String title;

  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  final _message = TextEditingController(
    text: 'Available for this assignment.',
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Apply: ${widget.title}'),
    content: TextField(
      controller: _message,
      maxLength: 1000,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Message to the organisation',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
        onPressed: () => Navigator.pop(context, _message.text.trim()),
        child: const Text('Send'),
      ),
    ],
  );
}

/// POST /api/opportunities — organisations and administrators.
class _CreateOpportunityScreen extends StatefulWidget {
  const _CreateOpportunityScreen({required this.auth});
  final AuthController auth;

  @override
  State<_CreateOpportunityScreen> createState() =>
      _CreateOpportunityScreenState();
}

class _CreateOpportunityScreenState extends State<_CreateOpportunityScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _region;
  String? _certification;
  bool _paid = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.api.post(
        '/api/opportunities',
        body: {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'region': _region,
          'requiredCertification': _certification,
          'paid': _paid,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageOf(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Post an opportunity')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            NoticeBanner(_error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _title,
            enabled: !_busy,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a title.' : null,
          ),
          TextFormField(
            controller: _description,
            enabled: !_busy,
            maxLength: 2000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a description.' : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _region,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Region'),
            items: [
              for (final p in provinces)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _region = v;
                  }),
            validator: (v) => v == null ? 'Choose a region.' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _certification,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Required certification (optional)',
            ),
            items: [
              for (final e in certificationLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _certification = v;
                  }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _paid,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _paid = v;
                  }),
            title: const Text('Paid assignment'),
          ),
          const SizedBox(height: 16),
          BusyButton(
            label: 'Post opportunity',
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );
}

/// GET /api/opportunities/{id}/applications and POST /applications/{id}/decision.
class _ApplicationsScreen extends StatefulWidget {
  const _ApplicationsScreen({required this.auth, required this.opportunity});
  final AuthController auth;
  final Opportunity opportunity;

  @override
  State<_ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<_ApplicationsScreen> {
  late Future<List<Application>> _future = _load();
  int? _busyId;

  Future<List<Application>> _load() async =>
      (await widget.auth.api.get(
                '/api/opportunities/${widget.opportunity.id}/applications',
              )
              as List)
          .map((e) => Application.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<void> _decide(Application a, String status) async {
    if (_busyId != null) return;
    setState(() {
      _busyId = a.id;
    });
    try {
      await widget.auth.api.post(
        '/api/opportunities/applications/${a.id}/decision',
        body: {'status': status},
      );
      if (mounted) {
        showToast(
          context,
          status == 'ACCEPTED'
              ? 'Application accepted.'
              : 'Application declined.',
        );
        setState(() {
          _future = _load();
        });
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
      appBar: AppBar(title: Text(widget.opportunity.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncView<List<Application>>(
            future: _future,
            onRetry: () => setState(() {
              _future = _load();
            }),
            isEmpty: (l) => l.isEmpty,
            emptyMessage: 'No applications yet.',
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
                              child: Text(a.diverName, style: text.titleMedium),
                            ),
                            Builder(
                              builder: (_) {
                                final (label, fg, bg) = _applicationStatus(
                                  a.status,
                                );
                                return StatusPill(label, fg: fg, bg: bg);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            certificationLabels[a.certificationLevel],
                            if (a.experienceYears != null)
                              '${a.experienceYears} yrs',
                            '${a.completedProjects} cleanups',
                            if (a.averageMark != null)
                              'rating ${a.averageMark!.toStringAsFixed(1)}/5',
                          ].whereType<String>().join(' · '),
                          style: text.bodySmall,
                        ),
                        if (a.message != null && a.message!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(a.message!, style: text.bodyMedium),
                        ],
                        if (a.status == 'PENDING') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _busyId == a.id
                                      ? null
                                      : () => _decide(a, 'ACCEPTED'),
                                  child: const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  onPressed: _busyId == a.id
                                      ? null
                                      : () => _decide(a, 'DECLINED'),
                                  child: const Text('Decline'),
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
    );
  }
}
