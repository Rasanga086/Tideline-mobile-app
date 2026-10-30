// Field names follow the Spring DTOs: AuthDtos, UserDtos, ReportDtos, ProjectDtos,
// AlertDtos, OpportunityDtos, AnalyticsDtos.

import '../core/format.dart';

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<Map<String, dynamic>> _list(Object? v) =>
    ((v as List?) ?? const []).cast<Map<String, dynamic>>();

/// UserDtos.UserSummary — the compact author reference embedded everywhere.
class UserSummary {
  UserSummary({
    required this.id,
    required this.fullName,
    this.role,
    this.avatarUrl,
  });
  final int id;
  final String fullName;
  final String? role;
  final String? avatarUrl;

  static UserSummary? from(Object? j) {
    final m = _map(j);
    if (m == null) return null;
    return UserSummary(
      id: _int(m['id']),
      fullName: (m['fullName'] as String?) ?? 'Unknown',
      role: m['role'] as String?,
      avatarUrl: m['avatarUrl'] as String?,
    );
  }
}

class DiverProfile {
  DiverProfile({
    this.certificationLevel,
    this.experienceYears,
    this.equipment,
    this.preferredRegions = const [],
  });
  final String? certificationLevel;
  final int? experienceYears;
  final String? equipment;
  final List<String> preferredRegions;

  static DiverProfile? from(Object? j) {
    final m = _map(j);
    if (m == null) return null;
    return DiverProfile(
      certificationLevel: m['certificationLevel'] as String?,
      experienceYears: (m['experienceYears'] as num?)?.toInt(),
      equipment: m['equipment'] as String?,
      preferredRegions: ((m['preferredRegions'] as List?) ?? const [])
          .cast<String>(),
    );
  }
}

class OwnedProject {
  OwnedProject({
    required this.id,
    required this.reference,
    required this.title,
    required this.status,
  });
  final int id;
  final String reference;
  final String title;
  final String status;
}

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.province,
    this.city,
    this.avatarUrl,
    this.phone,
    this.organizationName,
    this.organizationType,
    this.websiteUrl,
    this.accountStatus,
    this.latitude,
    this.longitude,
    this.availableForAlerts = false,
    this.averageMark,
    this.markedCleanups,
    this.diverProfile,
    this.ownedProjects = const [],
  });

  final int id;
  final String fullName;
  final String? firstName;
  final String? lastName;
  final String email;
  final String role;
  final String? province;
  final String? city;
  final String? avatarUrl;
  final String? phone;
  final String? organizationName;
  final String? organizationType;
  final String? websiteUrl;
  final String? accountStatus;
  final double? latitude;
  final double? longitude;
  final bool availableForAlerts;
  final double? averageMark;
  final int? markedCleanups;
  final DiverProfile? diverProfile;
  final List<OwnedProject> ownedProjects;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: _int(j['id']),
    fullName: (j['fullName'] as String?) ?? '',
    firstName: j['firstName'] as String?,
    lastName: j['lastName'] as String?,
    email: (j['email'] as String?) ?? '',
    role: (j['role'] as String?) ?? 'CITIZEN',
    province: j['province'] as String?,
    city: j['city'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    phone: j['phone'] as String?,
    organizationName: j['organizationName'] as String?,
    organizationType: j['organizationType'] as String?,
    websiteUrl: j['websiteUrl'] as String?,
    accountStatus: j['accountStatus'] as String?,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    availableForAlerts: (j['availableForAlerts'] as bool?) ?? false,
    averageMark: (j['averageMark'] as num?)?.toDouble(),
    markedCleanups: (j['markedCleanups'] as num?)?.toInt(),
    diverProfile: DiverProfile.from(j['diverProfile']),
    ownedProjects: _list(j['ownedProjects'])
        .map(
          (p) => OwnedProject(
            id: _int(p['id']),
            reference: (p['reference'] as String?) ?? '',
            title: (p['title'] as String?) ?? '',
            status: (p['status'] as String?) ?? '',
          ),
        )
        .toList(),
  );

  String get roleText => roleLabels[role] ?? role;

  /// Government officers and administrators use the console.
  bool get isOfficial => role == 'ADMIN' || role == 'AUTHORITY';
  bool get isAdmin => role == 'ADMIN';
  bool get isAuthority => role == 'AUTHORITY';
  bool get isDiver => role == 'DIVER';
  bool get isOrganization => role == 'ORGANIZATION';

  /// Divers, organisations and officials wait for an administrator.
  bool get pendingReview => accountStatus == 'PENDING_REVIEW';
}

class AuthResult {
  AuthResult({this.token, required this.user});
  final String? token;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
    token: j['token'] as String?,
    user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
  );
}

/// One page of the report feed (Spring Page).
class PagedResult<T> {
  PagedResult({required this.items, required this.last, required this.total});
  final List<T> items;
  final bool last;
  final int total;
}

class Report {
  Report({
    required this.id,
    required this.reference,
    required this.title,
    required this.severity,
    required this.status,
    required this.trustPercentage,
    this.locationName,
    this.province,
    this.coverUrl,
    this.createdAt,
  });

  final int id;
  final String reference;
  final String title;
  final String severity;
  final String status;
  final int trustPercentage;
  final String? locationName;
  final String? province;
  final String? coverUrl;
  final DateTime? createdAt;

  /// Same as locationLine() in frontend/src/lib/format.js.
  String get locationLine => [
    locationName,
    province,
  ].where((s) => s != null && s.isNotEmpty).join(' · ');

  factory Report.fromJson(Map<String, dynamic> j) {
    final photos =
        (j['photoUrls'] as List?)?.cast<String>() ?? const <String>[];
    return Report(
      id: _int(j['id']),
      reference: (j['reference'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      severity: (j['severity'] as String?) ?? 'LOW',
      status: (j['status'] as String?) ?? 'PENDING',
      trustPercentage: _int(j['trustPercentage']),
      locationName: j['locationName'] as String?,
      province: j['province'] as String?,
      coverUrl: photos.isEmpty ? null : photos.first,
      createdAt: parseDate(j['createdAt']),
    );
  }
}

class Evidence {
  Evidence({required this.url, required this.contentType});
  final String url;
  final String contentType;
  bool get isVideo => contentType.startsWith('video/');
}

class ReportDetail {
  ReportDetail({
    required this.report,
    required this.description,
    required this.photoUrls,
    required this.reporterName,
    required this.confirmVotes,
    required this.disputeVotes,
    required this.thresholdPercent,
    required this.minimumConfirmations,
    this.myVote,
    this.district,
    this.authorityComment,
    this.reporter,
    this.evidence = const [],
    this.latitude,
    this.longitude,
    this.infoRequestStatus,
    this.adminDecision,
    this.moderationComment,
    this.authorityDecision,
    this.authorityOfficer,
    this.projectId,
    this.projectReference,
    this.resourcesAssigned,
  });

  final Report report;
  final String description;
  final List<String> photoUrls;
  final String reporterName;
  final int confirmVotes;
  final int disputeVotes;
  final int thresholdPercent;
  final int minimumConfirmations;
  final bool? myVote;
  final String? district;
  final String? authorityComment;
  final UserSummary? reporter;
  final List<Evidence> evidence;
  final double? latitude;
  final double? longitude;
  final String? infoRequestStatus;
  final String? adminDecision;
  final String? moderationComment;
  final String? authorityDecision;
  final UserSummary? authorityOfficer;
  final int? projectId;
  final String? projectReference;
  final bool? resourcesAssigned;

  factory ReportDetail.fromJson(Map<String, dynamic> j) => ReportDetail(
    report: Report.fromJson(j),
    description: (j['description'] as String?) ?? '',
    photoUrls: (j['photoUrls'] as List?)?.cast<String>() ?? const [],
    reporterName:
        ((j['reporter'] as Map?)?['fullName'] as String?) ?? 'Unknown',
    reporter: UserSummary.from(j['reporter']),
    confirmVotes: _int(j['confirmVotes']),
    disputeVotes: _int(j['disputeVotes']),
    thresholdPercent: _int(j['thresholdPercent']),
    minimumConfirmations: _int(j['minimumConfirmations']),
    myVote: j['myVote'] as bool?,
    district: j['district'] as String?,
    authorityComment: j['authorityComment'] as String?,
    evidence: _list(j['evidence'])
        .map(
          (e) => Evidence(
            url: (e['url'] as String?) ?? '',
            contentType: (e['contentType'] as String?) ?? '',
          ),
        )
        .toList(),
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    infoRequestStatus: j['infoRequestStatus'] as String?,
    adminDecision: j['adminDecision'] as String?,
    moderationComment: j['moderationComment'] as String?,
    authorityDecision: j['authorityDecision'] as String?,
    authorityOfficer: UserSummary.from(j['authorityOfficer']),
    projectId: (j['projectId'] as num?)?.toInt(),
    projectReference: j['projectReference'] as String?,
    resourcesAssigned: j['resourcesAssigned'] as bool?,
  );
}

class Comment {
  Comment({
    required this.id,
    required this.author,
    required this.body,
    required this.official,
    this.parentId,
    this.authorId,
    this.createdAt,
    this.likeCount = 0,
    this.heartCount = 0,
    this.myReaction,
  });

  final int id;
  final int? parentId;
  final int? authorId;
  final String author;
  final String body;
  final bool official;
  final DateTime? createdAt;
  final int likeCount;
  final int heartCount;
  final String? myReaction;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: _int(j['id']),
    parentId: (j['parentId'] as num?)?.toInt(),
    authorId: (_map(j['author'])?['id'] as num?)?.toInt(),
    author: ((j['author'] as Map?)?['fullName'] as String?) ?? 'Unknown',
    body: (j['body'] as String?) ?? '',
    official: (j['official'] as bool?) ?? false,
    createdAt: parseDate(j['createdAt']),
    likeCount: _int(j['likeCount']),
    heartCount: _int(j['heartCount']),
    myReaction: j['myReaction'] as String?,
  );
}

class ProjectUpdateComment {
  ProjectUpdateComment({
    required this.author,
    required this.body,
    this.createdAt,
  });
  final String author;
  final String body;
  final DateTime? createdAt;
}

class ProjectUpdate {
  ProjectUpdate({
    required this.id,
    required this.stage,
    this.note,
    this.imageUrl,
    this.authorName,
    this.createdAt,
    this.completionPercentage,
    this.likeCount = 0,
    this.likedByMe,
    this.comments = const [],
  });

  final int id;
  final String stage;
  final String? note;
  final String? imageUrl;
  final String? authorName;
  final DateTime? createdAt;
  final int? completionPercentage;
  final int likeCount;
  final bool? likedByMe;
  final List<ProjectUpdateComment> comments;

  factory ProjectUpdate.fromJson(Map<String, dynamic> j) => ProjectUpdate(
    id: _int(j['id']),
    stage: (j['stage'] as String?) ?? '',
    note: j['note'] as String?,
    imageUrl: j['imageUrl'] as String?,
    authorName: _map(j['author'])?['fullName'] as String?,
    createdAt: parseDate(j['createdAt']),
    completionPercentage: (j['completionPercentage'] as num?)?.toInt(),
    likeCount: _int(j['likeCount']),
    likedByMe: j['likedByMe'] as bool?,
    comments: _list(j['comments'])
        .map(
          (c) => ProjectUpdateComment(
            author: _map(c['author'])?['fullName'] as String? ?? 'Unknown',
            body: (c['body'] as String?) ?? '',
            createdAt: parseDate(c['createdAt']),
          ),
        )
        .toList(),
  );
}

class EquipmentNeed {
  EquipmentNeed({
    required this.name,
    required this.quantity,
    required this.securedQuantity,
  });
  final String name;
  final int quantity;
  final int securedQuantity;
}

class Participant {
  Participant({
    required this.id,
    required this.name,
    required this.role,
    this.mark,
  });
  final int id;
  final String name;
  final String role;
  final int? mark;
}

/// ProjectDtos.ProjectResponse (list and detail share it).
class Project {
  Project({
    required this.id,
    required this.reference,
    required this.title,
    required this.description,
    required this.status,
    required this.completionPercentage,
    this.locationName,
    this.province,
    this.severity,
    this.coverUrl,
    this.ownerName,
    this.ownerId,
    this.resourcesFinalized = false,
    this.volunteersNeeded,
    this.diversNeeded,
    this.equipment = const [],
    this.volunteerCount = 0,
    this.diverCount = 0,
    this.debrisRemovedKg,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.joined,
    this.updates = const [],
    this.participants,
    this.canPostProgress = false,
    this.reportId,
    this.latitude,
    this.longitude,
    this.approvalComment,
  });

  final int id;
  final String reference;
  final String title;
  final String description;
  final String status;
  final int completionPercentage;
  final String? locationName;
  final String? province;
  final String? severity;
  final String? coverUrl;
  final String? ownerName;
  final int? ownerId;

  /// The officer has set what the cleanup needs; joining is only open after this.
  final bool resourcesFinalized;
  final int? volunteersNeeded;
  final int? diversNeeded;
  final List<EquipmentNeed> equipment;
  final int volunteerCount;
  final int diverCount;
  final double? debrisRemovedKg;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final bool? joined;
  final List<ProjectUpdate> updates;

  /// Only the organiser, administrators and officers receive this.
  final List<Participant>? participants;
  final bool canPostProgress;
  final int? reportId;
  final double? latitude;
  final double? longitude;
  final String? approvalComment;

  String get locationLine => [
    locationName,
    province,
  ].where((s) => s != null && s.isNotEmpty).join(' · ');

  factory Project.fromJson(Map<String, dynamic> j) {
    String? cover;
    for (final m in _list(j['evidence'])) {
      if (((m['contentType'] as String?) ?? '').startsWith('image/')) {
        cover = m['url'] as String?;
        break;
      }
    }
    final resources = _map(j['resources']);
    return Project(
      id: _int(j['id']),
      reference: (j['reference'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      status: (j['status'] as String?) ?? 'PLANNED',
      completionPercentage: _int(j['completionPercentage']),
      locationName: j['locationName'] as String?,
      province: j['province'] as String?,
      severity: j['severity'] as String?,
      coverUrl: cover,
      ownerName: _map(j['owner'])?['fullName'] as String?,
      ownerId: (_map(j['owner'])?['id'] as num?)?.toInt(),
      resourcesFinalized: (resources?['finalized'] as bool?) ?? false,
      volunteersNeeded: (resources?['volunteersNeeded'] as num?)?.toInt(),
      diversNeeded: (resources?['diversNeeded'] as num?)?.toInt(),
      equipment: _list(resources?['equipment'])
          .map(
            (e) => EquipmentNeed(
              name: (e['name'] as String?) ?? '',
              quantity: _int(e['quantity']),
              securedQuantity: _int(e['securedQuantity']),
            ),
          )
          .toList(),
      volunteerCount: _int(j['volunteerCount']),
      diverCount: _int(j['diverCount']),
      debrisRemovedKg: (j['debrisRemovedKg'] as num?)?.toDouble(),
      startedAt: parseDate(j['startedAt']),
      completedAt: parseDate(j['completedAt']),
      createdAt: parseDate(j['createdAt']),
      joined: j['joined'] as bool?,
      updates: _list(j['updates']).map(ProjectUpdate.fromJson).toList(),
      participants: j['participants'] == null
          ? null
          : _list(j['participants'])
                .map(
                  (p) => Participant(
                    id: _int(p['id']),
                    name: _map(p['user'])?['fullName'] as String? ?? 'Unknown',
                    role: (p['role'] as String?) ?? '',
                    mark: (p['mark'] as num?)?.toInt(),
                  ),
                )
                .toList(),
      canPostProgress: (j['canPostProgress'] as bool?) ?? false,
      reportId: (j['reportId'] as num?)?.toInt(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      approvalComment: _map(j['approval'])?['comment'] as String?,
    );
  }
}

class AppAlert {
  AppAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.critical,
    this.reportId,
    this.projectId,
    this.reply,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final bool critical;
  final int? reportId;
  final int? projectId;
  final String? reply;
  final DateTime? createdAt;

  factory AppAlert.fromJson(Map<String, dynamic> j) => AppAlert(
    id: _int(j['id']),
    type: (j['type'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    read: (j['read'] as bool?) ?? false,
    critical: (j['critical'] as bool?) ?? false,
    reportId: (j['reportId'] as num?)?.toInt(),
    projectId: (j['projectId'] as num?)?.toInt(),
    reply: j['reply'] as String?,
    createdAt: parseDate(j['createdAt']),
  );

  AppAlert copyWith({bool? read}) => AppAlert(
    id: id,
    type: type,
    title: title,
    body: body,
    read: read ?? this.read,
    critical: critical,
    reportId: reportId,
    projectId: projectId,
    reply: reply,
    createdAt: createdAt,
  );
}

class Opportunity {
  Opportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.region,
    required this.paid,
    required this.open,
    required this.organizationName,
    this.organizationId,
    this.requiredCertification,
    this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final String region;
  final bool paid;
  final bool open;
  final String organizationName;
  final int? organizationId;
  final String? requiredCertification;
  final DateTime? createdAt;

  factory Opportunity.fromJson(Map<String, dynamic> j) => Opportunity(
    id: _int(j['id']),
    title: (j['title'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    region: (j['region'] as String?) ?? '',
    paid: (j['paid'] as bool?) ?? false,
    open: (j['open'] as bool?) ?? true,
    organizationName: (j['organizationName'] as String?) ?? '',
    organizationId: (j['organizationId'] as num?)?.toInt(),
    requiredCertification: j['requiredCertification'] as String?,
    createdAt: parseDate(j['createdAt']),
  );
}

class Application {
  Application({
    required this.id,
    required this.opportunityId,
    required this.opportunityTitle,
    required this.status,
    required this.diverName,
    this.certificationLevel,
    this.experienceYears,
    this.completedProjects = 0,
    this.averageMark,
    this.message,
    this.createdAt,
  });

  final int id;
  final int opportunityId;
  final String opportunityTitle;
  final String status;
  final String diverName;
  final String? certificationLevel;
  final int? experienceYears;
  final int completedProjects;
  final double? averageMark;
  final String? message;
  final DateTime? createdAt;

  factory Application.fromJson(Map<String, dynamic> j) => Application(
    id: _int(j['id']),
    opportunityId: _int(j['opportunityId']),
    opportunityTitle: (j['opportunityTitle'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'PENDING',
    diverName: _map(j['diver'])?['fullName'] as String? ?? '',
    certificationLevel: j['certificationLevel'] as String?,
    experienceYears: (j['experienceYears'] as num?)?.toInt(),
    completedProjects: _int(j['completedProjects']),
    averageMark: (j['averageMark'] as num?)?.toDouble(),
    message: j['message'] as String?,
    createdAt: parseDate(j['createdAt']),
  );
}

class PublicProfile {
  PublicProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.verified,
    this.avatarUrl,
    this.province,
    this.city,
    this.memberSince,
    this.organizationName,
    this.certificationLevel,
    this.experienceYears,
    this.completedProjects,
    this.averageMark,
    this.reportsSubmitted = 0,
    this.ownedProjects = const [],
  });

  final int id;
  final String fullName;
  final String role;
  final bool verified;
  final String? avatarUrl;
  final String? province;
  final String? city;
  final DateTime? memberSince;
  final String? organizationName;
  final String? certificationLevel;
  final int? experienceYears;
  final int? completedProjects;
  final double? averageMark;
  final int reportsSubmitted;
  final List<OwnedProject> ownedProjects;

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    id: _int(j['id']),
    fullName: (j['fullName'] as String?) ?? '',
    role: (j['role'] as String?) ?? 'CITIZEN',
    verified: (j['verified'] as bool?) ?? false,
    avatarUrl: j['avatarUrl'] as String?,
    province: j['province'] as String?,
    city: j['city'] as String?,
    memberSince: parseDate(j['memberSince']),
    organizationName: j['organizationName'] as String?,
    certificationLevel: j['certificationLevel'] as String?,
    experienceYears: (j['experienceYears'] as num?)?.toInt(),
    completedProjects: (j['completedProjects'] as num?)?.toInt(),
    averageMark: (j['averageMark'] as num?)?.toDouble(),
    reportsSubmitted: _int(j['reportsSubmitted']),
    ownedProjects: _list(j['ownedProjects'])
        .map(
          (p) => OwnedProject(
            id: _int(p['id']),
            reference: (p['reference'] as String?) ?? '',
            title: (p['title'] as String?) ?? '',
            status: (p['status'] as String?) ?? '',
          ),
        )
        .toList(),
  );
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.suspended,
    this.avatarUrl,
    this.suspensionReason,
    this.createdAt,
    this.province,
    this.city,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  final String accountStatus;
  final bool suspended;
  final String? avatarUrl;
  final String? suspensionReason;
  final DateTime? createdAt;
  final String? province;
  final String? city;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: _int(j['id']),
    fullName: (j['fullName'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    role: (j['role'] as String?) ?? 'CITIZEN',
    accountStatus: (j['accountStatus'] as String?) ?? '',
    suspended: (j['suspended'] as bool?) ?? false,
    avatarUrl: j['avatarUrl'] as String?,
    suspensionReason: j['suspensionReason'] as String?,
    createdAt: parseDate(j['createdAt']),
    province: j['province'] as String?,
    city: j['city'] as String?,
  );
}

class AccountReview {
  AccountReview({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accountStatus,
    this.phone,
    this.reviewNote,
    this.province,
    this.city,
    this.certificationLevel,
    this.experienceYears,
    this.organizationName,
    this.organizationType,
    this.websiteUrl,
    this.documents = const [],
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  final String accountStatus;
  final String? phone;
  final String? reviewNote;
  final String? province;
  final String? city;
  final String? certificationLevel;
  final int? experienceYears;
  final String? organizationName;
  final String? organizationType;
  final String? websiteUrl;

  /// (id, name, contentType) of each uploaded certificate/licence.
  final List<(int, String, String)> documents;

  factory AccountReview.fromJson(Map<String, dynamic> j) => AccountReview(
    id: _int(j['id']),
    fullName: (j['fullName'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    role: (j['role'] as String?) ?? '',
    accountStatus: (j['accountStatus'] as String?) ?? '',
    phone: j['phone'] as String?,
    reviewNote: j['reviewNote'] as String?,
    province: j['province'] as String?,
    city: j['city'] as String?,
    certificationLevel: j['certificationLevel'] as String?,
    experienceYears: (j['experienceYears'] as num?)?.toInt(),
    organizationName: j['organizationName'] as String?,
    organizationType: j['organizationType'] as String?,
    websiteUrl: j['websiteUrl'] as String?,
    documents: [
      for (final key in const ['documents', 'certificates'])
        for (final d in _list(j[key]))
          (
            _int(d['id']),
            (d['name'] as String?) ??
                (d['originalName'] as String?) ??
                'Document',
            (d['contentType'] as String?) ?? '',
          ),
    ],
  );
}

class RegionCount {
  RegionCount(this.name, this.count);
  final String name;
  final int count;
}

/// AuthDtos.DemoAccountResponse — an account the sign-in page may offer as a shortcut.
/// Only the role and email ever arrive; there is no password or token to show.
class DemoAccount {
  const DemoAccount({required this.role, required this.email});
  final String role;
  final String email;

  String get roleText => roleLabels[role] ?? role;

  /// Null for an entry without an email, so a malformed row is skipped rather than shown.
  static DemoAccount? tryParse(Object? j) {
    final m = _map(j);
    final email = m?['email'];
    if (email is! String || email.trim().isEmpty) return null;
    return DemoAccount(
      role: (m?['role'] as String?) ?? '',
      email: email.trim(),
    );
  }
}

/// AnalyticsDtos.SummaryResponse — GET /api/analytics/summary.
class Summary {
  Summary({
    required this.reportedSites,
    required this.verifiedIncidents,
    required this.communityVerified,
    required this.escalatedReports,
    required this.activeProjects,
    required this.completedProjects,
    required this.registeredVolunteers,
    required this.wasteRemovedKg,
    required this.peopleJoined,
    required this.awaitingResources,
    required this.readyToRun,
    required this.reportsByStatus,
    required this.topLocations,
    this.accountsAwaitingVerification,
    this.projectsByStage = const {},
    this.helpCallAnswers = const {},
    this.provinceBreakdown = const [],
    this.districtBreakdown = const [],
    this.reportsWithoutDistrict = 0,
    this.generatedAt,
    this.district,
    this.province,
  });

  final int reportedSites;
  final int verifiedIncidents;
  final int communityVerified;
  final int escalatedReports;
  final int activeProjects;
  final int completedProjects;
  final int registeredVolunteers;
  final double wasteRemovedKg;
  final int peopleJoined;
  final int awaitingResources;
  final int readyToRun;

  /// Only sent to administrators and government officers; null for everyone else.
  final int? accountsAwaitingVerification;

  /// Keyed by ReportStatus name, in the server's order.
  final Map<String, int> reportsByStatus;

  /// Keyed by a ready-to-show stage label ("Waiting for resources", ...), in order.
  final Map<String, int> projectsByStage;

  /// "Joined", "Ignored", "No answer yet".
  final Map<String, int> helpCallAnswers;
  final List<RegionCount> topLocations;
  final List<RegionCount> provinceBreakdown;

  /// Reports per district as recorded on each report (Galle Fort and Galle Town are both
  /// Galle), most reports first. Place names never appear here.
  final List<RegionCount> districtBreakdown;

  /// Reports with no district recorded — shown apart, never guessed into a district.
  final int reportsWithoutDistrict;
  final DateTime? generatedAt;

  /// The district the figures cover; null for the whole island.
  final String? district;

  /// The province of [district] — what the people counts cover, since accounts record a province.
  final String? province;

  static Map<String, int> _counts(Object? v) => {
    for (final e in (_map(v) ?? const <String, dynamic>{}).entries)
      e.key: _int(e.value),
  };

  static List<RegionCount> _regions(Object? v) => _list(v)
      .where((r) => r['name'] is String)
      .map((r) => RegionCount(r['name'] as String, _int(r['count'])))
      .toList();

  factory Summary.fromJson(Map<String, dynamic> j) {
    // A server that answers in another shape (an older build, say) must not render as zeros.
    if (j['reportedSites'] is! num) {
      throw const FormatException(
        'The server sent analytics in an unexpected format. Update or restart the API.',
      );
    }
    return Summary._fromValidJson(j);
  }

  factory Summary._fromValidJson(Map<String, dynamic> j) => Summary(
    reportedSites: _int(j['reportedSites']),
    verifiedIncidents: _int(j['verifiedIncidents']),
    communityVerified: _int(j['communityVerified']),
    escalatedReports: _int(j['escalatedReports']),
    activeProjects: _int(j['activeProjects']),
    completedProjects: _int(j['completedProjects']),
    registeredVolunteers: _int(j['registeredVolunteers']),
    wasteRemovedKg: (j['wasteRemovedKg'] as num?)?.toDouble() ?? 0,
    peopleJoined: _int(j['peopleJoined']),
    awaitingResources: _int(j['awaitingResources']),
    readyToRun: _int(j['readyToRun']),
    accountsAwaitingVerification: (j['accountsAwaitingVerification'] as num?)
        ?.toInt(),
    reportsByStatus: _counts(j['reportsByStatus']),
    projectsByStage: _counts(j['projectsByStage']),
    helpCallAnswers: _counts(j['helpCallAnswers']),
    topLocations: _regions(j['topLocations']),
    provinceBreakdown: _regions(j['provinceBreakdown']),
    districtBreakdown: _regions(j['districtBreakdown']),
    reportsWithoutDistrict: _int(j['reportsWithoutDistrict']),
    generatedAt: parseDate(j['generatedAt']),
    district: j['district'] as String?,
    province: j['province'] as String?,
  );
}

class InfoRequest {
  InfoRequest({
    required this.id,
    required this.reportId,
    required this.message,
    required this.status,
    this.requestedBy,
    this.responseText,
    this.attachments = const [],
    this.createdAt,
    this.respondedAt,
  });

  final int id;
  final int reportId;
  final String message;
  final String status;
  final String? requestedBy;
  final String? responseText;

  /// (url, name, contentType)
  final List<(String, String, String)> attachments;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  factory InfoRequest.fromJson(Map<String, dynamic> j) => InfoRequest(
    id: _int(j['id']),
    reportId: _int(j['reportId']),
    message: (j['message'] as String?) ?? '',
    status: (j['status'] as String?) ?? '',
    requestedBy: _map(j['requestedBy'])?['fullName'] as String?,
    responseText: j['responseText'] as String?,
    attachments: _list(j['attachments'])
        .map(
          (a) => (
            (a['url'] as String?) ?? '',
            (a['name'] as String?) ?? '',
            (a['contentType'] as String?) ?? '',
          ),
        )
        .toList(),
    createdAt: parseDate(j['createdAt']),
    respondedAt: parseDate(j['respondedAt']),
  );
}
