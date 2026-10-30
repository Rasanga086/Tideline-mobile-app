import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Keeps the unread-alert count for the tab badge (GET /api/alerts/unread-count),
/// like hooks/useUnreadAlerts.js. Polls while the signed-in shell is on screen.
class AlertsController extends ChangeNotifier {
  AlertsController(this.api, {Duration poll = const Duration(seconds: 60)}) {
    refresh();
    _timer = Timer.periodic(poll, (_) => refresh());
  }

  final ApiClient api;
  Timer? _timer;
  int unread = 0;
  bool _disposed = false;

  Future<void> refresh() async {
    try {
      final json = await api.get('/api/alerts/unread-count');
      final count = json is Map ? (json['count'] ?? json['unread']) : json;
      final next = (count as num?)?.toInt() ?? 0;
      if (next != unread && !_disposed) {
        unread = next;
        notifyListeners();
      }
    } catch (_) {
      // The badge is a convenience; a failed poll just keeps the last count.
    }
  }

  /// Called after the alert list changes locally (read / read-all).
  void set(int value) {
    if (value == unread || _disposed) return;
    unread = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
