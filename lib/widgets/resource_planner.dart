import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// A government officer revises what they committed to a project when they approved it:
/// PUT /api/projects/{id}/resources {volunteersNeeded, diversNeeded, equipment, publish}.
/// Rules mirror buildResources() on the website: at least one volunteer, and every
/// equipment line needs a name and a quantity of at least 1.
class ResourcePlanner extends StatefulWidget {
  const ResourcePlanner({
    super.key,
    required this.auth,
    required this.project,
    required this.onSaved,
  });
  final AuthController auth;
  final Project project;
  final void Function(Project) onSaved;

  @override
  State<ResourcePlanner> createState() => _ResourcePlannerState();
}

class _EquipmentLine {
  _EquipmentLine(String name, String qty)
    : name = TextEditingController(text: name),
      quantity = TextEditingController(text: qty);
  final TextEditingController name;
  final TextEditingController quantity;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

/// Builds the request body from typed values, or returns the message to show instead.
({Map<String, Object>? payload, String? error}) buildResources({
  required String volunteers,
  required String divers,
  required List<(String, String)> equipmentLines,
}) {
  final equipment = <Map<String, Object>>[];
  for (final (name, raw) in equipmentLines) {
    final n = name.trim();
    final q = raw.trim();
    if (n.isEmpty && q.isEmpty) continue;
    final qty = int.tryParse(q);
    if (n.isEmpty || qty == null || qty < 1) {
      return (
        payload: null,
        error: 'Give every equipment item a name and a quantity of at least 1.',
      );
    }
    equipment.add({'name': n, 'quantity': qty});
  }
  final v = volunteers.trim().isEmpty ? 0 : int.tryParse(volunteers.trim());
  final d = divers.trim().isEmpty ? 0 : int.tryParse(divers.trim());
  if (v == null || d == null || v < 0 || d < 0) {
    return (payload: null, error: 'Enter whole numbers for the people needed.');
  }
  if (v < 1) {
    return (
      payload: null,
      error: 'Every cleanup needs at least one volunteer.',
    );
  }
  return (
    payload: {'volunteersNeeded': v, 'diversNeeded': d, 'equipment': equipment},
    error: null,
  );
}

class _ResourcePlannerState extends State<ResourcePlanner> {
  late final _volunteers = TextEditingController(
    text: widget.project.volunteersNeeded?.toString() ?? '',
  );
  late final _divers = TextEditingController(
    text: widget.project.diversNeeded?.toString() ?? '',
  );
  late final List<_EquipmentLine> _lines = [
    for (final e in widget.project.equipment)
      _EquipmentLine(e.name, '${e.quantity}'),
  ];
  String? _busy;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _volunteers.dispose();
    _divers.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _save(bool publish) async {
    if (_busy != null) return;
    final built = buildResources(
      volunteers: _volunteers.text,
      divers: _divers.text,
      equipmentLines: [for (final l in _lines) (l.name.text, l.quantity.text)],
    );
    if (built.payload == null) {
      setState(() {
        _error = built.error;
        _notice = null;
      });
      return;
    }
    setState(() {
      _busy = publish ? 'publish' : 'draft';
      _error = null;
      _notice = null;
    });
    try {
      final updated = Project.fromJson(
        await widget.auth.api.put(
              '/api/projects/${widget.project.id}/resources',
              body: {...built.payload!, 'publish': publish},
            )
            as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(
        () => _notice = publish
            ? 'Resources updated and shown on the project.'
            : 'Draft saved.',
      );
      widget.onSaved(updated);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalized = widget.project.resourcesFinalized;
    final comment = widget.project.approvalComment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Assign resources',
          trailing: StatusPill(
            finalized ? 'Finalized' : 'Not finalized',
            fg: finalized ? TL.kelp600 : TL.buoy600,
            bg: finalized ? TL.kelp100 : TL.buoy100,
          ),
        ),
        TLCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (comment != null && comment.isNotEmpty) ...[
                NoticeBanner(
                  'Official comment: $comment',
                  tone: BannerTone.info,
                ),
                const SizedBox(height: 12),
              ],
              if (_notice != null) ...[
                NoticeBanner(_notice!, tone: BannerTone.success),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                NoticeBanner(_error!),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _volunteers,
                      enabled: _busy == null,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Volunteers needed',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _divers,
                      enabled: _busy == null,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Divers needed',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Equipment', style: Theme.of(context).textTheme.titleMedium),
              for (var i = 0; i < _lines.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _lines[i].name,
                          enabled: _busy == null,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Item',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _lines[i].quantity,
                          enabled: _busy == null,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove item',
                        icon: const Icon(Icons.close),
                        onPressed: _busy == null
                            ? () => setState(() => _lines.removeAt(i).dispose())
                            : null,
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy == null && _lines.length < 30
                      ? () => setState(() => _lines.add(_EquipmentLine('', '')))
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add equipment'),
                ),
              ),
              const SizedBox(height: 8),
              BusyButton(
                label: _busy == 'publish' ? 'Saving…' : 'Assign resources',
                icon: Icons.check,
                busy: _busy != null,
                onPressed: () => _save(true),
              ),
              if (!finalized) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy != null ? null : () => _save(false),
                  child: Text(_busy == 'draft' ? 'Saving…' : 'Save draft'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
