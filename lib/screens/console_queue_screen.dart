import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';
import 'report_review_screen.dart';

/// The officer's queue: their own approvals, then cleanups still waiting to be resourced.
const _officerFilters = [
  ('all', 'All reports'),
  ('VERIFIED', 'Verified'),
  ('ESCALATED', 'Waiting for approval'),
  ('AWAITING_RESOURCES', 'Waiting for resource assigning'),
  ('REJECTED', 'Rejected'),
];

/// The administrator's queue. "Waiting for approval" is the reports the community has verified.
const _adminFilters = [
  ('all', 'All reports'),
  ('VERIFIED', 'Waiting for approval'),
  ('ESCALATED', 'With government officer'),
  ('REJECTED', 'Rejected'),
];

/// GET /api/reports?reviewQueue=true — what administrators and government officers work through.
/// Mirrors pages/authority/Queue.jsx.
class ConsoleQueueScreen extends StatefulWidget {
  const ConsoleQueueScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ConsoleQueueScreen> createState() => _ConsoleQueueScreenState();
}

class _ConsoleQueueScreenState extends State<ConsoleQueueScreen> {
  late String _filter = widget.auth.user!.isAuthority ? 'ESCALATED' : 'all';
  String _severity = 'all';
  String _district = 'all';
  String _order = 'newest';
  late Future<List<Report>> _future = _load();

  bool get _officer => widget.auth.user!.isAuthority;

  Future<List<Report>> _load() async {
    final json =
        await widget.auth.api.get(
              '/api/reports',
              query: {
                if (_filter == 'AWAITING_RESOURCES') ...{
                  'reviewQueue': 'true',
                  'awaitingResources': 'true',
                } else ...{
                  'status': _filter == 'all' ? null : _filter,
                  'reviewQueue': 'true',
                },
                'size': '100',
              },
            )
            as Map<String, dynamic>;
    return [
      for (final e in json['content'] as List)
        Report.fromJson(e as Map<String, dynamic>),
    ];
  }

  void _reload() => setState(() {
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    final filters = _officer ? _officerFilters : _adminFilters;
    return Scaffold(
      appBar: AppBar(title: const Text('Review queue')),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (value, label) in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _filter == value,
                        onSelected: (_) {
                          _filter = value;
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _severity,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Risk level'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Any risk level'),
                      ),
                      for (final s in const [
                        'CRITICAL',
                        'HIGH',
                        'MEDIUM',
                        'LOW',
                      ])
                        DropdownMenuItem(
                          value: s,
                          child: Text(severityLabels[s]!),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _severity = v ?? 'all';
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _district,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'District'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Any district'),
                      ),
                      for (final d in districts)
                        DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: (v) => setState(() {
                      _district = v ?? 'all';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _order,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Order'),
              items: const [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text('Latest reported first'),
                ),
                DropdownMenuItem(
                  value: 'oldest',
                  child: Text('Oldest reported first'),
                ),
              ],
              onChanged: (v) => setState(() {
                _order = v ?? 'newest';
              }),
            ),
            const SizedBox(height: 16),
            AsyncView<List<Report>>(
              future: _future,
              onRetry: _reload,
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.fact_check_outlined,
              emptyMessage: _filter == 'AWAITING_RESOURCES'
                  ? 'Every approved cleanup has its resources — nothing is waiting here.'
                  : 'Nothing in this queue — try another status filter.',
              builder: (context, all) {
                final rows =
                    all
                        .where(
                          (r) => _severity == 'all' || r.severity == _severity,
                        )
                        .where((r) => _district == 'all' || _matchesDistrict(r))
                        .toList()
                      ..sort((a, b) {
                        final x = a.createdAt ?? DateTime(0);
                        final y = b.createdAt ?? DateTime(0);
                        return _order == 'oldest'
                            ? x.compareTo(y)
                            : y.compareTo(x);
                      });
                if (rows.isEmpty) {
                  return const EmptyState(
                    message: 'No reports match these filters.',
                  );
                }
                return Column(
                  children: [
                    for (final r in rows)
                      ReportCard(
                        report: r,
                        onTap: () async {
                          // APPROVED reports are cleanups now: the review screen sends officials on.
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportReviewScreen(
                                auth: widget.auth,
                                reportId: r.id,
                              ),
                            ),
                          );
                          if (mounted) _reload();
                        },
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

  // The list payload has no district, so match on the site name like the website's fallback.
  bool _matchesDistrict(Report r) => [r.locationName, r.province]
      .whereType<String>()
      .join(' ')
      .toLowerCase()
      .contains(_district.toLowerCase());
}
