import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/alerts_controller.dart';
import '../widgets/common.dart';
import '../widgets/tab_history.dart';
import 'admin_users_screen.dart';
import 'admin_verifications_screen.dart';
import 'alerts_screen.dart';
import 'analytics_screen.dart';
import 'console_queue_screen.dart';
import 'home_shell.dart';
import 'profile_screen.dart';
import 'projects_screen.dart';

/// Home for administrators and government officers, mirroring the website's AuthorityShell:
/// Review queue, Cleanups, Alerts, Analytics, and a More tab (Verifications and Users are
/// administrator-only, as on the website and in the backend's @PreAuthorize rules).
class ConsoleShell extends StatefulWidget {
  const ConsoleShell({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ConsoleShell> createState() => _ConsoleShellState();
}

class _ConsoleShellState extends State<ConsoleShell> with TabHistory {
  late final AlertsController _alerts = AlertsController(widget.auth.api);

  @override
  void onTabShown(int index) {
    if (index == 2) _alerts.refresh();
  }

  @override
  void dispose() {
    _alerts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return tabBackScope(
      child: Scaffold(
        body: IndexedStack(
          index: tabIndex,
          children: [
            ConsoleQueueScreen(auth: widget.auth),
            ProjectsScreen(
              auth: widget.auth,
              onBack: canGoBackTab ? backTab : null,
            ),
            AlertsScreen(auth: widget.auth, alerts: _alerts, console: true),
            AnalyticsScreen(auth: widget.auth),
            _ConsoleMore(auth: widget.auth),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _alerts,
          builder: (context, _) => NavigationBar(
            selectedIndex: tabIndex,
            onDestinationSelected: selectTab,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Queue',
              ),
              const NavigationDestination(
                icon: Icon(Icons.cleaning_services_outlined),
                selectedIcon: Icon(Icons.cleaning_services),
                label: 'Cleanups',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _alerts.unread > 0,
                  label: Text(_alerts.unread > 9 ? '9+' : '${_alerts.unread}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _alerts.unread > 0,
                  label: Text(_alerts.unread > 9 ? '9+' : '${_alerts.unread}'),
                  child: const Icon(Icons.notifications),
                ),
                label: 'Alerts',
              ),
              const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Analytics',
              ),
              const NavigationDestination(
                icon: Icon(Icons.menu),
                selectedIcon: Icon(Icons.menu_open),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsoleMore extends StatelessWidget {
  const _ConsoleMore({required this.auth});
  final AuthController auth;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = auth.user!;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          user.isAuthority
              ? 'Government officer console'
              : 'Administrator console',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TLCard(
            onTap: () => _push(context, ProfileScreen(auth: auth)),
            child: Row(
              children: [
                UserAvatar(
                  name: user.fullName,
                  url: user.avatarUrl,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: text.titleMedium),
                      Text(user.roleText, style: text.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          if (user.isAdmin) ...[
            const SectionTitle('Administration'),
            TLCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Verifications'),
                    subtitle: const Text(
                      'Divers, organisations and officials awaiting approval',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _push(context, AdminVerificationsScreen(auth: auth)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Users'),
                    subtitle: const Text(
                      'Search accounts and suspend or restore them',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(context, AdminUsersScreen(auth: auth)),
                  ),
                ],
              ),
            ),
          ],
          const SectionTitle('Community'),
          TLCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.waves),
              title: const Text('Community app'),
              subtitle: const Text(
                'Browse the report feed and opportunities as a member',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(context, HomeShell(auth: auth)),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Sign out?',
                message: 'You will need to sign in again.',
                confirmLabel: 'Sign out',
              );
              if (ok) await auth.logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
