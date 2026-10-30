import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/project_widgets.dart';
import 'project_detail_screen.dart';

export 'project_detail_screen.dart' show ProjectDetailScreen;

const _filters = [
  ('all', 'All'),
  ('PLANNED', 'Planned'),
  ('ACTIVE', 'Active'),
  ('COMPLETED', 'Completed'),
];

/// Cleanup projects: GET /api/projects (public; the token adds the viewer's "joined" flag).
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.auth, this.onBack});
  final AuthController auth;

  /// Set by a home shell when an earlier tab can be returned to; shows a back arrow.
  /// When null the app bar keeps its usual behaviour (an arrow only on a pushed route).
  final VoidCallback? onBack;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _status = 'all';

  /// '' = every province. Filtered on the phone, as the website's Cleanups page does.
  String _province = '';
  late Future<List<Project>> _projects = _load();

  Future<List<Project>> _load() async {
    final list =
        await widget.auth.api.get(
              '/api/projects',
              query: {'status': _status == 'all' ? null : _status},
            )
            as List;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _reload() => setState(() {
    _projects = _load();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: const Text('Cleanups'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          try {
            await _projects;
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
                  for (final (value, label) in _filters)
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
            DropdownButtonFormField<String>(
              initialValue: _province,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Province'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Every province'),
                ),
                for (final p in provinces)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) => setState(() => _province = v ?? ''),
            ),
            const SizedBox(height: 16),
            AsyncView<List<Project>>(
              future: _projects,
              onRetry: _reload,
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.cleaning_services_outlined,
              emptyMessage:
                  'No cleanups here yet — approved reports become cleanups.',
              builder: (context, all) {
                final projects = _province.isEmpty
                    ? all
                    : all.where((p) => p.province == _province).toList();
                String count(int n) => '$n cleanup${n == 1 ? '' : 's'}';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _province.isEmpty
                            ? count(all.length)
                            : '${count(projects.length)} of ${all.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (projects.isEmpty)
                      EmptyState(
                        message:
                            'No cleanups in $_province with this status yet.',
                        icon: Icons.cleaning_services_outlined,
                      ),
                    for (final p in projects)
                      ProjectCard(
                        project: p,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(
                              auth: widget.auth,
                              projectId: p.id,
                              onChanged: _reload,
                            ),
                          ),
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

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.onTap});
  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = project;
    final dates = p.completedAt != null
        ? 'Completed ${formatDate(p.completedAt)}'
        : p.startedAt != null
        ? 'Started ${formatDate(p.startedAt)}'
        : p.createdAt != null
        ? 'Created ${formatDate(p.createdAt)}'
        : '';
    return TLCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                p.reference,
                style: const TextStyle(
                  fontFamily: TL.fontMono,
                  fontSize: 13,
                  color: TL.textMuted,
                ),
              ),
              ProjectStatusPill(p.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(p.title, style: text.titleMedium),
          if (p.locationLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14, color: TL.textMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(p.locationLine, style: text.bodySmall)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (p.completionPercentage / 100).clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${p.completionPercentage}% complete · ${p.volunteerCount + p.diverCount} joined',
                style: text.bodySmall,
              ),
              if (p.joined == true)
                const Text(
                  'Joined',
                  style: TextStyle(
                    color: TL.kelp600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (dates.isNotEmpty)
                Text(dates, style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
