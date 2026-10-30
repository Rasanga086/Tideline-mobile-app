import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/uploads.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/upload_picker.dart';

/// Where the reporter answers a reviewer's request for more information:
/// GET /api/reports/{id}/info-requests, then multipart POST
/// /api/reports/{id}/info-requests/{requestId}/response with a `data` {description}
/// part and `photos` files. Mirrors pages/volunteer/MoreInfo.jsx.
class MoreInfoScreen extends StatefulWidget {
  const MoreInfoScreen({super.key, required this.auth, required this.reportId});
  final AuthController auth;
  final int reportId;

  @override
  State<MoreInfoScreen> createState() => _MoreInfoScreenState();
}

class _MoreInfoScreenState extends State<MoreInfoScreen> {
  late Future<List<InfoRequest>> _future = _load();
  final _description = TextEditingController();
  final List<PickedUpload> _photos = [];
  bool _busy = false;
  bool _sent = false;
  String? _error;

  Future<List<InfoRequest>> _load() async =>
      (await widget.auth.api.get(
                '/api/reports/${widget.reportId}/info-requests',
              )
              as List)
          .map((e) => InfoRequest.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(InfoRequest request) async {
    final text = _description.text.trim();
    if (_busy) return;
    if (text.isEmpty) {
      setState(() {
        _error = 'Describe the information the reviewers asked for.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.api.postMultipart(
        '/api/reports/${widget.reportId}/info-requests/${request.id}/response',
        json: {'description': text},
        files: [for (final p in _photos) await uploadPart('photos', p)],
      );
      if (mounted) {
        setState(() {
          _sent = true;
        });
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
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('More information')),
      body: _sent
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 56,
                      color: Color(0xFF3E7B2F),
                    ),
                    const SizedBox(height: 12),
                    Text('Information sent', style: text.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      "Thanks — it's attached to your report for the reviewers. You'll get an alert when they decide.",
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to your report'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AsyncView<List<InfoRequest>>(
                  future: _future,
                  onRetry: () => setState(() {
                    _future = _load();
                  }),
                  builder: (context, requests) {
                    final open = requests
                        .where((r) => r.status == 'OPEN')
                        .firstOrNull;
                    if (open == null) {
                      return const EmptyState(
                        message: 'Nothing is waiting on you for this report.',
                        icon: Icons.check_circle_outline,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          NoticeBanner(_error!),
                          const SizedBox(height: 12),
                        ],
                        TLCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${open.requestedBy ?? 'A reviewer'} asked${open.createdAt != null ? ' · ${formatDate(open.createdAt)}' : ''}',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Text(open.message, style: text.bodyMedium),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _description,
                          enabled: !_busy,
                          maxLength: 2000,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Your answer',
                            alignLabelWithHint: true,
                          ),
                        ),
                        UploadPicker(
                          label: 'Photos (optional)',
                          hint: 'JPG, PNG or WebP, up to 8 MB each (max 6).',
                          files: _photos,
                          pick: pickImages,
                          check: (n, s) => checkImage(n, s),
                          max: 6,
                          enabled: !_busy,
                          icon: Icons.image_outlined,
                        ),
                        const SizedBox(height: 12),
                        BusyButton(
                          label: 'Send information',
                          icon: Icons.send,
                          busy: _busy,
                          onPressed: () => _submit(open),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
