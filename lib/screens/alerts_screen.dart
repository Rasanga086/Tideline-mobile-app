import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/alerts_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'alert_routes.dart';

(IconData, Color, Color) _alertStyle(AppAlert a) {
  if (a.critical) {
    return (Icons.warning_amber_rounded, TL.coral700, TL.coral100);
  }
  return switch (a.type) {
    'NEW_REPORT_NEARBY' => (Icons.place_outlined, TL.sea600, TL.sea100),
    'REPORT_VERIFIED' ||
    'AUTHORITY_DECISION' => (Icons.verified_outlined, TL.kelp600, TL.kelp100),
    'HELP_NEEDED' || 'RESOURCES_NEEDED' => (
      Icons.volunteer_activism_outlined,
      TL.buoy600,
      TL.buoy100,
    ),
    'OPPORTUNITY' => (Icons.anchor, TL.sea600, TL.sea100),
    'COMMENT_REPLY' => (Icons.chat_bubble_outline, TL.sea600, TL.sea100),
    _ => (Icons.notifications_none, TL.gray600, TL.gray100),
  };
}

/// GET /api/alerts, with mark-read, mark-all-read and navigation to the related content.
/// Used for both the member app and the console (the [console] flag only changes where alerts open).
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    required this.auth,
    required this.alerts,
    this.console = false,
  });
  final AuthController auth;
  final AlertsController alerts;
  final bool console;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<AppAlert>> _future = _load();
  List<AppAlert> _items = const [];
  bool _markingAll = false;

  Future<List<AppAlert>> _load() async {
    final list = await widget.auth.api.get('/api/alerts') as List;
    _items = list
        .map((e) => AppAlert.fromJson(e as Map<String, dynamic>))
        .toList();
    widget.alerts.set(_items.where((a) => !a.read).length);
    return _items;
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _markAll() async {
    if (_markingAll) return;
    setState(() {
      _markingAll = true;
    });
    try {
      await widget.auth.api.post('/api/alerts/read-all');
      _reload();
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
        });
      }
    }
  }

  Future<void> _open(AppAlert a) async {
    if (!a.read) {
      // Optimistic: mark locally first; the server call is best-effort.
      setState(() {
        _items = [
          for (final x in _items) x.id == a.id ? x.copyWith(read: true) : x,
        ];
      });
      _future = Future.value(_items);
      widget.alerts.set(_items.where((x) => !x.read).length);
      widget.auth.api.post('/api/alerts/${a.id}/read').catchError((_) {});
    }
    await openAlertTarget(context, widget.auth, a, console: widget.console);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAll,
            child: const Text('Mark all read'),
          ),
        ],
      ),
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
            AsyncView<List<AppAlert>>(
              future: _future,
              onRetry: _reload,
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.notifications_none,
              emptyMessage:
                  "You're all caught up. Alerts about reports and cleanups near you appear here.",
              builder: (context, list) => Column(
                children: [
                  for (final a in list)
                    Builder(
                      builder: (context) {
                        final (icon, fg, bg) = _alertStyle(a);
                        return TLCard(
                          onTap: () => _open(a),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: bg,
                                child: Icon(icon, color: fg, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            a.title,
                                            style: text.titleMedium?.copyWith(
                                              fontWeight: a.read
                                                  ? FontWeight.w500
                                                  : FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (!a.read)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: TL.tide600,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(a.body, style: text.bodyMedium),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          timeAgo(a.createdAt),
                                          style: text.bodySmall,
                                        ),
                                        if (a.reply != null) ...[
                                          const SizedBox(width: 8),
                                          StatusPill(
                                            a.reply == 'JOINED'
                                                ? 'You joined'
                                                : 'Passed',
                                            fg: a.reply == 'JOINED'
                                                ? TL.kelp600
                                                : TL.gray600,
                                            bg: a.reply == 'JOINED'
                                                ? TL.kelp100
                                                : TL.gray100,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
