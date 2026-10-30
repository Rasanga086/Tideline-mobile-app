import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'projects_screen.dart';

/// What a HELP_NEEDED alert opens: the cleanup's needs, then Join (optionally pledging
/// equipment) or Ignore — POST /api/alerts/{id}/reply. Mirrors pages/volunteer/HelpCall.jsx.
class HelpCallScreen extends StatefulWidget {
  const HelpCallScreen({super.key, required this.auth, required this.alert});
  final AuthController auth;
  final AppAlert alert;

  @override
  State<HelpCallScreen> createState() => _HelpCallScreenState();
}

class _HelpCallScreenState extends State<HelpCallScreen> {
  late Future<Project> _project = _load();
  final Map<String, TextEditingController> _pledges = {};
  String? _busy;
  String? _error;
  String? _reply;

  @override
  void initState() {
    super.initState();
    _reply = widget.alert.reply;
  }

  Future<Project> _load() async => Project.fromJson(
    await widget.auth.api.get('/api/projects/${widget.alert.projectId}')
        as Map<String, dynamic>,
  );

  @override
  void dispose() {
    for (final c in _pledges.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _answer(String reply, Project p) async {
    if (_busy != null) return; // no duplicate answers
    setState(() {
      _busy = reply;
      _error = null;
    });
    try {
      final equipment = <Map<String, Object>>[
        if (reply == 'JOINED')
          for (final e in _pledges.entries)
            if ((int.tryParse(e.value.text.trim()) ?? 0) > 0)
              {'name': e.key, 'quantity': int.parse(e.value.text.trim())},
      ];
      await widget.auth.api.post(
        '/api/alerts/${widget.alert.id}/reply',
        body: {'reply': reply, 'equipment': equipment},
      );
      if (!mounted) return;
      if (reply == 'JOINED') {
        showToast(context, 'You have joined this cleanup. Thank you.');
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                ProjectDetailScreen(auth: widget.auth, projectId: p.id),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageOf(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Call for help')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AsyncView<Project>(
          future: _project,
          onRetry: () => setState(() {
            _project = _load();
          }),
          builder: (context, p) {
            final me = widget.auth.user;
            final km = distanceKm(
              me?.latitude,
              me?.longitude,
              p.latitude,
              p.longitude,
            );
            final shortfall = p.equipment
                .where((e) => e.securedQuantity < e.quantity)
                .toList();
            final answered = _reply != null;
            final cover = AppConfig.mediaUrl(p.coverUrl);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cover != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(TL.radiusLg),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: TL.sea100),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  p.reference,
                  style: const TextStyle(
                    fontFamily: TL.fontMono,
                    color: TL.textMuted,
                    fontSize: 13,
                  ),
                ),
                Text(p.title, style: text.headlineSmall),
                if (p.locationLine.isNotEmpty)
                  Text(p.locationLine, style: text.bodySmall),
                const SizedBox(height: 8),
                Text(p.description, style: text.bodyMedium),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  NoticeBanner(_error!),
                ],
                const SectionTitle('What you should know'),
                TLCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoRow(
                        Icons.near_me_outlined,
                        'How far from you',
                        km == null
                            ? 'Add your location in your profile to see this'
                            : '${km.toStringAsFixed(1)} km away',
                      ),
                      InfoRow(
                        Icons.groups_outlined,
                        'Volunteers',
                        '${p.volunteerCount} of ${p.volunteersNeeded ?? 0} joined',
                      ),
                      InfoRow(
                        Icons.anchor,
                        'Divers',
                        '${p.diverCount} of ${p.diversNeeded ?? 0} joined',
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Equipment needed'),
                if (p.equipment.isEmpty)
                  Text(
                    'Nothing to bring — just yourself.',
                    style: text.bodySmall,
                  )
                else
                  TLCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final e in p.equipment)
                          ListTile(
                            dense: true,
                            title: Text(e.name),
                            trailing: Text('× ${e.quantity}'),
                          ),
                      ],
                    ),
                  ),
                const SectionTitle('Can you help?'),
                if (answered) ...[
                  NoticeBanner(
                    _reply == 'JOINED'
                        ? 'You joined this cleanup.'
                        : 'You passed on this one.',
                    tone: _reply == 'JOINED'
                        ? BannerTone.success
                        : BannerTone.info,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailScreen(
                          auth: widget.auth,
                          projectId: p.id,
                        ),
                      ),
                    ),
                    child: const Text('Open the cleanup'),
                  ),
                ] else ...[
                  if (shortfall.isNotEmpty) ...[
                    Text('Anything you can bring?', style: text.bodyMedium),
                    const SizedBox(height: 8),
                    for (final e in shortfall)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${e.name} — ${e.quantity - e.securedQuantity} still needed',
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: _pledges.putIfAbsent(
                                  e.name,
                                  TextEditingController.new,
                                ),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  semanticCounterText:
                                      'How many ${e.name} you can bring',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  BusyButton(
                    label: _busy == 'JOINED' ? 'Joining…' : 'Join this cleanup',
                    icon: Icons.volunteer_activism_outlined,
                    busy: _busy != null,
                    onPressed: () => _answer('JOINED', p),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy != null
                        ? null
                        : () => _answer('IGNORED', p),
                    child: const Text('Ignore'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
