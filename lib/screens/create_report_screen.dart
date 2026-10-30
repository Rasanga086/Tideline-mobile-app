import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_controller.dart';
import '../core/api_client.dart';
import '../core/format.dart';
import '../core/location.dart';
import '../core/places.dart';
import '../core/uploads.dart';
import '../core/theme.dart';
import '../models/models.dart';

const _severities = [
  ('LOW', 'Low — small, isolated debris'),
  ('MEDIUM', 'Medium — noticeable, spreading'),
  ('HIGH', 'High — large area, harmful materials'),
  ('CRITICAL', 'Critical — active spill or hazard'),
];

// DocumentStorageService: at most 6 evidence files, photos up to 8 MB, JPG/PNG/WebP.
const maxPhotos = 6;

/// Null when [value] is a usable title/description/etc.; otherwise the message to show.
String? requiredText(String? value, String label, int max) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter $label.';
  if (v.length > max) return '$label must be $max characters or fewer.';
  return null;
}

String? validateCoordinate(String? value, String label, double limit) {
  final n = double.tryParse(value?.trim() ?? '');
  if (n == null) return 'Enter a number for $label.';
  if (n < -limit || n > limit) {
    return '$label must be between -${limit.toInt()} and ${limit.toInt()}.';
  }
  return null;
}

/// Null if the file is acceptable to the API, else why not.
String? checkPhoto(String name, int bytes) => checkImage(name, bytes);

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key, required this.auth, ImagePicker? picker})
    : _picker = picker;
  final AuthController auth;
  final ImagePicker? _picker;

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  late final ImagePicker _picker = widget._picker ?? ImagePicker();

  String? _severity;
  String? _province;
  String? _district;
  bool _willLead = true;
  final List<XFile> _photos = [];
  bool _busy = false;
  bool _locating = false;
  String? _locationError;
  String? _error;

  /// Set once the reporter types their own place name, so a captured position won't replace it.
  bool _namedByUser = false;

  @override
  void initState() {
    super.initState();
    final user = widget.auth.user;
    _location.text = user?.city ?? '';
    if (user?.province != null && provinces.contains(user!.province)) {
      _province = user.province;
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _location, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the coordinates from the device and names the place after the nearest town
  /// (as SubmitReport.jsx does). On failure the reason is shown and nothing is guessed.
  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final (lat, lng) = await DeviceLocation.locate();
      if (!mounted) return;
      final nearest = nearestPlace(lat, lng);
      setState(() {
        _lat.text = lat.toStringAsFixed(6);
        _lng.text = lng.toStringAsFixed(6);
        // Only name the place from the town list when it is close by (i.e. in Sri Lanka).
        if (nearest != null && nearest.$2 <= 50) {
          final town = nearest.$1;
          if (!_namedByUser || _location.text.trim().isEmpty) {
            _location.text = town.name;
          }
          _province = town.province;
          _district = town.district;
        }
      });
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPhotos() async {
    final room = maxPhotos - _photos.length;
    if (room <= 0) {
      setState(() => _error = 'You can attach up to $maxPhotos photos.');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(
        limit: room >= 2 ? room : null,
      );
      final problems = <String>[];
      final accepted = <XFile>[];
      for (final f in picked) {
        final problem = checkPhoto(f.name, await f.length());
        if (problem != null) {
          problems.add(problem);
        } else if (_photos.length + accepted.length < maxPhotos) {
          accepted.add(f);
        } else {
          problems.add('Only $maxPhotos photos can be attached.');
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _photos.addAll(accepted);
        _error = problems.isEmpty ? null : problems.join('\n');
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open your photo library.');
      }
    }
  }

  Future<http.MultipartFile> _part(XFile f) async => uploadPart(
    'evidence',
    kIsWeb
        ? PickedUpload(name: f.name, size: 0, bytes: await f.readAsBytes())
        : PickedUpload(name: f.name, path: f.path, size: 0),
  );

  Future<void> _submit() async {
    if (_busy) return; // no duplicate submissions
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = [for (final p in _photos) await _part(p)];
      // Field names and limits follow ReportDtos.CreateReportRequest.
      final json = await widget.auth.api.postMultipart(
        '/api/reports',
        json: {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'severity': _severity,
          'locationName': _location.text.trim(),
          'province': _province,
          'district': _district,
          'latitude': double.parse(_lat.text.trim()),
          'longitude': double.parse(_lng.text.trim()),
          'willLeadCleanup': _willLead,
        },
        files: files,
      );
      final report = Report.fromJson(json as Map<String, dynamic>);
      if (mounted) Navigator.of(context).pop(report);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.status == 413
              ? 'Those files are too large. Photos must be 8 MB or smaller.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not read one of the selected photos.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Report pollution')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TL.coral100,
                    borderRadius: BorderRadius.circular(TL.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: TL.coral700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: TL.coral700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('What did you find?', style: text.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                enabled: !_busy,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => requiredText(v, 'a title', 120),
              ),
              TextFormField(
                controller: _description,
                enabled: !_busy,
                maxLength: 2000,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: (v) => requiredText(v, 'a description', 2000),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: [
                  for (final (value, label) in _severities)
                    DropdownMenuItem(
                      value: value,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _busy ? null : (v) => setState(() => _severity = v),
                validator: (v) => v == null ? 'Choose a severity.' : null,
              ),
              const SizedBox(height: 24),
              Text('Where is it?', style: text.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _location,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Location name'),
                validator: (v) => requiredText(v, 'a location name', 255),
                onChanged: (_) => _namedByUser = true,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy || _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _locating ? 'Locating…' : 'Use my current location',
                ),
              ),
              if (_locationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _locationError!,
                  style: const TextStyle(color: TL.coral700, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // Keyed so a captured location can change the selection.
                key: ValueKey('province-$_province'),
                initialValue: _province,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Province (optional)',
                ),
                items: [
                  for (final p in provinces)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _province = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('district-$_district'),
                initialValue: _district,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'District (optional)',
                ),
                items: [
                  for (final d in districts)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _district = v),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lat,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: '7.2083',
                      ),
                      validator: (v) => validateCoordinate(v, 'Latitude', 90),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lng,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '79.8358',
                      ),
                      validator: (v) => validateCoordinate(v, 'Longitude', 180),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Reports are matched to nearby volunteers by distance, so use the site’s coordinates.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 24),
              Text('Photos', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Optional. Up to $maxPhotos photos (JPG, PNG or WebP, 8 MB each).',
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(TL.radiusMd),
                          child: Image(
                            image: kIsWeb
                                ? NetworkImage(_photos[i].path)
                                : FileImage(File(_photos[i].path)),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: TL.sea100,
                              child: const Icon(
                                Icons.image_outlined,
                                color: TL.sea600,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: _busy
                                ? null
                                : () => setState(() => _photos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _photos.isEmpty
                        ? 'Add photos'
                        : 'Add more (${_photos.length}/$maxPhotos)',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _willLead,
                onChanged: _busy ? null : (v) => setState(() => _willLead = v),
                title: const Text('I will lead the cleanup'),
                subtitle: const Text(
                  'Turn off and anyone who joins the cleanup can post its progress.',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
