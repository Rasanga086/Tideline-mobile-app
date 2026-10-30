import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/alerts_controller.dart';
import '../widgets/brand.dart';
import '../widgets/tab_history.dart';
import 'alerts_screen.dart';
import 'feed_screen.dart';
import 'opportunities_screen.dart';
import 'profile_screen.dart';
import 'projects_screen.dart';

/// Signed-in member home. Tabs mirror the website's VolunteerShell (Feed, Cleanups, Alerts,
/// Opportunities, Profile) and are kept alive in an IndexedStack so switching tabs does not
/// reload the feed or lose scroll/filter state.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth});
  final AuthController auth;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TabHistory {
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
            FeedScreen(auth: widget.auth),
            ProjectsScreen(
              auth: widget.auth,
              onBack: canGoBackTab ? backTab : null,
            ),
            AlertsScreen(auth: widget.auth, alerts: _alerts),
            OpportunitiesScreen(auth: widget.auth),
            ProfileScreen(auth: widget.auth),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _alerts,
          builder: (context, _) => NavigationBar(
            selectedIndex: tabIndex,
            onDestinationSelected: selectTab,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.waves_outlined),
                selectedIcon: Icon(Icons.waves),
                label: 'Feed',
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
                icon: Icon(Icons.anchor_outlined),
                selectedIcon: Icon(Icons.anchor),
                label: 'Opportunities',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a visitor can browse without an account, as on the website: the report feed and
/// cleanup projects (both public in the API). Everything else asks them to sign in.
class GuestShell extends StatefulWidget {
  const GuestShell({super.key, required this.auth, this.initialTab = 0});
  final AuthController auth;

  /// 0 = reports, 1 = cleanups.
  final int initialTab;

  @override
  State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> with TabHistory {
  @override
  void initState() {
    super.initState();
    tabIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    // This shell is pushed from the landing page, so the Cleanups app bar already shows a
    // back arrow; it pops through tabBackScope, returning to the previous tab first.
    return tabBackScope(
      child: Scaffold(
        body: IndexedStack(
          index: tabIndex,
          children: [
            FeedScreen(auth: widget.auth),
            ProjectsScreen(auth: widget.auth),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabIndex,
          onDestinationSelected: (i) {
            if (i == 2) {
              openSignIn(context, widget.auth);
            } else {
              selectTab(i);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.waves_outlined),
              selectedIcon: Icon(Icons.waves),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.cleaning_services_outlined),
              selectedIcon: Icon(Icons.cleaning_services),
              label: 'Cleanups',
            ),
            NavigationDestination(icon: Icon(Icons.login), label: 'Sign in'),
          ],
        ),
      ),
    );
  }
}
