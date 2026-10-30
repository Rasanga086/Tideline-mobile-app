import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/location.dart';
import '../core/places.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'create_report_screen.dart' show validateCoordinate;

/// Edits the signed-in user: PUT /api/users/me (and PUT /api/users/me/diver-profile for divers).
/// The API treats absent fields as "unchanged", so only edited values are sent.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.auth.user!.firstName);
  late final _last = TextEditingController(text: widget.auth.user!.lastName);
  late final _phone = TextEditingController(text: widget.auth.user!.phone);
  late final _city = TextEditingController(text: widget.auth.user!.city);
  late final _lat = TextEditingController(
    text: widget.auth.user!.latitude?.toString(),
  );
  late final _lng = TextEditingController(
    text: widget.auth.user!.longitude?.toString(),
  );
  late final _orgName = TextEditingController(
    text: widget.auth.user!.organizationName,
  );
  late final _experience = TextEditingController(
    text: widget.auth.user!.diverProfile?.experienceYears?.toString(),
  );
  late final _equipment = TextEditingController(
    text: widget.auth.user!.diverProfile?.equipment,
  );

  late String? _province = provinces.contains(widget.auth.user!.province)
      ? widget.auth.user!.province
      : null;
  late bool _alerts = widget.auth.user!.availableForAlerts;
  late String? _orgType = widget.auth.user!.organizationType;
  late String? _certification =
      widget.auth.user!.diverProfile?.certificationLevel;
  late final Set<String> _regions = {
    ...?widget.auth.user!.diverProfile?.preferredRegions,
  };
  bool _busy = false;
  bool _locating = false;
  String? _locationError;
  String? _error;

  /// Profile.jsx "Use my current location": fills the coordinates, and the town and province
  /// when they are empty. The position is only saved when the user taps Save changes.
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
        if (nearest != null && nearest.$2 <= 50) {
          if (_city.text.trim().isEmpty) _city.text = nearest.$1.name;
          _province ??= nearest.$1.province;
        }
      });
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _phone,
      _city,
      _lat,
      _lng,
      _orgName,
      _experience,
      _equipment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optionalCoordinate(String? v, String label, double limit) =>
      (v == null || v.trim().isEmpty)
      ? null
      : validateCoordinate(v, label, limit);

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final user = widget.auth.user!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? text(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      // Field names follow UserDtos.UpdateProfileRequest; null means "leave unchanged".
      await widget.auth.updateProfile({
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'phone': text(_phone),
        'province': _province,
        'city': text(_city),
        'latitude': double.tryParse(_lat.text.trim()),
        'longitude': double.tryParse(_lng.text.trim()),
        'availableForAlerts': _alerts,
        if (user.isOrganization || user.isOfficial)
          'organizationName': text(_orgName),
        if (user.isOrganization) 'organizationType': _orgType,
      });
      if (user.isDiver) {
        await widget.auth.updateDiverProfile({
          'certificationLevel': _certification,
          'experienceYears': int.tryParse(_experience.text.trim()),
          'equipment': text(_equipment),
          'preferredRegions': _regions.toList(),
        });
      }
      if (!mounted) return;
      showToast(context, 'Profile saved.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                NoticeBanner(_error!),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _first,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: (v) => validateName(v, 'first name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _last,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (v) => validateName(v, 'last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              if (user.isOrganization || user.isOfficial) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _orgName,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: user.isOrganization
                        ? 'Organisation name'
                        : 'Department or agency',
                  ),
                ),
              ],
              if (user.isOrganization) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _orgType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Organisation type',
                  ),
                  items: [
                    for (final e in organizationLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _orgType = v),
                ),
              ],
              const SectionTitle('Location'),
              DropdownButtonFormField<String>(
                key: ValueKey('province-$_province'),
                initialValue: _province,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Province'),
                items: [
                  for (final p in provinces)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _province = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _city,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Town or city'),
              ),
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
                  _locating
                      ? 'Locating…'
                      : _lat.text.isNotEmpty
                      ? 'Update to my current location'
                      : 'Use my current location',
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
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: (v) => _optionalCoordinate(v, 'Latitude', 90),
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
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: (v) =>
                          _optionalCoordinate(v, 'Longitude', 180),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Your saved position is used to alert you about reports and cleanups nearby.',
                style: text.bodySmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _alerts,
                onChanged: _busy ? null : (v) => setState(() => _alerts = v),
                title: const Text('Available for nearby alerts'),
                subtitle: const Text(
                  'Get alerts when a report or cleanup needs people near you.',
                ),
              ),
              if (user.isDiver) ...[
                const SectionTitle('Diving profile'),
                DropdownButtonFormField<String>(
                  initialValue: _certification,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Certification level',
                  ),
                  items: [
                    for (final e in certificationLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _certification = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _experience,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Years of experience',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    return n == null || n < 0 || n > 80
                        ? 'Enter a whole number of years.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _equipment,
                  enabled: !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Equipment you own',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Preferred working regions', style: text.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in provinces)
                      FilterChip(
                        label: Text(p),
                        selected: _regions.contains(p),
                        onSelected: _busy
                            ? null
                            : (on) => setState(
                                () => on ? _regions.add(p) : _regions.remove(p),
                              ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              BusyButton(label: 'Save changes', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
