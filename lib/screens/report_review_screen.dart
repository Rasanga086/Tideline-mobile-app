import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';
import 'project_detail_screen.dart';
import 'report_detail_screen.dart';
import 'user_profile_screen.dart';

/// Console review of one report. Administrators approve (send to the officer), reject or ask
/// for more information; government officers decide on escalated reports (approval creates the
/// cleanup project). Role rules mirror pages/authority/ReportReview.jsx and the backend's
/// @PreAuthorize: POST /moderation is ADMIN-only, POST /authority-decision is AUTHORITY-only.
class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({
    super.key,
    required this.auth,
    required this.reportId,
  });
  final AuthController auth;
  final int reportId;

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  late Future<ReportDetail> _detail = _load();
  late Future<List<InfoRequest>> _info = _loadInfo();
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;

  String get _path => '/api/reports/${widget.reportId}';
  AppUser get _me => widget.auth.user!;

  Future<ReportDetail> _load() async => ReportDetail.fromJson(
    await widget.auth.api.get(_path) as Map<String, dynamic>,
  );

  Future<List<InfoRequest>> _loadInfo() async =>
      (await widget.auth.api.get('$_path/info-requests') as List)
          .map((e) => InfoRequest.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(
    String endpoint,
    String decision,
    String Function(ReportDetail) message,
  ) async {
    if (_busy) return;
    final comment = _comment.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final updated = ReportDetail.fromJson(
        await widget.auth.api.post(
              '$_path/$endpoint',
              body: {
                'decision': decision,
                'comment': comment.isEmpty ? null : comment,
              },
            )
            as Map<String, dynamic>,
      );
      if (!mounted) return;
      if (updated.projectId != null) {
        // The report is a project now — carry on from the project page.
        showToast(context, message(updated));
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              auth: widget.auth,
              projectId: updated.projectId!,
            ),
          ),
        );
        return;
      }
      setState(() {
        _detail = Future.value(updated);
        _info = _loadInfo();
        _notice = message(updated);
        _comment.clear();
      });
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

  Future<void> _reject(bool asOfficer) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null || !mounted) return;
    _comment.text = reason;
    await _run(
      asOfficer ? 'authority-decision' : 'moderation',
      'REJECTED',
      (_) => asOfficer
          ? 'Report rejected. The reporter and administrators have been notified.'
          : 'Report rejected. The reporter has been notified.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review report')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _detail = _load();
            _info = _loadInfo();
          });
          try {
            await _detail;
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            AsyncView<ReportDetail>(
              future: _detail,
              onRetry: () => setState(() {
                _detail = _load();
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
    final isAdmin = _me.isAdmin;
    final isAuthority = _me.isAuthority;
    final canModerate =
        isAdmin &&
        const ['PENDING', 'VERIFYING', 'VERIFIED'].contains(r.status);
    final canDecide = isAuthority && r.status == 'ESCALATED';
    final verified = r.status == 'VERIFIED';
    final waiting = d.infoRequestStatus == 'OPEN';
    final hasComment = _comment.text.trim().isNotEmpty;
    final (statusLabel, statusFg, statusBg) = reportStatusStyle(r.status);
    final cover = AppConfig.mediaUrl(r.coverUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              r.reference,
              style: const TextStyle(
                fontFamily: TL.fontMono,
                color: TL.textMuted,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            StatusPill(statusLabel, fg: statusFg, bg: statusBg),
          ],
        ),
        const SizedBox(height: 12),
        if (_notice != null) ...[
          NoticeBanner(_notice!, tone: BannerTone.success),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          NoticeBanner(_error!),
          const SizedBox(height: 12),
        ],
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
        Text(r.title, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [
            r.locationLine,
            if (d.latitude != null && d.longitude != null)
              '${d.latitude!.toStringAsFixed(4)}, ${d.longitude!.toStringAsFixed(4)}',
          ].where((s) => s.isNotEmpty).join(' · '),
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(d.description, style: text.bodyMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: d.reporter == null
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
              Expanded(
                child: Text(
                  'Reported by ${d.reporterName} · ${formatDate(r.createdAt)}',
                  style: text.bodySmall?.copyWith(color: TL.tide700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ReportDetailScreen(auth: widget.auth, reportId: r.id),
            ),
          ),
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Open evidence and discussion'),
        ),
        const SectionTitle('Community verification'),
        LinearProgressIndicator(
          value: (r.trustPercentage / 100).clamp(0.0, 1.0),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 6),
        Text(
          '${r.trustPercentage}% trust (needs ${d.thresholdPercent}% and ${d.minimumConfirmations} '
          'confirmations) · ${d.confirmVotes} confirm, ${d.disputeVotes} dispute',
          style: text.bodySmall,
        ),
        const SectionTitle('Review status'),
        _reviewLine(
          'Administrator',
          d.adminDecision,
          d.moderationComment,
          null,
        ),
        const SizedBox(height: 8),
        _reviewLine(
          'Government officer',
          d.authorityDecision,
          d.authorityComment,
          d.authorityOfficer?.fullName,
        ),
        if (isAdmin && r.status == 'ESCALATED') ...[
          const SizedBox(height: 12),
          const NoticeBanner(
            'With the government officer. Nothing more for you to do until they approve, reject or ask for more detail.',
            tone: BannerTone.info,
          ),
        ],
        if (isAuthority &&
            r.status != 'ESCALATED' &&
            d.projectId == null &&
            d.authorityDecision == null) ...[
          const SizedBox(height: 12),
          const NoticeBanner(
            'Not sent to the government officer yet. An administrator has to approve this report before you can decide on it.',
            tone: BannerTone.info,
          ),
        ],
        if (d.projectId != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(
                  auth: widget.auth,
                  projectId: d.projectId!,
                ),
              ),
            ),
            icon: const Icon(Icons.cleaning_services_outlined),
            label: Text('Open cleanup ${d.projectReference ?? ''}'),
          ),
        ],
        if (canModerate || canDecide) ...[
          SectionTitle(
            canDecide
                ? 'Your decision as the government officer'
                : 'Your review as administrator',
          ),
          Text(
            canDecide
                ? 'Approving creates the cleanup project, with ${d.reporterName} as project owner.'
                : 'Approving sends the report to the government officer for a decision.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            enabled: !_busy,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Official comment',
              alignLabelWithHint: true,
              helperText: canDecide
                  ? 'Required for every decision — the reporter and administrators see it.'
                  : 'Required to request more information or reject — the reporter sees it.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          if (canModerate) ...[
            BusyButton(
              label: 'Approve and send to officer',
              icon: Icons.flag_outlined,
              busy: _busy,
              onPressed: verified
                  ? () => _run(
                      'moderation',
                      'APPROVED',
                      (_) =>
                          'Approved. The report is with the government officer, who has been alerted.',
                    )
                  : null,
            ),
            if (!verified)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Approval waits for the community confirmations.',
                  style: text.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy || !hasComment || !verified || waiting
                  ? null
                  : () => _run(
                      'moderation',
                      'MORE_INFO_REQUESTED',
                      (_) =>
                          'More information requested. The reporter has a critical alert.',
                    ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Request more info'),
            ),
          ] else ...[
            BusyButton(
              label: 'Approve and create project',
              icon: Icons.verified_user_outlined,
              busy: _busy,
              onPressed: hasComment
                  ? () => _run(
                      'authority-decision',
                      'APPROVED',
                      (u) =>
                          'Approved. Project ${u.projectReference ?? ''} has been created. Assign its resources next.',
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy || !hasComment || waiting
                  ? null
                  : () => _run(
                      'authority-decision',
                      'MORE_INFO_REQUESTED',
                      (_) =>
                          'More information requested. The reporter has a critical alert.',
                    ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Request more info'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: TL.coral700,
            ),
            onPressed: _busy ? null : () => _reject(canDecide),
            icon: const Icon(Icons.close),
            label: const Text('Reject report'),
          ),
        ],
        const SectionTitle('Additional information'),
        AsyncView<List<InfoRequest>>(
          future: _info,
          onRetry: () => setState(() {
            _info = _loadInfo();
          }),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.mark_chat_read_outlined,
          emptyMessage: 'No information has been requested for this report.',
          builder: (context, list) => Column(
            children: [for (final i in list) _infoCard(i, d.reporterName)],
          ),
        ),
      ],
    );
  }

  Widget _reviewLine(
    String who,
    String? decision,
    String? comment,
    String? name,
  ) {
    final label = decision == null
        ? 'Not reviewed yet'
        : (reviewDecisionLabels[decision] ?? decision);
    final (fg, bg) = switch (decision) {
      'APPROVED' => (TL.kelp600, TL.kelp100),
      'REJECTED' => (TL.coral700, TL.coral100),
      'MORE_INFO_REQUESTED' => (TL.sea600, TL.sea100),
      _ => (TL.gray600, TL.gray100),
    };
    return TLCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name == null ? who : '$who · $name',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              StatusPill(label, fg: fg, bg: bg),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(comment),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(InfoRequest i, String reporter) {
    final text = Theme.of(context).textTheme;
    final answered = i.status == 'ANSWERED';
    return TLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${i.requestedBy ?? 'A reviewer'} asked · ${formatDate(i.createdAt)}',
                  style: text.bodySmall,
                ),
              ),
              StatusPill(
                answered ? 'Answered' : 'Waiting for reporter',
                fg: answered ? TL.kelp600 : TL.buoy600,
                bg: answered ? TL.kelp100 : TL.buoy100,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(i.message),
          if (answered) ...[
            const Divider(height: 24),
            Text(
              '$reporter replied · ${formatDate(i.respondedAt)}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(i.responseText ?? ''),
            if (i.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: i.attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, k) {
                    final (url, name, type) = i.attachments[k];
                    // Attachments are private: the request must carry the session token.
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(TL.radiusMd),
                      child: type.startsWith('image/')
                          ? Image.network(
                              AppConfig.mediaUrl(url)!,
                              width: 140,
                              fit: BoxFit.cover,
                              headers: widget.auth.api.authHeaders,
                              errorBuilder: (_, _, _) =>
                                  _attachmentFallback(name),
                            )
                          : _attachmentFallback(name),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _attachmentFallback(String name) => Container(
    width: 140,
    color: TL.sea100,
    padding: const EdgeInsets.all(8),
    child: Center(
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject this report?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The reporter is notified with your reason, and the report is closed.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          maxLength: 1000,
          maxLines: 4,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
      ],
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
        child: const Text('Reject'),
      ),
    ],
  );
}
