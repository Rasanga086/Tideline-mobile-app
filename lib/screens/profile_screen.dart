import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/uploads.dart';
import '../widgets/common.dart';
import '../widgets/upload_picker.dart';
import 'edit_profile_screen.dart';
import 'projects_screen.dart';

/// The signed-in user's profile (GET /api/users/me), with editing and avatar upload.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _avatarBusy = false;

  AuthController get auth => widget.auth;

  Future<void> _refresh() async {
    try {
      await auth.refresh();
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    }
  }

  /// PUT /api/users/me/avatar: one JPG/PNG/WebP photo up to 5 MB, sent as the `photo` part.
  Future<void> _changeAvatar() async {
    if (_avatarBusy) return;
    try {
      final picked = await pickImages(multiple: false);
      if (picked.isEmpty) return;
      final problem = checkImage(
        picked.first.name,
        picked.first.size,
        maxBytes: maxAvatarBytes,
      );
      if (problem != null) {
        if (mounted) showToast(context, problem);
        return;
      }
      setState(() => _avatarBusy = true);
      await auth.uploadAvatar(await uploadPart('photo', picked.first));
      if (mounted) showToast(context, 'Profile photo updated.');
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _avatarBusy = true);
    try {
      await auth.removeAvatar();
      if (mounted) showToast(context, 'Profile photo removed.');
    } catch (e) {
      if (mounted) showToast(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await confirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to vote, comment or report.',
      confirmLabel: 'Sign out',
    );
    if (ok) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final user = auth.user;
        final text = Theme.of(context).textTheme;
        if (user == null) return const SizedBox.shrink();
        final diver = user.diverProfile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(auth: auth),
                  ),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      UserAvatar(
                        name: user.fullName,
                        url: user.avatarUrl,
                        radius: 44,
                      ),
                      if (_avatarBusy)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        PopupMenuButton<String>(
                          tooltip: 'Profile photo',
                          icon: const CircleAvatar(
                            radius: 14,
                            backgroundColor: TL.tide600,
                            child: Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          onSelected: (v) =>
                              v == 'change' ? _changeAvatar() : _removeAvatar(),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'change',
                              child: Text('Choose a photo'),
                            ),
                            if (user.avatarUrl != null)
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove photo'),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 6),
                Center(
                  child: StatusPill(
                    user.roleText,
                    fg: TL.tide700,
                    bg: TL.tide100,
                  ),
                ),
                if (user.pendingReview) ...[
                  const SizedBox(height: 16),
                  const NoticeBanner(
                    'An administrator is still verifying your account.',
                    tone: BannerTone.warning,
                  ),
                ],
                const SizedBox(height: 20),
                TLCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoRow(Icons.mail_outline, 'Email', user.email),
                      InfoRow(Icons.phone_outlined, 'Phone', user.phone),
                      InfoRow(
                        Icons.business_outlined,
                        'Organisation',
                        user.organizationName,
                      ),
                      InfoRow(
                        Icons.category_outlined,
                        'Type',
                        organizationLabels[user.organizationType],
                      ),
                      InfoRow(Icons.link, 'Website', user.websiteUrl),
                      InfoRow(
                        Icons.place_outlined,
                        'Location',
                        [
                          user.city,
                          user.province,
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                      ),
                      InfoRow(
                        Icons.notifications_outlined,
                        'Nearby alerts',
                        user.availableForAlerts ? 'Available' : 'Off',
                      ),
                      if (user.averageMark != null)
                        InfoRow(
                          Icons.star_outline,
                          'Organiser rating',
                          '${user.averageMark!.toStringAsFixed(1)} / 5 · ${user.markedCleanups ?? 0} cleanups',
                        ),
                    ],
                  ),
                ),
                if (diver != null) ...[
                  const SectionTitle('Diving profile'),
                  TLCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        InfoRow(
                          Icons.verified_outlined,
                          'Certification',
                          certificationLabels[diver.certificationLevel],
                        ),
                        InfoRow(
                          Icons.timer_outlined,
                          'Experience',
                          diver.experienceYears == null
                              ? null
                              : '${diver.experienceYears} years',
                        ),
                        InfoRow(
                          Icons.construction_outlined,
                          'Equipment',
                          diver.equipment,
                        ),
                        InfoRow(
                          Icons.map_outlined,
                          'Preferred regions',
                          diver.preferredRegions.isEmpty
                              ? null
                              : diver.preferredRegions.join(', '),
                        ),
                      ],
                    ),
                  ),
                ],
                if (user.ownedProjects.isNotEmpty) ...[
                  const SectionTitle('Cleanups you lead'),
                  for (final p in user.ownedProjects)
                    TLCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailScreen(auth: auth, projectId: p.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(p.title, style: text.titleMedium),
                          ),
                          StatusPill(humanize(p.status)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
