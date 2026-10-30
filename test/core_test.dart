import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tideline_mobile/auth/auth_controller.dart';
import 'package:tideline_mobile/core/api_client.dart';
import 'package:tideline_mobile/core/format.dart';
import 'package:tideline_mobile/core/uploads.dart';
import 'package:tideline_mobile/models/models.dart';
import 'package:tideline_mobile/widgets/resource_planner.dart';

const _user = {
  'id': 1,
  'fullName': 'Hiruna Perera',
  'firstName': 'Hiruna',
  'lastName': 'Perera',
  'email': 'hiruna@example.lk',
  'role': 'DIVER',
  'accountStatus': 'APPROVED',
  'diverProfile': {
    'certificationLevel': 'RESCUE_DIVER',
    'experienceYears': 4,
    'preferredRegions': ['Western Province'],
  },
};

void main() {
  group('validators and formatting', () {
    test('registration rules mirror the backend', () {
      expect(validateName('Hiruna', 'first name'), isNull);
      expect(validateName('H', 'first name'), isNotNull);
      expect(validateName('R2D2', 'first name'), isNotNull);
      expect(validateEmail('a@b.lk'), isNull);
      expect(validateEmail('nope'), isNotNull);
      expect(validateNic('199912345678'), isNull);
      expect(validateNic('991234567V'), isNull);
      expect(validateNic('12345'), isNotNull);
      expect(validatePassword('abcdefg1'), isNull);
      expect(validatePassword('abcdefgh'), isNotNull); // no number
      expect(validatePassword('12345678'), isNotNull); // no letter
      expect(validatePassword('a1'), isNotNull); // too short
    });

    test('timeAgo and distanceKm', () {
      final now = DateTime(2026, 10, 19, 12);
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now: now),
        '3 h ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 2)), now: now),
        '2 d ago',
      );
      expect(distanceKm(null, 1, 2, 3), isNull);
      // Colombo -> Galle is roughly 100 km as the crow flies.
      final km = distanceKm(6.9271, 79.8612, 6.0535, 80.2210)!;
      expect(km, inInclusiveRange(95, 115));
    });

    test('upload checks follow the backend limits', () {
      expect(checkImage('a.webp', 100), isNull);
      expect(checkImage('a.gif', 100), isNotNull);
      expect(
        checkImage('a.png', maxAvatarBytes + 1, maxBytes: maxAvatarBytes),
        isNotNull,
      );
      expect(checkDocument('cert.pdf', 100), isNull);
      expect(checkDocument('cert.webp', 100), isNotNull);
      expect(checkDocument('cert.pdf', maxDocumentBytes + 1), isNotNull);
    });

    test('resource plan needs a volunteer and complete equipment lines', () {
      expect(
        buildResources(volunteers: '', divers: '', equipmentLines: []).error,
        isNotNull,
      );
      expect(
        buildResources(
          volunteers: '5',
          divers: '',
          equipmentLines: [('Gloves', '')],
        ).error,
        isNotNull,
      );
      final ok = buildResources(
        volunteers: '5',
        divers: '2',
        equipmentLines: [('Gloves', '10'), ('', '')],
      );
      expect(ok.error, isNull);
      expect(ok.payload, {
        'volunteersNeeded': 5,
        'diversNeeded': 2,
        'equipment': [
          {'name': 'Gloves', 'quantity': 10},
        ],
      });
    });
  });

  group('models', () {
    test('AppUser reads the diver profile and role helpers', () {
      final u = AppUser.fromJson(_user);
      expect(u.isDiver, isTrue);
      expect(u.isOfficial, isFalse);
      expect(u.diverProfile!.certificationLevel, 'RESCUE_DIVER');
      expect(u.diverProfile!.preferredRegions, ['Western Province']);
    });

    test('Project reads resources, updates and approval', () {
      final p = Project.fromJson({
        'id': 7,
        'reference': 'PRJ-7',
        'title': 'T',
        'description': 'D',
        'status': 'ACTIVE',
        'completionPercentage': 40,
        'owner': {'id': 9, 'fullName': 'Owner'},
        'resources': {
          'finalized': true,
          'volunteersNeeded': 5,
          'diversNeeded': 2,
          'equipment': [
            {'name': 'Gloves', 'quantity': 10, 'securedQuantity': 4},
          ],
        },
        'approval': {'comment': 'Go ahead'},
        'canPostProgress': true,
        'evidence': [
          {'url': '/api/reports/evidence/a.mp4', 'contentType': 'video/mp4'},
          {'url': '/api/reports/evidence/a.jpg', 'contentType': 'image/jpeg'},
        ],
        'updates': [
          {
            'id': 3,
            'stage': 'BEFORE',
            'likeCount': 2,
            'likedByMe': true,
            'author': {'id': 9, 'fullName': 'Owner'},
            'comments': [
              {
                'author': {'fullName': 'Sam'},
                'body': 'Great',
              },
            ],
          },
        ],
      });
      expect(p.ownerId, 9);
      expect(p.resourcesFinalized, isTrue);
      expect(p.equipment.single.securedQuantity, 4);
      expect(p.approvalComment, 'Go ahead');
      expect(p.canPostProgress, isTrue);
      expect(
        p.coverUrl,
        '/api/reports/evidence/a.jpg',
      ); // first image, not the video
      expect(p.updates.single.likedByMe, isTrue);
      expect(p.updates.single.comments.single.author, 'Sam');
      expect(p.participants, isNull);
    });

    test('Comment, alert and summary parse the DTO fields', () {
      final c = Comment.fromJson({
        'id': 1,
        'parentId': 5,
        'author': {'id': 2, 'fullName': 'Ana'},
        'body': 'hi',
        'likeCount': 3,
        'heartCount': 1,
        'myReaction': 'LIKE',
      });
      expect(c.parentId, 5);
      expect(c.myReaction, 'LIKE');
      final a = AppAlert.fromJson({
        'id': 1,
        'type': 'HELP_NEEDED',
        'title': 't',
        'body': 'b',
        'read': false,
        'critical': true,
        'projectId': 4,
      });
      expect(a.copyWith(read: true).read, isTrue);
      expect(a.projectId, 4);
      final s = Summary.fromJson({
        'reportedSites': 9,
        'wasteRemovedKg': 12.5,
        'reportsByStatus': {'PENDING': 3},
        'topLocations': [
          {'name': 'Negombo', 'count': 4},
        ],
      });
      expect(s.reportedSites, 9);
      expect(s.reportsByStatus['PENDING'], 3);
      expect(s.topLocations.single.name, 'Negombo');
    });
  });

  group('ApiClient', () {
    test(
      'put, delete and multipart PUT send the right method and token',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final seen = <String>[];
        final auths = <String?>[];
        final api = ApiClient(
          client: MockClient.streaming((req, body) async {
            seen.add('${req.method} ${req.url.path}');
            auths.add(req.headers['Authorization']);
            await body.drain<void>();
            return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
          }),
        );
        await api.setToken('abc', remember: false);
        await api.put('/api/users/me', body: {'city': 'x'});
        await api.delete('/api/users/me/avatar');
        await api.postMultipart(
          '/api/users/me/avatar',
          method: 'PUT',
          files: [
            http.MultipartFile.fromBytes('photo', [1, 2], filename: 'a.png'),
          ],
        );
        expect(seen, [
          'PUT /api/users/me',
          'DELETE /api/users/me/avatar',
          'PUT /api/users/me/avatar',
        ]);
        expect(auths.every((a) => a == 'Bearer abc'), isTrue);
      },
    );

    test(
      '401 on a signed-in request calls onUnauthorized; offline maps to status 0',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        var expired = 0;
        final api = ApiClient(
          client: MockClient((req) async {
            if (req.url.path == '/offline') throw http.ClientException('down');
            return http.Response('{"message":"Expired"}', 401);
          }),
        );
        api.onUnauthorized = () => expired++;
        await api.setToken('t', remember: false);

        await expectLater(
          api.get('/api/x'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
        );
        expect(expired, 1);
        await expectLater(
          api.get('/offline'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 0)),
        );
        expect(expired, 1);
      },
    );
  });

  group('AuthController', () {
    test(
      'keeps a stored session through a dropped connection but clears a rejected one',
      () async {
        FlutterSecureStorage.setMockInitialValues({'tideline.token': 'stored'});
        final offline = AuthController(
          ApiClient(
            client: MockClient((_) async => throw http.ClientException('x')),
          ),
        );
        await offline.init();
        expect(offline.isAuthenticated, isFalse);
        expect(offline.api.token, 'stored');

        final rejected = AuthController(
          ApiClient(client: MockClient((_) async => http.Response('{}', 401))),
        );
        await rejected.init();
        expect(rejected.api.token, isNull);
        expect(rejected.isAuthenticated, isFalse);
      },
    );

    test('restores the user from the stored token', () async {
      FlutterSecureStorage.setMockInitialValues({'tideline.token': 'stored'});
      final auth = AuthController(
        ApiClient(
          client: MockClient((req) async {
            expect(req.headers['Authorization'], 'Bearer stored');
            return http.Response(jsonEncode(_user), 200);
          }),
        ),
      );
      await auth.init();
      expect(auth.user!.fullName, 'Hiruna Perera');
    });

    test(
      'registering a community member signs them in; a diver gets no session',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        var withToken = true;
        final auth = AuthController(
          ApiClient(
            client: MockClient.streaming((req, body) async {
              await body.drain<void>();
              expect(req.url.path, '/api/auth/register');
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      if (withToken) 'token': 'new-token',
                      'expiresInSeconds': 3600,
                      'user': _user,
                    }),
                  ),
                ),
                201,
              );
            }),
          ),
        );
        final pending = await auth
            .register({'role': 'DIVER'})
            .then((_) => auth.isAuthenticated);
        expect(pending, isTrue); // token present in this mocked response
        await auth.logout();

        withToken = false;
        final r = await auth.register({'role': 'DIVER'});
        expect(r.token, isNull);
        expect(auth.isAuthenticated, isFalse);
      },
    );

    test('updateProfile replaces the user with the API response', () async {
      FlutterSecureStorage.setMockInitialValues({});
      Map<String, dynamic>? sent;
      final auth = AuthController(
        ApiClient(
          client: MockClient((req) async {
            sent = jsonDecode(req.body) as Map<String, dynamic>;
            return http.Response(jsonEncode({..._user, 'city': 'Galle'}), 200);
          }),
        ),
      );
      await auth.updateProfile({'city': 'Galle'});
      expect(sent, {'city': 'Galle'});
      expect(auth.user!.city, 'Galle');
    });
  });
}
