import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'projects_screen.dart';

/// Another member's public profile: GET /api/users/{id} (no email, phone or saved location).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.auth,
    required this.userId,
  });
  final AuthController auth;
  final int userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<PublicProfile> _future = _load();

  Future<PublicProfile> _load() async => PublicProfile.fromJson(
    await widget.auth.api.get('/api/users/${widget.userId}')
        as Map<String, dynamic>,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncView<PublicProfile>(
            future: _future,
            onRetry: () => setState(() {
              _future = _load();
            }),
            builder: (context, p) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: UserAvatar(
                    name: p.fullName,
                    url: p.avatarUrl,
                    radius: 44,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  p.fullName,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    StatusPill(
                      roleLabels[p.role] ?? p.role,
                      fg: TL.tide700,
                      bg: TL.tide100,
                    ),
                    if (p.verified && p.role != 'CITIZEN')
                      const StatusPill(
                        'Verified',
                        fg: TL.kelp600,
                        bg: TL.kelp100,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TLCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoRow(
                        Icons.business_outlined,
                        'Organisation',
                        p.organizationName,
                      ),
                      InfoRow(
                        Icons.place_outlined,
                        'Location',
                        [
                          p.city,
                          p.province,
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                      ),
                      InfoRow(
                        Icons.verified_outlined,
                        'Certification',
                        certificationLabels[p.certificationLevel],
                      ),
                      InfoRow(
                        Icons.timer_outlined,
                        'Experience',
                        p.experienceYears == null
                            ? null
                            : '${p.experienceYears} years',
                      ),
                      InfoRow(
                        Icons.cleaning_services_outlined,
                        'Cleanups completed',
                        p.completedProjects?.toString(),
                      ),
                      InfoRow(
                        Icons.star_outline,
                        'Organiser rating',
                        p.averageMark == null
                            ? null
                            : '${p.averageMark!.toStringAsFixed(1)} / 5',
                      ),
                      InfoRow(
                        Icons.flag_outlined,
                        'Reports submitted',
                        '${p.reportsSubmitted}',
                      ),
                      InfoRow(
                        Icons.event_outlined,
                        'Member since',
                        formatDate(p.memberSince),
                      ),
                    ],
                  ),
                ),
                if (p.ownedProjects.isNotEmpty) ...[
                  const SectionTitle('Cleanups led'),
                  for (final o in p.ownedProjects)
                    TLCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailScreen(
                            auth: widget.auth,
                            projectId: o.id,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(o.title, style: text.titleMedium),
                          ),
                          StatusPill(humanize(o.status)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
