import 'dart:math' as math;

import 'api_client.dart';

/// Labels mirror frontend/src/lib/format.js so wording matches the website.
const roleLabels = {
  'CITIZEN': 'Community member',
  'DIVER': 'Volunteer diver',
  'ORGANIZATION': 'Organisation',
  'AUTHORITY': 'Government officer',
  'ADMIN': 'Administrator',
};

const certificationLabels = {
  'OPEN_WATER': 'Open Water',
  'ADVANCED_OPEN_WATER': 'Advanced Open Water',
  'RESCUE_DIVER': 'Rescue Diver',
  'DIVEMASTER': 'Divemaster',
  'INSTRUCTOR': 'Instructor',
};

const organizationLabels = {
  'NGO': 'NGO',
  'TOURISM': 'Tourism',
  'MARINE_INSTITUTION': 'Marine institution',
};

const reviewDecisionLabels = {
  'PENDING': 'Pending',
  'APPROVED': 'Approved',
  'REJECTED': 'Rejected',
  'MORE_INFO_REQUESTED': 'More info requested',
};

/// Sri Lanka's provinces and districts — the API rejects any other value.
const provinces = [
  'Western Province',
  'Central Province',
  'Southern Province',
  'Northern Province',
  'Eastern Province',
  'North Western Province',
  'North Central Province',
  'Uva Province',
  'Sabaragamuwa Province',
];

const districts = [
  'Colombo',
  'Gampaha',
  'Kalutara',
  'Kandy',
  'Matale',
  'Nuwara Eliya',
  'Galle',
  'Matara',
  'Hambantota',
  'Jaffna',
  'Kilinochchi',
  'Mannar',
  'Vavuniya',
  'Mullaitivu',
  'Batticaloa',
  'Ampara',
  'Trincomalee',
  'Kurunegala',
  'Puttalam',
  'Anuradhapura',
  'Polonnaruwa',
  'Badulla',
  'Monaragala',
  'Ratnapura',
  'Kegalle',
];

/// The user-facing text for any error thrown by the API client.
String messageOf(Object e) => e is ApiException
    ? e.message
    : e is FormatException
    ? e.message
    : 'Something went wrong.';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

String formatDateTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  return '${formatDate(d)}, $h:$m';
}

/// "5 min ago", "3 h ago", "2 d ago", or a date for anything older than a week.
String timeAgo(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDate(d);
}

DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// "OPEN_WATER" -> "Open water" for enums that have no explicit label.
String humanize(String? v) {
  if (v == null || v.isEmpty) return '';
  final s = v.replaceAll('_', ' ').toLowerCase();
  return s[0].toUpperCase() + s.substring(1);
}

/// Null when valid, else the message. Mirrors RegisterRequest rules.
String? validateName(String? v, String label) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Enter your $label.';
  if (t.length < 2 || t.length > 50) {
    return '$label must be between 2 and 50 characters.';
  }
  if (!RegExp(r"^\p{L}[\p{L} .'-]*$", unicode: true).hasMatch(t)) {
    return '$label can only contain letters, spaces, apostrophes, hyphens and full stops.';
  }
  return null;
}

String? validateEmail(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Enter your email.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateNic(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Enter your NIC number.';
  if (!RegExp(r'^(\d{12}|\d{9}[VvXx])$').hasMatch(t)) {
    return 'NIC must be 12 digits, or 9 digits followed by V or X.';
  }
  return null;
}

String? validatePassword(String? v) {
  final t = v ?? '';
  if (t.isEmpty) return 'Enter a password.';
  if (t.length < 8) return 'Password must be at least 8 characters.';
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(t) ||
      !RegExp(r'\d').hasMatch(t)) {
    return 'Password must include at least one letter and one number.';
  }
  return null;
}

/// Great-circle distance in kilometres, or null when either point is missing.
double? distanceKm(double? lat1, double? lng1, double? lat2, double? lng2) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
