import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/models.dart';
import 'admin_verifications_screen.dart';
import 'help_call_screen.dart';
import 'more_info_screen.dart';
import 'profile_screen.dart';
import 'project_detail_screen.dart';
import 'report_detail_screen.dart';
import 'report_review_screen.dart';

/// Where an alert opens. Mirrors lib/alertLinks.js on the website
/// (volunteerAlertLink / consoleAlertLink).
Future<void> openAlertTarget(
  BuildContext context,
  AuthController auth,
  AppAlert a, {
  bool console = false,
}) {
  final isAdmin = auth.user?.isAdmin ?? false;
  Widget? page;
  if (a.type == 'ACCOUNT_APPLICATION') {
    if (isAdmin) page = AdminVerificationsScreen(auth: auth);
  } else if (a.type == 'ACCOUNT_REVIEW') {
    page = ProfileScreen(auth: auth);
  } else if (!console && a.type == 'HELP_NEEDED' && a.projectId != null) {
    page = HelpCallScreen(auth: auth, alert: a);
  } else if (!console && a.type == 'INFO_REQUESTED' && a.reportId != null) {
    page = MoreInfoScreen(auth: auth, reportId: a.reportId!);
  } else if (a.projectId != null) {
    page = ProjectDetailScreen(auth: auth, projectId: a.projectId!);
  } else if (a.reportId != null) {
    page = console
        ? ReportReviewScreen(auth: auth, reportId: a.reportId!)
        : ReportDetailScreen(auth: auth, reportId: a.reportId!);
  }
  if (page == null) return Future.value();
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
}
