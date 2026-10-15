// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.
// Boots the whole app with in-memory secure storage, signs in as every role
// and opens every screen at phone and desktop sizes. Any exception during
// build or layout (including "RenderFlex overflowed") fails the test.
//
// Run with:  flutter test test/app_smoke_test.dart

import 'package:aquaaware/app.dart';
import 'package:aquaaware/core/app_info.dart';
import 'package:aquaaware/data/models/models.dart';
import 'package:aquaaware/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phone = Size(390, 844);
const _desktop = Size(1366, 900);

const _paths = <Role, List<String>>{
  Role.student: [
    '/student',
    '/student/learn',
    '/student/map',
    '/student/rewards',
    '/student/profile',
    '/learn/MOD_A',
    '/learn/MOD_B',
    '/quiz/MOD_B',
    '/sort',
    '/gallery',
    '/settings',
    '/security',
  ],
  Role.educator: [
    '/educator',
    '/educator/class',
    '/educator/messages',
    '/educator/resources',
    '/educator/insights',
    '/thread/STU001',
    '/settings',
  ],
  Role.ngo: ['/ngo', '/ngo/activities', '/ngo/verify', '/ngo/map', '/security'],
  Role.manager: ['/manager', '/manager/directory', '/manager/map', '/security'],
};

/// Prints each framework error in full the moment it happens, while the
/// widget tree still exists, so the report names the widget and the file and
/// line that caused it. The test framework still records the error as usual
/// (and restores its own handler after every test).
void _traceErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint('AQUA-ERROR-BEGIN\n${details.toString()}\nAQUA-ERROR-END');
    previous?.call(details);
  };
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<AppServices> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    // Reduced motion keeps frames deterministic; accessible navigation makes
    // the eco-map render its list view, so no map tiles are fetched.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true, disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    _traceErrors();
    final services = (await tester.runAsync(() => AppServices.bootstrap(startSensors: false)))!;
    await tester.pumpWidget(AquaAwareApp(services: services));
    await settle(tester);
    expect(find.text('Sign in'), findsWidgets);
    return services;
  }

  Future<void> signIn(WidgetTester tester, AppServices s, Role role) async {
    final result = await tester.runAsync(() => switch (role) {
          Role.student => s.auth.signInStudent(name: 'Priya', classCode: 'AWA-2024-GHS', pin: '2580'),
          Role.educator =>
            s.auth.signInWithSecret(role: Role.educator, loginId: 'kavitha@aquaaware.org', secret: 'Kavitha#2026'),
          Role.ngo => s.auth.signInWithSecret(role: Role.ngo, loginId: 'NGO001', secret: 'PSF-GREEN-2026'),
          Role.manager =>
            s.auth.signInWithSecret(role: Role.manager, loginId: 'admin@aquaaware.org', secret: 'Manager#2026!'),
        });
    expect(result?.ok, isTrue, reason: 'sign-in as ${role.label}: ${result?.message}');
    await settle(tester);
  }

  /// Opens every screen for [role] and reports all problems at once, so one
  /// run shows every screen that needs fixing.
  Future<void> visitAll(WidgetTester tester, Role role) async {
    final problems = <String>[];
    for (final path in _paths[role]!) {
      debugPrint('AQUA-VISIT $path as ${role.label}');
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
      await settle(tester);
      final error = tester.takeException();
      if (error != null) problems.add('$path as ${role.label}: $error');
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  }

  Future<void> signOut(WidgetTester tester, AppServices s) async {
    await tester.runAsync(() => s.auth.signOut());
    await settle(tester);
    expect(find.text('Sign in'), findsWidgets);
  }

  for (final size in [_phone, _desktop]) {
    final label = size == _phone ? 'phone' : 'desktop';

    testWidgets('every role opens every screen without errors ($label)', (tester) async {
      final s = await boot(tester, size);
      // A navigation label only that role's shell has.
      const marker = {
        Role.student: 'Eco-map',
        Role.educator: 'Insights',
        Role.ngo: 'Reward desk',
        Role.manager: 'Directory',
      };
      for (final role in Role.values) {
        await signIn(tester, s, role);
        expect(find.text(marker[role]!), findsWidgets, reason: 'landed on the ${role.label} home');
        await visitAll(tester, role);
        await signOut(tester, s);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('everyone can see who made AquaAware, even before signing in', (tester) async {
    await boot(tester, _phone);
    // The credit under the sign-in form.
    expect(find.text('${AppInfo.authorDegree} · ${AppInfo.authorInstitution}'), findsOneWidget);
    // The About page opens without an account and shows the author's message.
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/about');
    await settle(tester);
    expect(find.text(AppInfo.author), findsOneWidget);
    expect(find.text(AppInfo.missionTitle), findsWidgets);
    expect(find.text(AppInfo.mission.last), findsOneWidget);
    expect(find.text(AppInfo.copyright), findsOneWidget);
    expect(find.text('Office'), findsOneWidget, reason: 'the page lists every kind of group');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an office employee sees office words', (tester) async {
    final s = await boot(tester, _phone);
    final r = await tester.runAsync(() => s.auth.signInStudent(name: 'Ravi', classCode: 'AWA-2026-CTP', pin: '4826'));
    expect(r?.ok, isTrue, reason: r?.message);
    await settle(tester);
    // The 4W line at the top of home speaks of work, not school.
    expect(find.textContaining(RegExp('at work|Away from work')), findsWidgets);
    expect(find.textContaining('AWA-2026-CTP'), findsWidgets);
    expect(tester.takeException(), isNull);
    await signOut(tester, s);

    final lead = await tester.runAsync(
        () => s.auth.signInWithSecret(role: Role.educator, loginId: 'deepa@aquaaware.org', secret: 'Deepa#2026'));
    expect(lead?.ok, isTrue, reason: lead?.message);
    await settle(tester);
    expect(find.text('Team'), findsWidgets, reason: 'the navigation says Team, not Class');
    expect(find.text('Employees'), findsWidgets);
    expect(tester.takeException(), isNull);
    await signOut(tester, s);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student claims a reward and sees a QR ticket', (tester) async {
    final s = await boot(tester, _phone);
    await signIn(tester, s, Role.student);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/student/rewards');
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Claim').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);

    expect(find.text('Reward ticket'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await signOut(tester, s);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('NGO desk schedules an event and shows its rotating check-in code', (tester) async {
    final s = await boot(tester, _phone);
    await signIn(tester, s, Role.ngo);
    await tester.runAsync(() => s.store.addActivity(
          desk: s.auth.user!,
          name: 'Test clean-up',
          date: DateTime.now().add(const Duration(days: 1)),
          place: 'Rock Beach',
        ));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/ngo/activities');
    await settle(tester);
    expect(find.text('Test clean-up'), findsOneWidget);

    await tester.tap(find.text('Show check-in code').first);
    await settle(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('New code in'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Navigator.of(tester.element(find.byType(QrImageView))).pop();
    await settle(tester);
    await signOut(tester, s);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('educator opens a student sheet; manager searches the directory', (tester) async {
    final s = await boot(tester, _phone);
    await signIn(tester, s, Role.educator);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/educator/class');
    await settle(tester);
    // The class list is alphabetical and long; search, as an educator would.
    await tester.enterText(find.byType(TextField).first, 'Pranil');
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Pranil').first);
    await settle(tester);
    expect(find.text('Message in AquaAware'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Message in AquaAware'))).pop();
    await settle(tester);
    await signOut(tester, s);

    await signIn(tester, s, Role.manager);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/manager/directory');
    await settle(tester);
    for (final tab in ['Leaders', 'NGOs', 'Members']) {
      await tester.tap(find.text(tab).first);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.enterText(find.byType(TextField).first, 'Priya');
    await settle(tester);
    expect(find.text('1 result'), findsOneWidget);
    await signOut(tester, s);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// Pumps a few frames without waiting for endless animations to stop.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}
