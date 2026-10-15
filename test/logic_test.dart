// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'package:aquaaware/core/platform/device_context.dart';
import 'package:aquaaware/core/utils/format.dart';
import 'package:aquaaware/core/utils/geo.dart';
import 'package:aquaaware/data/app_store.dart';
import 'package:aquaaware/data/models/models.dart';
import 'package:aquaaware/data/points_rules.dart';
import 'package:aquaaware/data/seed/community_seed.dart';
import 'package:aquaaware/data/seed/content_seed.dart';
import 'package:aquaaware/features/student/student_screens.dart';
import 'package:aquaaware/widgets/slide_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Geo (Q8 geofence)', () {
    test('Haversine distance is accurate in metres', () {
      final d = Geo.distanceMeters(CommunitySeed.rewardDesk, CommunitySeed.city);
      expect(d, closeTo(9554, 5));
      const near = GeoPoint(12.0163 + 0.0008, 79.8517);
      expect(Geo.distanceMeters(CommunitySeed.rewardDesk, near), closeTo(89, 1));
      expect(Geo.distanceMeters(CommunitySeed.rewardDesk, near) < CommunitySeed.rewardDeskRadiusMeters, isTrue);
    });

    test('distance labels', () {
      expect(Geo.describeDistance(420), '420 m');
      expect(Geo.describeDistance(2500), '2.5 km');
      expect(Geo.describeDistance(25000), '25 km');
      expect(Geo.etaMinutes(100), 3);
    });
  });

  group('Formatting', () {
    test('Indian digit grouping', () {
      expect(Fmt.number(999), '999');
      expect(Fmt.number(12345), '12,345');
      expect(Fmt.number(1234567), '12,34,567');
      expect(Fmt.number(-1500), '-1,500');
    });

    test('relative times', () {
      final now = DateTime(2026, 10, 12, 15);
      expect(Fmt.relative(now.subtract(const Duration(seconds: 10)), now: now), 'just now');
      expect(Fmt.relative(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(Fmt.relative(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(Fmt.relative(DateTime(2026, 10, 11, 20), now: now), 'yesterday');
      expect(Fmt.relative(DateTime(2026, 10, 1), now: now), '1 Oct');
    });

    test('plural', () {
      expect(Fmt.plural(1, 'student'), '1 student');
      expect(Fmt.plural(3, 'student'), '3 students');
    });
  });

  group('Eco levels', () {
    test('levels and progress between them', () {
      expect(EcoLevels.of(0).name, 'Droplet');
      expect(EcoLevels.of(120).name, 'Stream');
      expect(EcoLevels.next(120)!.name, 'River');
      expect(EcoLevels.progress(175), closeTo(0.5, 0.001));
      expect(EcoLevels.next(5000), isNull);
      expect(EcoLevels.progress(5000), 1);
    });
  });

  group('Context rules', () {
    test('Q2 quiet hours: weekdays 8 am to 3 pm only', () {
      expect(AppStore.isQuietHours(DateTime(2026, 10, 12, 9)), isTrue); // Monday
      expect(AppStore.isQuietHours(DateTime(2026, 10, 12, 15)), isFalse);
      expect(AppStore.isQuietHours(DateTime(2026, 10, 12, 7, 59)), isFalse);
      expect(AppStore.isQuietHours(DateTime(2026, 10, 11, 10)), isFalse); // Sunday
    });

    test('Q12 water meter reading is stable for a given moment', () {
      final t = DateTime(2026, 10, 12, 13, 30);
      expect(WaterMeter.read(t).usedLitres, WaterMeter.read(t).usedLitres);
      expect(WaterMeter.read(DateTime(2026, 10, 12, 6)).usedLitres, lessThan(20));
    });
  });

  group('Content', () {
    test('every module has illustrated slides and a quiz with valid answers', () {
      expect(ContentSeed.modules, hasLength(6));
      for (final m in ContentSeed.modules) {
        expect(m.slides, isNotEmpty, reason: m.id);
        for (final s in m.slides) {
          expect(s.text.trim(), isNotEmpty, reason: '${m.id} ${s.title}');
          final art = s.art;
          switch (art.kind) {
            case SlideArtKind.stat:
              expect(art.stat, isNotEmpty, reason: s.title);
              expect(kSlideIcons.containsKey(art.icon), isTrue, reason: s.title);
            case SlideArtKind.icons:
              expect(art.icons.length, inInclusiveRange(1, 5), reason: s.title);
              for (final k in art.icons) {
                expect(kSlideIcons.containsKey(k), isTrue, reason: '${s.title}: $k');
              }
            case SlideArtKind.bins:
              break;
          }
        }
        final quiz = ContentSeed.quizzes[m.id];
        expect(quiz, isNotNull, reason: m.id);
        for (final q in quiz!) {
          expect(q.correct, inInclusiveRange(0, q.options.length - 1), reason: q.prompt);
        }
      }
    });

    test('point rules guard against farming', () {
      expect(PointRules.maxClaimsPerDay, greaterThan(0));
      expect(PointRules.maxRewardedPickupsPerDay, greaterThan(0));
      expect(PointRules.minPickupWait, greaterThan(Duration.zero));
    });

    test('the demo office team has a team lead and four employees', () {
      final team = CommunitySeed.classes.firstWhere((c) => c.code == 'AWA-2026-CTP');
      expect(team.kind, InstitutionKind.office);
      expect(CommunitySeed.students().where((s) => s.classCode == team.code), hasLength(4));
      final lead = CommunitySeed.accounts().firstWhere((a) => a.id == team.educatorId);
      expect(lead.classCode, team.code);
    });

    test('every seeded student belongs to a seeded class', () {
      final codes = CommunitySeed.classes.map((c) => c.code).toSet();
      for (final s in CommunitySeed.students()) {
        expect(codes, contains(s.classCode), reason: s.name);
      }
    });
  });

  test('announcements pay NGO tasks more than class tasks', () {
    Announcement make(Role r) => Announcement(
          id: 'x',
          message: 'm',
          senderId: 's',
          senderName: 'n',
          senderRole: r,
          sentAt: DateTime(2026),
          audience: 'ALL',
          audienceSize: 1,
        );
    expect(make(Role.ngo).points, 10);
    expect(make(Role.educator).points, 5);
    expect(make(Role.educator).reaches('AWA-2024-GHS'), isTrue);
  });

  group('Groups of every kind (school, college, office, community)', () {
    test('each kind speaks its own words', () {
      expect(InstitutionKind.school.codeLabel, 'Class code');
      expect(InstitutionKind.office.codeLabel, 'Team code');
      expect(InstitutionKind.community.codeLabel, 'Group code');
      expect(InstitutionKind.office.membersTitle, 'Employees');
      expect(InstitutionKind.office.leaderNoun, 'team lead');
      expect(InstitutionKind.community.leaderTitle, 'Organiser');
      expect(roleTitle(Role.student, InstitutionKind.office), 'Employee');
      expect(roleTitle(Role.educator, InstitutionKind.college), 'Faculty');
      expect(roleTitle(Role.ngo, InstitutionKind.office), Role.ngo.label);
    });

    test('older saved data without a kind is read as a school', () {
      expect(InstitutionKind.parse(null), InstitutionKind.school);
      expect(InstitutionKind.parse('office'), InstitutionKind.office);
      expect(InstitutionKind.parse('nonsense'), InstitutionKind.school);
      final room = ClassRoom.fromJson(const {'code': 'AWA-2026-ABC', 'school': 'X', 'educatorId': 'E', 'city': 'Y'});
      expect(room.kind, InstitutionKind.school);
      final office = ClassRoom(code: 'AWA-2026-ABC', school: 'X', educatorId: 'E', city: 'Y', kind: InstitutionKind.office);
      expect(ClassRoom.fromJson(office.toJson()).kind, InstitutionKind.office);
    });

    test('only schools and colleges hold notices during class hours', () {
      expect(InstitutionKind.values.where((k) => k.holdsNoticesDuringDay).toList(),
          [InstitutionKind.school, InstitutionKind.college]);
      expect(InstitutionKind.school.dayEndLabel, '3 pm');
      expect(InstitutionKind.office.dayEndLabel, '6 pm');
    });

    test('the 4W "where" line follows the group (Q7)', () {
      final tuesdayMorning = DateTime(2026, 10, 13, 11);
      final tuesdayEvening = DateTime(2026, 10, 13, 20);
      expect(StudentHomeScreen.whereLine(tuesdayMorning), 'You are probably at school');
      expect(StudentHomeScreen.whereLine(tuesdayMorning, InstitutionKind.college), 'You are probably at college');
      expect(StudentHomeScreen.whereLine(tuesdayMorning, InstitutionKind.office), 'You are probably at work');
      expect(StudentHomeScreen.whereLine(tuesdayEvening, InstitutionKind.office), 'Away from work');
      expect(StudentHomeScreen.whereLine(tuesdayEvening), 'Learning from home');
      expect(StudentHomeScreen.whereLine(tuesdayMorning, InstitutionKind.community), 'Every small action counts');
    });
  });
}
