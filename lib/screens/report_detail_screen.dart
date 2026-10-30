import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';
import 'more_info_screen.dart';
import 'projects_screen.dart';
import 'user_profile_screen.dart';

/// GET /api/reports/{id}: evidence, community verification (votes), reviewer decisions and
/// the threaded discussion with reactions. Mirrors pages/volunteer/ReportDetail.jsx.
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.auth,
    required this.reportId,
  });
  final AuthController auth;
  final int reportId;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Future<ReportDetail> _detail = _loadDetail();
  late Future<List<Comment>> _comments = _loadComments();
  final _commentCtl = TextEditingController();
  bool _voting = false;
  bool _posting = false;
  Comment? _replyTo;

  ApiClient get _api => widget.auth.api;
  String get _path => '/api/reports/${widget.reportId}';

  Future<ReportDetail> _loadDetail() async =>
      ReportDetail.fromJson(await _api.get(_path) as Map<String, dynamic>);

  /// The discussion is for signed-in members only (the API answers 401 to guests).
  Future<List<Comment>> _loadComments() async => !widget.auth.isAuthenticated
      ? const []
      : ((await _api.get('$_path/comments')) as List)
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList();

  Future<void> _refresh() async {
    setState(() {
      _detail = _loadDetail();
      _comments = _loadComments();
    });
    try {
      await _detail;
    } catch (_) {}
  }

  /// POST /votes {confirmed}; sending the same choice again removes the vote.
  Future<void> _vote(bool confirmed) async {
    if (_voting) return;
    setState(() {
      _voting = true;
    });
    try {
      final updated = ReportDetail.fromJson(
        await _api.post('$_path/votes', body: {'confirmed': confirmed})
            as Map<String, dynamic>,
      );
      if (mounted) {
        setState(() {
          _detail = Future.value(updated);
        });
      }
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) {
        setState(() {
          _voting = false;
        });
      }
    }
  }

  Future<void> _post() async {
    final body = _commentCtl.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() {
      _posting = true;
    });
    try {
      await _api.post(
        '$_path/comments',
        body: {'body': body, 'parentId': _replyTo?.id},
      );
      _commentCtl.clear();
      if (mounted) {
        setState(() {
          _replyTo = null;
          _comments = _loadComments();
        });
      }
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  /// POST /comments/{id}/reactions: the same type again removes it, another type replaces it.
  Future<void> _react(Comment c, String type) async {
    try {
      await _api.post(
        '$_path/comments/${c.id}/reactions',
        body: {'type': type},
      );
      if (mounted) {
        setState(() {
          _comments = _loadComments();
        });
      }
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    }
  }

  @override
  void dispose() {
    _commentCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            AsyncView<ReportDetail>(
              future: _detail,
              onRetry: () => setState(() {
                _detail = _loadDetail();
              }),
              builder: _body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ReportDetail d) {
    final text = Theme.of(context).textTheme;
    final r = d.report;
    final me = widget.auth.user;
    final isReporter = me != null && d.reporter?.id == me.id;
    final (statusLabel, statusFg, statusBg) = reportStatusStyle(r.status);
    final place = [
      r.locationLine,
      d.district,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EvidenceStrip(
          items: d.evidence.isNotEmpty
              ? d.evidence
              : [
                  for (final u in d.photoUrls)
                    Evidence(url: u, contentType: 'image/jpeg'),
                ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              r.reference,
              style: const TextStyle(
                fontFamily: TL.fontMono,
                color: TL.textMuted,
                fontSize: 13,
              ),
            ),
            StatusPill(statusLabel, fg: statusFg, bg: statusBg),
          ],
        ),
        const SizedBox(height: 4),
        Text(r.title, style: text.headlineSmall),
        const SizedBox(height: 6),
        if (place.isNotEmpty) Text(place, style: text.bodySmall),
        if (d.latitude != null && d.longitude != null)
          Text(
            '${d.latitude!.toStringAsFixed(5)}, ${d.longitude!.toStringAsFixed(5)}',
            style: text.bodySmall,
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: severityColors[r.severity],
            ),
            const SizedBox(width: 6),
            Text(
              '${severityLabels[r.severity] ?? r.severity} severity',
              style: text.bodySmall,
            ),
            if (r.createdAt != null)
              Text(' · ${formatDate(r.createdAt)}', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          // Profiles are for signed-in members, as on the website.
          onTap: d.reporter == null || me == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      auth: widget.auth,
                      userId: d.reporter!.id,
                    ),
                  ),
                ),
          child: Row(
            children: [
              UserAvatar(
                name: d.reporterName,
                url: d.reporter?.avatarUrl,
                radius: 14,
              ),
              const SizedBox(width: 8),
              Text('Reported by ${d.reporterName}', style: text.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(d.description, style: text.bodyMedium),
        if (isReporter && d.infoRequestStatus == 'OPEN') ...[
          const SizedBox(height: 16),
          TLCard(
            onTap: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MoreInfoScreen(auth: widget.auth, reportId: r.id),
                  ),
                )
                .then((_) => _refresh()),
            child: const NoticeBanner(
              'Action needed: reviewers need more information. Tap to add it.',
              tone: BannerTone.warning,
            ),
          ),
        ],
        if (isReporter && d.infoRequestStatus == 'ANSWERED') ...[
          const SizedBox(height: 16),
          const NoticeBanner(
            'Your additional information was sent.',
            tone: BannerTone.success,
          ),
        ],
        _reviewSection(d),
        const SectionTitle('Community verification'),
        LinearProgressIndicator(
          value: (r.trustPercentage / 100).clamp(0.0, 1.0),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 6),
        Text(
          '${r.trustPercentage}% trust (needs ${d.thresholdPercent}% and '
          '${d.minimumConfirmations} confirmations) · '
          '${d.confirmVotes} confirm, ${d.disputeVotes} dispute',
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        if (me == null)
          SignInPrompt(
            auth: widget.auth,
            message: 'Sign in to confirm or dispute this report.',
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _voting ? null : () => _vote(true),
                  icon: Icon(
                    d.myVote == true
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                  ),
                  label: const Text('Confirm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _voting ? null : () => _vote(false),
                  icon: Icon(
                    d.myVote == false ? Icons.cancel : Icons.cancel_outlined,
                  ),
                  label: const Text('Dispute'),
                ),
              ),
            ],
          ),
        const SectionTitle('Discussion'),
        if (me == null)
          SignInPrompt(
            auth: widget.auth,
            message: 'Sign in to read and join the discussion.',
          )
        else ...[
          _composer(),
          AsyncView<List<Comment>>(
            future: _comments,
            onRetry: () => setState(() {
              _comments = _loadComments();
            }),
            isEmpty: (l) => l.isEmpty,
            emptyMessage: 'No comments yet.',
            emptyIcon: Icons.chat_bubble_outline,
            builder: (context, list) => _thread(list),
          ),
        ],
      ],
    );
  }

  /// Moderation and authority decisions, and the cleanup this report became.
  Widget _reviewSection(ReportDetail d) {
    final rows = <Widget>[];
    if (d.adminDecision != null && d.adminDecision != 'PENDING') {
      rows.add(
        NoticeBanner(
          'Administrator: ${reviewDecisionLabels[d.adminDecision] ?? d.adminDecision}'
          '${d.moderationComment != null && d.moderationComment!.isNotEmpty ? ' — ${d.moderationComment}' : ''}',
          tone: d.adminDecision == 'REJECTED'
              ? BannerTone.error
              : BannerTone.info,
        ),
      );
    }
    if (d.authorityDecision != null && d.authorityDecision != 'PENDING') {
      rows.add(
        NoticeBanner(
          'Government officer${d.authorityOfficer != null ? ' ${d.authorityOfficer!.fullName}' : ''}: '
          '${reviewDecisionLabels[d.authorityDecision] ?? d.authorityDecision}'
          '${d.authorityComment != null && d.authorityComment!.isNotEmpty ? ' — ${d.authorityComment}' : ''}',
          tone: d.authorityDecision == 'REJECTED'
              ? BannerTone.error
              : BannerTone.success,
        ),
      );
    }
    if (d.projectId != null) {
      rows.add(
        TLCard(
          margin: EdgeInsets.zero,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(
                auth: widget.auth,
                projectId: d.projectId!,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.cleaning_services_outlined, color: TL.tide600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This report became cleanup ${d.projectReference ?? ''}',
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _composer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to ${_replyTo!.author}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _replyTo = null;
                  }),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentCtl,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: _replyTo == null
                      ? 'Add a comment'
                      : 'Write a reply',
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              onPressed: _posting ? null : _post,
              icon: _posting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Widget _thread(List<Comment> all) {
    final tops = all.where((c) => c.parentId == null).toList();
    final replies = <int, List<Comment>>{};
    for (final c in all.where((c) => c.parentId != null)) {
      replies.putIfAbsent(c.parentId!, () => []).add(c);
    }
    return Column(
      children: [
        for (final c in tops) ...[
          _commentTile(c, 0),
          for (final reply in replies[c.id] ?? const <Comment>[])
            _commentTile(reply, 28),
        ],
      ],
    );
  }

  Widget _commentTile(Comment c, double indent) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: 12, left: indent),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    c.author,
                    style: text.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.official) ...[
                  const SizedBox(width: 6),
                  const StatusPill('Official', fg: TL.kelp600, bg: TL.kelp100),
                ],
                const SizedBox(width: 6),
                Text(timeAgo(c.createdAt), style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 2),
            Text(c.body),
            Row(
              children: [
                _ReactionButton(
                  icon: c.myReaction == 'LIKE'
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                  count: c.likeCount,
                  label: 'Like',
                  onTap: () => _react(c, 'LIKE'),
                ),
                _ReactionButton(
                  icon: c.myReaction == 'HEART'
                      ? Icons.favorite
                      : Icons.favorite_border,
                  count: c.heartCount,
                  label: 'Heart',
                  onTap: () => _react(c, 'HEART'),
                ),
                if (c.parentId == null)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => setState(() {
                      _replyTo = c;
                    }),
                    child: const Text('Reply'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(count > 0 ? '$count' : label),
  );
}

/// Photos load from the public evidence URL; videos are listed but not played in-app.
class _EvidenceStrip extends StatelessWidget {
  const _EvidenceStrip({required this.items});
  final List<Evidence> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = items[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(TL.radiusLg),
            child: e.isVideo
                ? Container(
                    width: 300,
                    color: TL.sea900,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Video evidence',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Open it on the website to play',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(
                            AppConfig.mediaUrl(e.url)!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    child: Image.network(
                      AppConfig.mediaUrl(e.url)!,
                      width: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 300,
                        color: TL.sea100,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: TL.sea600,
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
