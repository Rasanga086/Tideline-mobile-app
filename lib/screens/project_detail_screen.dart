import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/uploads.dart';
import '../models/models.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/project_widgets.dart';
import '../widgets/resource_planner.dart';
import '../widgets/upload_picker.dart';
import 'user_profile_screen.dart';

const _stages = [
  ('BEFORE', 'Before — how the site looked'),
  ('DURING', 'During — the cleanup under way'),
  ('AFTER', 'After — the site once finished'),
];

/// GET /api/projects/{id}. Join, progress updates with likes and comments, participants
/// and organiser ratings. Every action answers with the updated project, which replaces
/// the screen's state. Mirrors pages/volunteer/CleanupDetail.jsx.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.auth,
    required this.projectId,
    this.onChanged,
  });
  final AuthController auth;
  final int projectId;

  /// Called after an action changed the project so the list behind this screen can refresh.
  final VoidCallback? onChanged;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Future<Project> _project = _load();
  bool _joining = false;

  String get _path => '/api/projects/${widget.projectId}';

  Future<Project> _load() async => Project.fromJson(
    await widget.auth.api.get(_path) as Map<String, dynamic>,
  );

  void _apply(Project updated) {
    if (!mounted) return;
    setState(() {
      _project = Future.value(updated);
    });
    widget.onChanged?.call();
  }

  /// POST /api/projects/{id}/participants without a role: the server picks diver or
  /// volunteer from the account and answers with the updated project.
  Future<void> _join() async {
    if (_joining) return; // no duplicate joins
    setState(() {
      _joining = true;
    });
    try {
      _apply(
        Project.fromJson(
          await widget.auth.api.post('$_path/participants')
              as Map<String, dynamic>,
        ),
      );
      if (mounted) showToast(context, 'You have joined this cleanup.');
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  Future<void> _like(ProjectUpdate u) async {
    try {
      _apply(
        Project.fromJson(
          await widget.auth.api.post('$_path/updates/${u.id}/likes')
              as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    }
  }

  Future<void> _comment(ProjectUpdate u) async {
    final body = await showDialog<String>(
      context: context,
      builder: (_) => const _CommentDialog(),
    );
    if (body == null || body.isEmpty || !mounted) return;
    try {
      _apply(
        Project.fromJson(
          await widget.auth.api.post(
                '$_path/updates/${u.id}/comments',
                body: {'body': body},
              )
              as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    }
  }

  Future<void> _rate(Participant p) async {
    final mark = await showDialog<int>(
      context: context,
      builder: (_) => _MarkDialog(name: p.name),
    );
    if (mark == null || !mounted) return;
    try {
      _apply(
        Project.fromJson(
          await widget.auth.api.post(
                '$_path/participants/${p.id}/mark',
                body: {'mark': mark},
              )
              as Map<String, dynamic>,
        ),
      );
      if (mounted) showToast(context, 'Rating saved.');
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    }
  }

  Widget _joinArea(Project p) {
    final me = widget.auth.user;
    if (p.joined == true) {
      return const NoticeBanner(
        'You have joined this cleanup.',
        tone: BannerTone.success,
      );
    }
    if (me != null && p.ownerId == me.id) {
      return const NoticeBanner(
        'You lead this cleanup, so you are already part of it.',
        tone: BannerTone.info,
      );
    }
    if (p.status == 'COMPLETED') {
      return const NoticeBanner(
        'This cleanup is complete.',
        tone: BannerTone.info,
      );
    }
    if (!p.resourcesFinalized) {
      return const NoticeBanner(
        'Not open yet — the government officer is still assigning its resources.',
        tone: BannerTone.warning,
      );
    }
    if (me == null) {
      return SignInPrompt(
        auth: widget.auth,
        message: 'Sign in to join this cleanup.',
      );
    }
    return BusyButton(
      label: 'Join this cleanup',
      icon: Icons.group_add_outlined,
      busy: _joining,
      onPressed: _join,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cleanup')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _project = _load();
          });
          try {
            await _project;
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            AsyncView<Project>(
              future: _project,
              onRetry: () => setState(() {
                _project = _load();
              }),
              builder: (context, p) {
                final cover = AppConfig.mediaUrl(p.coverUrl);
                final me = widget.auth.user;
                final isOwner = me != null && p.ownerId == me.id;
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
                            errorBuilder: (_, _, _) => Container(
                              color: TL.sea100,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: TL.sea600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p.reference,
                          style: const TextStyle(
                            fontFamily: TL.fontMono,
                            color: TL.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        ProjectStatusPill(p.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(p.title, style: text.headlineSmall),
                    if (p.locationLine.isNotEmpty)
                      Text(p.locationLine, style: text.bodySmall),
                    if (p.ownerName != null)
                      InkWell(
                        onTap: p.ownerId == null || isOwner || me == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(
                                    auth: widget.auth,
                                    userId: p.ownerId!,
                                  ),
                                ),
                              ),
                        child: Text(
                          isOwner
                              ? 'You are the project owner'
                              : 'Led by ${p.ownerName}',
                          style: text.bodySmall?.copyWith(
                            color: isOwner ? null : TL.tide700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(p.description, style: text.bodyMedium),
                    const SizedBox(height: 16),
                    if (!(me?.isOfficial ?? false)) _joinArea(p),
                    const SectionTitle('Progress'),
                    LinearProgressIndicator(
                      value: (p.completionPercentage / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${p.completionPercentage}% complete',
                        '${p.volunteerCount} volunteers · ${p.diverCount} divers',
                        if (p.debrisRemovedKg != null)
                          '${p.debrisRemovedKg} kg removed',
                        if (p.startedAt != null)
                          'Started ${formatDate(p.startedAt)}',
                        if (p.completedAt != null)
                          'Completed ${formatDate(p.completedAt)}',
                      ].join('\n'),
                      style: text.bodySmall,
                    ),
                    if (me != null && me.isAuthority && p.status != 'COMPLETED')
                      ResourcePlanner(
                        key: ValueKey('${p.id}-${p.resourcesFinalized}'),
                        auth: widget.auth,
                        project: p,
                        onSaved: _apply,
                      )
                    else ...[
                      if (p.approvalComment != null &&
                          p.approvalComment!.isNotEmpty) ...[
                        const SectionTitle('Official comment'),
                        NoticeBanner(p.approvalComment!, tone: BannerTone.info),
                      ],
                      if (p.resourcesFinalized) _resources(p),
                    ],
                    if (p.participants != null && p.participants!.isNotEmpty)
                      _participants(
                        p,
                        canRate: isOwner && p.status == 'COMPLETED',
                      ),
                    if (p.canPostProgress)
                      _ProgressForm(
                        auth: widget.auth,
                        projectId: p.id,
                        onUpdated: _apply,
                      ),
                    if (p.updates.isNotEmpty) ...[
                      const SectionTitle('Updates'),
                      for (final u in p.updates) _updateCard(u, me != null),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _resources(Project p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('What the cleanup needs'),
        TLCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
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
              for (final e in p.equipment)
                ListTile(
                  dense: true,
                  leading: Icon(
                    e.securedQuantity >= e.quantity
                        ? Icons.check_circle
                        : Icons.inventory_2_outlined,
                    color: e.securedQuantity >= e.quantity
                        ? TL.kelp600
                        : TL.textMuted,
                  ),
                  title: Text(e.name),
                  trailing: Text('${e.securedQuantity} / ${e.quantity}'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _participants(Project p, {required bool canRate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Participants (${p.participants!.length})'),
        TLCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final x in p.participants!)
                ListTile(
                  dense: true,
                  title: Text(x.name),
                  subtitle: Text(humanize(x.role)),
                  trailing: x.mark != null
                      ? Text('★ ${x.mark}/5')
                      : canRate
                      ? TextButton(
                          onPressed: () => _rate(x),
                          child: const Text('Rate'),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _updateCard(ProjectUpdate u, bool signedIn) {
    final text = Theme.of(context).textTheme;
    final image = AppConfig.mediaUrl(u.imageUrl);
    return TLCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TL.radiusLg),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: TL.sea100,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: TL.sea600,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(humanize(u.stage), fg: TL.sea600, bg: TL.sea100),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          u.authorName,
                          timeAgo(u.createdAt),
                        ].whereType<String>().join(' · '),
                        style: text.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (u.note != null) ...[
                  const SizedBox(height: 8),
                  Text(u.note!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: signedIn ? () => _like(u) : null,
                      icon: Icon(
                        u.likedByMe == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 18,
                      ),
                      label: Text('${u.likeCount}'),
                    ),
                    TextButton.icon(
                      onPressed: signedIn ? () => _comment(u) : null,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text('${u.comments.length}'),
                    ),
                  ],
                ),
                for (final c in u.comments)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${c.author}  ',
                            style: text.labelLarge,
                          ),
                          TextSpan(text: c.body),
                        ],
                      ),
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

/// POST /api/projects/{id}/updates (multipart: `data` {stage, note} and an optional `photo`).
/// Posting an "after" update closes the project, as on the website.
class _ProgressForm extends StatefulWidget {
  const _ProgressForm({
    required this.auth,
    required this.projectId,
    required this.onUpdated,
  });
  final AuthController auth;
  final int projectId;
  final void Function(Project) onUpdated;

  @override
  State<_ProgressForm> createState() => _ProgressFormState();
}

class _ProgressFormState extends State<_ProgressForm> {
  final _note = TextEditingController();
  final List<PickedUpload> _photo = [];
  String _stage = 'DURING';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_photo.isEmpty && _note.text.trim().isEmpty) {
      setState(() {
        _error = 'Add a photo or a note so there is something to show.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final json = await widget.auth.api.postMultipart(
        '/api/projects/${widget.projectId}/updates',
        json: {
          'stage': _stage,
          'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        },
        files: [for (final f in _photo) await uploadPart('photo', f)],
      );
      _note.clear();
      _photo.clear();
      widget.onUpdated(Project.fromJson(json as Map<String, dynamic>));
      if (mounted) showToast(context, 'Progress recorded.');
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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Record progress'),
        TLCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Posting an “after” photo closes the project and marks the site cleaned.',
                style: text.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                NoticeBanner(_error!),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _stage,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Stage'),
                items: [
                  for (final (v, l) in _stages)
                    DropdownMenuItem(
                      value: v,
                      child: Text(l, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _stage = v ?? _stage;
                      }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                enabled: !_busy,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              UploadPicker(
                label: 'Photo (optional)',
                hint: 'JPG, PNG or WebP, up to 8 MB.',
                files: _photo,
                pick: () => pickImages(multiple: false),
                check: (n, s) => checkImage(n, s),
                max: 1,
                enabled: !_busy,
                icon: Icons.image_outlined,
              ),
              const SizedBox(height: 8),
              BusyButton(
                label: 'Post update',
                icon: Icons.upload,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog();

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Comment on this update'),
    content: TextField(
      controller: _ctl,
      maxLength: 1000,
      maxLines: 4,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'Say something'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
        onPressed: () => Navigator.pop(context, _ctl.text.trim()),
        child: const Text('Post'),
      ),
    ],
  );
}

class _MarkDialog extends StatelessWidget {
  const _MarkDialog({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: Text('Rate $name'),
    children: [
      for (var i = 1; i <= 5; i++)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, i),
          child: Text('★' * i + '☆' * (5 - i)),
        ),
    ],
  );
}
