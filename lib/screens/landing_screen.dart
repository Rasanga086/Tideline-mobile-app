import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/report_card.dart';
import 'home_shell.dart';
import 'projects_screen.dart';
import 'report_detail_screen.dart';

/// The public front page — mirrors pages/Landing.jsx: hero slides, quick-start tiles, how it
/// works, live impact figures, the latest reports and projects, and the footer links.
/// Every figure and list comes from the public API; nothing here is made up.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key, required this.auth});
  final AuthController auth;

  /// Same pace as the website's hero (SLIDE_MS).
  static const slideEvery = Duration(seconds: 6);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

enum _Go { submit, feed, projects, opportunities }

/// (eyebrow, title, body, call to action, icon, destination) — Landing.jsx SLIDES.
const _slides = <(String, String, String, String, IconData, _Go)>[
  (
    'Report',
    'Spot pollution on the coast? Report it in a minute.',
    'Snap a photo, drop your location and describe what you see. People nearby are alerted to help confirm it.',
    'Report a polluted site',
    Icons.photo_camera_outlined,
    _Go.submit,
  ),
  (
    'Verify',
    'The community checks every report before it moves on.',
    'Five confirmations and 75% trust send a report to administrators, then to the government officer.',
    'Browse reports',
    Icons.verified_outlined,
    _Go.feed,
  ),
  (
    'Clean up',
    'Approved sites become cleanup projects anyone can join.',
    'Administrators assign volunteers, divers and equipment. Follow progress until the site is clean.',
    'See cleanup projects',
    Icons.volunteer_activism_outlined,
    _Go.projects,
  ),
];

/// (label, hint, icon, colour, destination) — Landing.jsx TILES.
const _tiles = <(String, String, IconData, Color, _Go)>[
  (
    'Report',
    'Photo and location',
    Icons.photo_camera_outlined,
    TL.buoy400,
    _Go.submit,
  ),
  (
    'Verify',
    'Confirm what you see',
    Icons.verified_outlined,
    TL.tide300,
    _Go.feed,
  ),
  (
    'Clean up',
    'Join a project',
    Icons.volunteer_activism_outlined,
    TL.sea300,
    _Go.projects,
  ),
  (
    'Dive',
    'Diver opportunities',
    Icons.anchor,
    Color(0xFFFF9F8A),
    _Go.opportunities,
  ),
];

/// (icon, title, body) — Landing.jsx STEPS.
const _steps = <(IconData, String, String)>[
  (
    Icons.photo_camera_outlined,
    'Someone reports it',
    'A citizen or diver submits photos, severity and the exact location.',
  ),
  (
    Icons.groups_outlined,
    'The community verifies',
    'Neighbours confirm or dispute. Five confirmations and 75% trust pass it on.',
  ),
  (
    Icons.verified_user_outlined,
    'Officials approve',
    'An administrator reviews it, then the government officer approves it.',
  ),
  (
    Icons.volunteer_activism_outlined,
    'It becomes a project',
    'Resources are assigned, volunteers join and progress is tracked to the end.',
  ),
];

const _muted = Color(
  0xB8FFFFFF,
); // rgba(255,255,255,0.72), the website's body text on navy
const _faint = Color(0x8CFFFFFF); // 0.55

class _LandingScreenState extends State<LandingScreen> {
  final _pages = PageController();
  int _slide = 0;
  bool _paused = false;
  Timer? _timer;
  bool _showProjects = false;

  late Future<Summary> _summary = _loadSummary();
  late Future<List<Report>> _reports = _loadReports();
  late Future<List<Project>> _projects = _loadProjects();

  Future<Summary> _loadSummary() async => Summary.fromJson(
    await widget.auth.api.get('/api/analytics/summary', auth: false)
        as Map<String, dynamic>,
  );

  Future<List<Report>> _loadReports() async {
    final page =
        await widget.auth.api.get(
              '/api/reports',
              query: {'size': '3'},
              auth: false,
            )
            as Map<String, dynamic>;
    return ((page['content'] as List?) ?? const [])
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .take(3)
        .toList();
  }

  Future<List<Project>> _loadProjects() async {
    final list =
        await widget.auth.api.get('/api/projects', auth: false) as List;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .where((p) => p.status != 'COMPLETED')
        .take(3)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(LandingScreen.slideEvery, (_) {
      if (_paused || !_pages.hasClients) return;
      _pages.animateToPage(
        (_slide + 1) % _slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _summary = _loadSummary();
      _reports = _loadReports();
      _projects = _loadProjects();
    });
    await Future.wait<Object?>([
      _summary.then<Object?>((v) => v, onError: (_) => null),
      _reports.then<Object?>((v) => v, onError: (_) => null),
      _projects.then<Object?>((v) => v, onError: (_) => null),
    ]);
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Where a slide, tile or link leads. Reporting and diving need an account, as on the website.
  Future<void> _go(_Go to) async {
    switch (to) {
      case _Go.feed:
        _push(GuestShell(auth: widget.auth));
      case _Go.projects:
        _push(GuestShell(auth: widget.auth, initialTab: 1));
      case _Go.submit:
        await ensureSignedIn(
          context,
          widget.auth,
          reason:
              'Reporting a polluted site needs a Tideline account, so the community knows who to ask about it.',
        );
      case _Go.opportunities:
        await ensureSignedIn(
          context,
          widget.auth,
          reason:
              'Diver opportunities are for signed-in members. Create an account to apply.',
        );
    }
  }

  /// Section anchors for the header menu, like the website's #how-it-works / #impact / #latest.
  final _howKey = GlobalKey();
  final _impactKey = GlobalKey();
  final _latestKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _width(List<Widget> children) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // On small phones "Sign in" moves into the menu so the header never overflows.
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return Scaffold(
      backgroundColor: TL.sea950,
      appBar: AppBar(
        backgroundColor: TL.sea950,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TidelineWordmark(onDark: true),
        ),
        actions: [
          if (!narrow)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => openSignIn(context, widget.auth),
              child: const Text('Sign in'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TL.tide500,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () => openRegister(context, widget.auth),
            child: Text(narrow ? 'Join' : 'Join Tideline'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onSelected: (v) {
              switch (v) {
                case 'how':
                  _scrollTo(_howKey);
                case 'impact':
                  _scrollTo(_impactKey);
                case 'latest':
                  _scrollTo(_latestKey);
                case 'projects':
                  _go(_Go.projects);
                case 'signin':
                  openSignIn(context, widget.auth);
                default:
                  openRegister(context, widget.auth);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'how', child: Text('How it works')),
              PopupMenuItem(value: 'impact', child: Text('Impact')),
              PopupMenuItem(value: 'latest', child: Text('Latest')),
              PopupMenuItem(value: 'projects', child: Text('Projects')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'signin', child: Text('Sign in')),
              PopupMenuItem(value: 'join', child: Text('Join Tideline')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        // One scroll view with every section built, so the menu can scroll to any of them.
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _width([
                  _hero(context),
                  _phonePreview(context),
                  _tilesGrid(context),
                ]),
                const TidelineWaves(height: 70),
                _width([
                  KeyedSubtree(key: _howKey, child: _howItWorks(context)),
                  KeyedSubtree(key: _impactKey, child: _impact(context)),
                  _promo(context),
                ]),
                KeyedSubtree(key: _latestKey, child: _latest(context)),
                _width([
                  _about(context),
                  _callToAction(context),
                  _footer(context),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────────────────

  Widget _hero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Listener(
            // Touching the slides pauses them, like hovering on the website.
            onPointerDown: (_) => _paused = true,
            onPointerUp: (_) => _paused = false,
            onPointerCancel: (_) => _paused = false,
            child: SizedBox(
              // Taller when the user has asked for larger text.
              height: MediaQuery.textScalerOf(context).scale(260),
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _slide = i),
                itemBuilder: (context, i) => _slideView(context, _slides[i]),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _slides.length; i++)
                Semantics(
                  button: true,
                  selected: i == _slide,
                  label: 'Slide ${i + 1}: ${_slides[i].$1}',
                  child: InkWell(
                    onTap: () => _pages.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 4,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: i == _slide ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _slide
                              ? TL.tide400
                              : const Color(0x40FFFFFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // The website's two hero buttons: the current slide's action and "How it works".
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: TL.tide500),
            onPressed: () => _go(_slides[_slide].$6),
            icon: Icon(_slides[_slide].$5),
            label: Text(_slides[_slide].$4),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x59FFFFFF)),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TL.radiusMd),
              ),
            ),
            onPressed: () => _scrollTo(_howKey),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('How it works'),
          ),
        ],
      ),
    );
  }

  Widget _slideView(
    BuildContext context,
    (String, String, String, String, IconData, _Go) slide,
  ) {
    final (eyebrow, title, body, _, icon, _) = slide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x2935C2B7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: TL.tide300),
              const SizedBox(width: 6),
              Text(
                eyebrow,
                style: const TextStyle(
                  color: TL.tide300,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TL.fontDisplay,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: Text(
            body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, height: 1.55, color: _muted),
          ),
        ),
      ],
    );
  }

  /// A small phone showing the newest real report, like PhoneMock on the website. With no
  /// report to show (none yet, or the API is unreachable) the preview is left out rather
  /// than filled with an invented one.
  Widget _phonePreview(BuildContext context) => FutureBuilder<List<Report>>(
    future: _reports,
    builder: (context, snap) {
      final report = (snap.data ?? const <Report>[]).firstOrNull;
      if (report == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Center(
          child: Semantics(
            button: true,
            label: 'Latest report: ${report.title}',
            child: GestureDetector(
              onTap: () => _push(
                ReportDetailScreen(auth: widget.auth, reportId: report.id),
              ),
              child: _PhoneFrame(report: report),
            ),
          ),
        ),
      );
    },
  );

  Widget _tilesGrid(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    child: LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 560 ? 4 : 2;
        final w = (c.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, hint, icon, colour, to) in _tiles)
              SizedBox(
                width: w,
                child: Material(
                  color: const Color(0x0AFFFFFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TL.radiusLg),
                    side: const BorderSide(color: Color(0x14FFFFFF)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(TL.radiusLg),
                    onTap: () => _go(to),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colour.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: colour, size: 22),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: TL.fontDisplay,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            hint,
                            style: const TextStyle(fontSize: 13, color: _faint),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  // ── How it works & impact ─────────────────────────────────────────────────────────────

  Widget _heading(String eyebrow, String title, {bool onDark = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                color: onDark ? TL.tide300 : TL.tide700,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: TL.fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 26,
                height: 1.15,
                letterSpacing: -0.5,
                color: onDark ? Colors.white : TL.textStrong,
              ),
            ),
          ],
        ),
      );

  Widget _howItWorks(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('How it works', 'From a photo to a clean coast'),
        for (var i = 0; i < _steps.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(TL.radiusLg),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x2935C2B7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_steps[i].$1, color: TL.tide300),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i].$2,
                        style: const TextStyle(
                          fontFamily: TL.fontDisplay,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _steps[i].$3,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '0${i + 1}',
                  style: const TextStyle(
                    fontFamily: TL.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: Color(0x1FFFFFFF),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _impact(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: FutureBuilder<Summary>(
      future: _summary,
      builder: (context, snap) {
        final s = snap.data;
        // (label, value, colour) — the website's four impact figures.
        final stats = <(String, int?, Color)>[
          ('Open reports', s?.reportedSites, TL.buoy400),
          ('Active projects', s?.activeProjects, TL.tide300),
          ('Projects completed', s?.completedProjects, TL.sea300),
          ('Volunteers', s?.registeredVolunteers, const Color(0xFFFF9F8A)),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('Impact', 'Our impact so far'),
            const Text(
              'Every number here is live from the platform.',
              style: TextStyle(color: _muted, fontSize: 15),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (label, value, colour) in stats)
                    Container(
                      width: (c.maxWidth - 12) / 2,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(TL.radiusMd),
                        border: Border.all(color: const Color(0x0FFFFFFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // A figure we could not load shows a dash, never a guessed number.
                          _CountUp(value: value, colour: colour),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: const TextStyle(fontSize: 13, color: _faint),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (snap.hasError) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Live figures are unavailable right now.',
                      style: TextStyle(color: _faint, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: TL.tide300),
                    onPressed: () => setState(() => _summary = _loadSummary()),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _promo(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6E0), TL.buoy100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(TL.radiusXl),
      ),
      child: FutureBuilder<Summary>(
        future: _summary,
        builder: (context, snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.waves, size: 18, color: TL.tide600),
                SizedBox(width: 8),
                Text(
                  'Tideline projects',
                  style: TextStyle(
                    fontFamily: TL.fontDisplay,
                    fontWeight: FontWeight.w700,
                    color: TL.tide700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              const TextSpan(
                text: 'Clean coasts, ',
                children: [
                  TextSpan(
                    text: 'together',
                    style: TextStyle(color: TL.buoy600),
                  ),
                ],
              ),
              style: const TextStyle(
                fontFamily: TL.fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 26,
                height: 1.1,
                letterSpacing: -0.5,
                color: TL.textStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              snap.data != null
                  ? '${snap.data!.activeProjects} cleanup projects are looking for volunteers and divers right now.'
                  : 'Cleanup projects near you are looking for volunteers and divers.',
              style: const TextStyle(
                color: TL.sea700,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _go(_Go.projects),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Join a cleanup'),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Latest ────────────────────────────────────────────────────────────────────────────

  Widget _latest(BuildContext context) => Container(
    color: TL.gray50,
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('Latest', 'From the coast', onDark: false),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Reports')),
                ButtonSegment(value: true, label: Text('Projects')),
              ],
              selected: {_showProjects},
              onSelectionChanged: (v) =>
                  setState(() => _showProjects = v.first),
            ),
            const SizedBox(height: 16),
            if (_showProjects)
              _list<Project>(
                _projects,
                retry: () => setState(() => _projects = _loadProjects()),
                item: (p) => ProjectCard(
                  project: p,
                  onTap: () => _push(
                    ProjectDetailScreen(auth: widget.auth, projectId: p.id),
                  ),
                ),
              )
            else
              _list<Report>(
                _reports,
                retry: () => setState(() => _reports = _loadReports()),
                item: (r) => ReportCard(
                  report: r,
                  onTap: () => _push(
                    ReportDetailScreen(auth: widget.auth, reportId: r.id),
                  ),
                ),
              ),
            Align(
              child: TextButton.icon(
                onPressed: () => _go(_showProjects ? _Go.projects : _Go.feed),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(
                  _showProjects
                      ? 'See all cleanup projects'
                      : 'See all reports',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _list<T>(
    Future<List<T>> future, {
    required VoidCallback retry,
    required Widget Function(T) item,
  }) => FutureBuilder<List<T>>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snap.hasError) {
        return Column(
          children: [
            Text(
              messageOf(snap.error!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: TL.coral700),
            ),
            TextButton(onPressed: retry, child: const Text('Try again')),
          ],
        );
      }
      final items = snap.data!;
      if (items.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Nothing here yet.',
              style: TextStyle(color: TL.textMuted),
            ),
          ),
        );
      }
      return Column(children: [for (final i in items) item(i)]);
    },
  );

  // ── About, call to action, footer ─────────────────────────────────────────────────────

  Widget _about(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Tideline',
          style: TextStyle(
            fontFamily: TL.fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tideline is a community-based ocean and coastal cleanup platform for Sri Lanka. '
          'Citizens and divers report pollution, the community verifies it, administrators '
          'and the government officer approve it, and it becomes a cleanup project people can join.',
          style: TextStyle(color: _muted, fontSize: 15, height: 1.6),
        ),
      ],
    ),
  );

  Widget _callToAction(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TL.tide700, TL.sea700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(TL.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Seen pollution on the coast?',
            style: TextStyle(
              fontFamily: TL.fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'It takes a minute to report, and your neighbours can help confirm it.',
            style: TextStyle(color: _muted, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: TL.tide800,
            ),
            onPressed: () => _go(_Go.submit),
            child: const Text('Report a polluted site'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x66FFFFFF)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => openRegister(context, widget.auth),
            child: const Text('Create an account'),
          ),
        ],
      ),
    ),
  );

  Widget _footer(BuildContext context) {
    Widget link(String label, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 14)),
      ),
    );
    Widget column(String title, List<Widget> links) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          ...links,
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TidelineWordmark(onDark: true, size: 20),
          const SizedBox(height: 10),
          const Text(
            'Community-based ocean and coastal cleanup management for Sri Lanka.',
            style: TextStyle(color: _faint, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column('Community', [
                link('Reports', () => _go(_Go.feed)),
                link('Cleanup projects', () => _go(_Go.projects)),
                link('Diver opportunities', () => _go(_Go.opportunities)),
                link('Report pollution', () => _go(_Go.submit)),
              ]),
              column('Account', [
                link('Sign in', () => openSignIn(context, widget.auth)),
                link(
                  'Create an account',
                  () => openRegister(context, widget.auth),
                ),
              ]),
            ],
          ),
          const Divider(color: Color(0x1AFFFFFF), height: 32),
          Text(
            '© ${DateTime.now().year} Tideline',
            style: const TextStyle(color: _faint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Counts up to [value] once, like the website's CountUp; a missing value shows "—".
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.colour});
  final int? value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: TL.fontDisplay,
      fontWeight: FontWeight.w700,
      fontSize: 30,
      height: 1,
    );
    if (value == null) return Text('—', style: style.copyWith(color: colour));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value!.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('${v.round()}', style: style.copyWith(color: colour)),
    );
  }
}

/// The phone outline and the report card inside it.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusFg, statusBg) = reportStatusStyle(report.status);
    final cover = AppConfig.mediaUrl(report.coverUrl);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1216),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: const Color(0x14FFFFFF), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 60,
            offset: Offset(0, 30),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: ColoredBox(
          color: TL.gray50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: TL.sea900,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: const Row(
                  children: [TidelineWordmark(onDark: true, size: 13)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nearby reports',
                      style: TextStyle(
                        fontFamily: TL.fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: TL.textStrong,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TL.gray200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 110,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [TL.sea300, TL.tide500],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: cover == null
                                  ? const Icon(
                                      Icons.waves,
                                      color: Colors.white70,
                                      size: 40,
                                    )
                                  : Image.network(
                                      cover,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          const SizedBox.shrink(),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.reference,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: TL.fontMono,
                                          fontSize: 10,
                                          color: TL.textMuted,
                                        ),
                                      ),
                                    ),
                                    StatusPill(
                                      statusLabel,
                                      fg: statusFg,
                                      bg: statusBg,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: TL.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: (report.trustPercentage / 100).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  minHeight: 5,
                                  color: TL.tide500,
                                  backgroundColor: TL.gray200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${report.trustPercentage}% community trust',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TL.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
