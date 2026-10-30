import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';
import 'create_report_screen.dart';
import 'report_detail_screen.dart';

const _statusFilters = [
  ('all', 'All'),
  ('PENDING', 'Pending'),
  ('VERIFYING', 'Verifying'),
  ('VERIFIED', 'Verified'),
  ('ESCALATED', 'With government officer'),
  ('REJECTED', 'Rejected'),
];

const _pageSize = 30;

/// GET /api/reports — status, severity and sort filters with "load more" paging.
/// Signed-in viewers see their own province's reports (the server narrows the feed).
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _status = 'all';
  String _severity = 'all';
  String _sort = 'newest';

  final List<Report> _items = [];
  int _page = 0;
  bool _last = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Guards against a slow, superseded request overwriting a newer filter's results.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<PagedResult<Report>> _fetch(int page) async {
    final json =
        await widget.auth.api.get(
              '/api/reports',
              query: {
                // "all" is not a ReportStatus: the website omits it, so the API is not sent it either.
                'status': _status == 'all' ? null : _status,
                'severity': _severity == 'all' ? null : _severity,
                'sort': _sort,
                'page': '$page',
                'size': '$_pageSize',
              },
            )
            as Map<String, dynamic>;
    return PagedResult(
      items: (json['content'] as List)
          .map((e) => Report.fromJson(e as Map<String, dynamic>))
          .toList(),
      last: (json['last'] as bool?) ?? true,
      total: (json['totalElements'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _fetch(0);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _page = 0;
        _last = page.last;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = messageOf(e));
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _last) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _page += 1;
        _last = page.last;
      });
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _createReport() async {
    final allowed = await ensureSignedIn(
      context,
      widget.auth,
      reason:
          'Reporting a polluted site needs a Tideline account, so the community knows who to ask about it.',
    );
    if (!allowed || !mounted) return;
    final created = await Navigator.of(context).push<Report>(
      MaterialPageRoute(builder: (_) => CreateReportScreen(auth: widget.auth)),
    );
    if (created == null || !mounted) return;
    _status =
        'all'; // a new report is PENDING; make sure the filter does not hide it
    _severity = 'all';
    _sort = 'newest';
    _reload();
    showToast(context, 'Report ${created.reference} submitted.');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createReport,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Report'),
      ),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.waves, color: TL.tide600),
            SizedBox(width: 8),
            Text(
              'Tideline',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            Text('Nearby reports', style: text.headlineSmall),
            const SizedBox(height: 2),
            Text(
              user?.province != null
                  ? 'Reports in ${user!.province}'
                  : 'All reported sites',
              style: text.bodySmall,
            ),
            if (user != null && user.province == null) ...[
              const SizedBox(height: 12),
              const NoticeBanner(
                'Add your province in your profile to see the reports around you.',
                tone: BannerTone.info,
              ),
            ],
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (value, label) in _statusFilters)
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
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _severity,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Any severity'),
                      ),
                      for (final e in severityLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) {
                      _severity = v ?? 'all';
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sort'),
                    items: const [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text('Newest first'),
                      ),
                      DropdownMenuItem(
                        value: 'oldest',
                        child: Text('Oldest first'),
                      ),
                    ],
                    onChanged: (v) {
                      _sort = v ?? 'newest';
                      _reload();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _reload)
            else if (_items.isEmpty)
              const EmptyState(
                message:
                    'No reports match these filters — widen them or report a site.',
                icon: Icons.waves,
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_items.length} report${_items.length == 1 ? '' : 's'}${_last ? '' : '+'}',
                  style: text.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              for (final r in _items)
                ReportCard(
                  report: r,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReportDetailScreen(auth: widget.auth, reportId: r.id),
                    ),
                  ),
                ),
              if (!_last)
                Center(
                  child: _loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        )
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(160, 44),
                          ),
                          onPressed: _loadMore,
                          child: const Text('Load more'),
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
