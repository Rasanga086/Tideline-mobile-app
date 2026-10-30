import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';

/// GET /api/analytics/summary[?district=] — the console dashboard.
/// Mirrors pages/authority/Analytics.jsx: same figures, same labels, same refresh rules.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.auth});
  final AuthController auth;

  /// How often the figures refresh while the screen is open, as on the website.
  static const refreshEvery = Duration(seconds: 60);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

/// (JSON key, label, icon) — the headline cards, in the website's order.
const _statCards = <(String, String, IconData)>[
  ('reportedSites', 'Open reports', Icons.place_outlined),
  ('communityVerified', 'Verified by the community', Icons.verified_outlined),
  ('escalatedReports', 'With the government officer', Icons.flag_outlined),
  ('activeProjects', 'Active projects', Icons.waves_outlined),
  ('completedProjects', 'Completed projects', Icons.done_all),
  ('wasteRemovedKg', 'Waste removed', Icons.delete_outline),
  ('peopleJoined', 'People joined cleanups', Icons.volunteer_activism_outlined),
  ('registeredVolunteers', 'Registered members', Icons.groups_outlined),
];

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with WidgetsBindingObserver {
  String? _district;
  Summary? _summary;
  Object? _error;
  bool _loading = true;
  int _request = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(AnalyticsScreen.refreshEvery, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app shows current figures, like the website does on window focus.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  /// Keeps the last figures on screen while refreshing; only the newest request is applied,
  /// so switching district quickly never shows an older district's numbers.
  Future<void> _load() async {
    final request = ++_request;
    if (!_loading) setState(() => _loading = true);
    try {
      final json = await widget.auth.api.get(
        '/api/analytics/summary',
        query: {'district': _district},
      );
      if (!mounted || request != _request) return;
      setState(() {
        _summary = Summary.fromJson(json as Map<String, dynamic>);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _pickDistrict(String? district) {
    setState(() {
      _district = district;
      _summary = null; // another district's figures must not linger
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.auth.user?.isAuthority == true ? 'Government officer' : 'Administrator'} console',
              style: const TextStyle(
                fontFamily: TL.fontBody,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: TL.textMuted,
              ),
            ),
            const Text('Analytics'),
          ],
        ),
        bottom: _loading && s != null
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context, s),
                    const SizedBox(height: 16),
                    if (s == null && _error != null)
                      ErrorState(message: messageOf(_error!), onRetry: _load)
                    else if (s == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      if (_error != null) _staleBanner(context),
                      _content(context, s),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Summary? s) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _district == null
              ? 'System-wide performance and regional pollution trends.'
              : 'Reports, cleanups and people in $_district district.',
          style: text.bodyMedium?.copyWith(color: TL.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _district ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'District'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Every district'),
                  ),
                  for (final d in districts)
                    DropdownMenuItem(value: d, child: Text('$d district')),
                ],
                onChanged: (v) =>
                    _pickDistrict(v == null || v.isEmpty ? null : v),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Refresh',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                // Icon-only on very narrow phones so the filter keeps its room.
                label: MediaQuery.sizeOf(context).width < 360
                    ? const SizedBox.shrink()
                    : const Text('Refresh'),
              ),
            ),
          ],
        ),
        if (s?.generatedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            _loading ? 'Updating…' : 'Updated ${timeAgo(s!.generatedAt)}',
            style: text.bodySmall,
          ),
        ],
      ],
    );
  }

  /// A refresh failed but older figures are still showing: say so instead of hiding them.
  Widget _staleBanner(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: TL.buoy100,
      borderRadius: BorderRadius.circular(TL.radiusMd),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.cloud_off_outlined, color: TL.buoy600),
        title: Text('Could not refresh. ${messageOf(_error!)}'),
        trailing: TextButton(onPressed: _load, child: const Text('Retry')),
      ),
    ),
  );

  Widget _content(BuildContext context, Summary s) {
    final text = Theme.of(context).textTheme;
    // (number, unit) — the unit is shown small beside the number, as on the website.
    final values = <String, (String, String?)>{
      'reportedSites': ('${s.reportedSites}', null),
      'communityVerified': ('${s.communityVerified}', null),
      'escalatedReports': ('${s.escalatedReports}', null),
      'activeProjects': ('${s.activeProjects}', null),
      'completedProjects': ('${s.completedProjects}', null),
      'wasteRemovedKg': (
        s.wasteRemovedKg.toStringAsFixed(s.wasteRemovedKg % 1 == 0 ? 0 : 1),
        'kg',
      ),
      'peopleJoined': ('${s.peopleJoined}', null),
      'registeredVolunteers': ('${s.registeredVolunteers}', null),
    };

    // (label, count, icon, calm) — counts that mean somebody has to do something.
    final attention = <(String, int, IconData, bool)>[
      (
        'Reports waiting for an administrator',
        s.verifiedIncidents,
        Icons.fact_check_outlined,
        false,
      ),
      if (s.accountsAwaitingVerification != null)
        (
          'Accounts waiting to be verified',
          s.accountsAwaitingVerification!,
          Icons.badge_outlined,
          false,
        ),
      (
        'Projects without resources',
        s.awaitingResources,
        Icons.warning_amber_outlined,
        false,
      ),
      ('Projects ready to run', s.readyToRun, Icons.groups_outlined, true),
    ];

    final totalAnswers = s.helpCallAnswers.values.fold<int>(0, (a, b) => a + b);

    final panels = <Widget>[
      _Panel(
        title: 'Reports by location',
        subtitle:
            'Totals per district, from the district recorded on each report.',
        child: _Bars(
          rows: [
            for (final d in s.districtBreakdown)
              ('${d.name} district', d.count),
            if (s.reportsWithoutDistrict > 0)
              ('District not recorded', s.reportsWithoutDistrict),
          ],
          empty: 'No reports recorded yet.',
        ),
      ),
      _Panel(
        title: 'Open reports by status',
        child: _StatusColumns(
          columns: [
            for (final e in s.reportsByStatus.entries)
              (reportStatusStyle(e.key).$1, e.value),
          ],
          empty: 'No reports recorded yet.',
        ),
      ),
      _Panel(
        title: 'Cleanup projects',
        subtitle: 'Where every project has got to.',
        child: _Bars(
          rows: [for (final e in s.projectsByStage.entries) (e.key, e.value)],
          colour: TL.tide600,
          empty: 'No cleanup projects yet.',
        ),
      ),
      _Panel(
        title: 'Calls for help',
        subtitle: totalAnswers == 0
            ? 'No calls for help have gone out yet.'
            : '$totalAnswers sent to people living near a cleanup.',
        child: totalAnswers == 0
            ? const SizedBox.shrink()
            : _Bars(
                rows: [
                  for (final e in s.helpCallAnswers.entries) (e.key, e.value),
                ],
                max: totalAnswers,
                colourOf: (label) => switch (label) {
                  'Joined' => TL.kelp600,
                  'Ignored' => TL.gray300,
                  _ => TL.buoy600,
                },
              ),
      ),
      _Panel(
        title: 'Reports by province',
        child: _Bars(
          rows: [
            for (final p in s.provinceBreakdown.take(9)) (p.name, p.count),
          ],
          colour: TL.buoy600,
          empty: 'No reports recorded yet.',
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final statColumns = width >= 900 ? 4 : (width >= 560 ? 3 : 2);
        final panelColumns = width >= 760 ? 2 : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.district != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: TL.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reports and cleanups are counted for ${s.district} district. '
                        'Members${s.accountsAwaitingVerification != null ? ' and accounts awaiting verification' : ''} '
                        'are counted for ${s.province ?? 'its province'}, because an account '
                        'records the province it is in, not the district.',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            _Grid(
              columns: statColumns,
              children: [
                for (final (key, label, icon) in _statCards)
                  _StatCard(
                    label: label,
                    icon: icon,
                    value: values[key]!.$1,
                    unit: values[key]!.$2,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TLCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Needs attention', style: text.titleSmall),
                  const SizedBox(height: 12),
                  _Grid(
                    columns: width >= 560 ? 2 : 1,
                    gap: 10,
                    children: [
                      for (final (label, count, icon, calm) in attention)
                        _AttentionTile(
                          label: label,
                          count: count,
                          icon: icon,
                          calm: calm,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Grid(columns: panelColumns, children: panels),
          ],
        );
      },
    );
  }
}

/// Lays [children] out in rows of [columns] equal-width cells.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children, this.gap = 12});
  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: w, child: child),
        ],
      );
    },
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TLCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: text.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Labelled horizontal bars, scaled to the largest row (or to [max]).
class _Bars extends StatelessWidget {
  const _Bars({
    required this.rows,
    this.empty,
    this.max,
    this.colour = TL.tide500,
    this.colourOf,
  });
  final List<(String, int)> rows;
  final String? empty;
  final int? max;
  final Color colour;
  final Color Function(String label)? colourOf;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (rows.isEmpty) {
      return Text(empty ?? '', style: text.bodySmall);
    }
    final top = max ?? rows.fold<int>(1, (a, r) => r.$2 > a ? r.$2 : a);
    return Column(
      children: [
        for (final (label, count) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: text.bodySmall)),
                    Text('$count', style: text.labelLarge),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: top == 0 ? 0 : count / top,
                  minHeight: 8,
                  color: colourOf?.call(label) ?? colour,
                  backgroundColor: TL.gray200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.calm});
  final int count;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = count == 0
        ? (TL.gray600, TL.gray100)
        : calm
        ? (TL.kelp600, TL.kelp100)
        : (TL.buoy600, TL.buoy100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// One headline figure: tinted icon box and label on top, the number below
/// (Analytics.jsx STAT_CARDS).
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.value,
    this.unit,
  });
  final String label;
  final IconData icon;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value${unit == null ? '' : ' $unit'}',
      child: ExcludeSemantics(
        child: TLCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: TL.tide100,
                      borderRadius: BorderRadius.circular(TL.radiusSm),
                    ),
                    child: Icon(icon, size: 18, color: TL.tide700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontFamily: TL.fontMono,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: TL.textStrong,
                  ),
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: text.bodySmall?.copyWith(
                          fontFamily: TL.fontBody,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "Needs attention" tile: icon, what is waiting, and how many.
class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.calm,
  });
  final String label;
  final int count;
  final IconData icon;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final waiting = count > 0 && !calm;
    return Semantics(
      container: true,
      label: '$label: $count',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: TL.gray50,
            borderRadius: BorderRadius.circular(TL.radiusMd),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: waiting ? TL.buoy600 : TL.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TL.textBody),
                ),
              ),
              const SizedBox(width: 8),
              _CountChip(count: count, calm: calm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical columns, one per label: the number above, a bar scaled to the tallest column,
/// the label below (Analytics.jsx "Open reports by status"). A zero still gets a short stub
/// so the column is visible, as on the website.
class _StatusColumns extends StatelessWidget {
  const _StatusColumns({required this.columns, this.empty});
  final List<(String, int)> columns;
  final String? empty;

  /// The tallest bar, and the shortest drawn for a zero.
  static const maxBar = 100.0;
  static const minBar = 6.0;

  /// Bar height for [count] when the tallest column is [top].
  static double barHeight(int count, int top) =>
      top <= 0 ? minBar : (count / top * maxBar).clamp(minBar, maxBar);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (columns.isEmpty) return Text(empty ?? '', style: text.bodySmall);
    final top = columns.fold<int>(1, (a, c) => c.$2 > a ? c.$2 : a);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (label, count) in columns)
          Expanded(
            child: Semantics(
              container: true,
              label: '$label: $count',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: TL.fontMono,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: TL.textStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: maxBar,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          key: ValueKey('status-bar-$label'),
                          width: 28,
                          height: barHeight(count, top),
                          decoration: const BoxDecoration(
                            color: TL.tide500,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(TL.radiusSm),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Room for three short lines so the labels line up and never overlap.
                    SizedBox(
                      height: 44,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: TL.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
