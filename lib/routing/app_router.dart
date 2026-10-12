import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';
import '../data/models/models.dart';
import '../features/auth/login_screen.dart';
import '../features/educator/educator_screens.dart';
import '../features/manager/manager_screens.dart';
import '../features/ngo/ngo_screens.dart';
import '../features/shared/gallery_screen.dart';
import '../features/shared/scan_screen.dart';
import '../features/shared/security_center.dart';
import '../features/shared/settings_screen.dart';
import '../features/shared/thread_screen.dart';
import '../features/student/claim_screen.dart';
import '../features/student/learn_screens.dart';
import '../features/student/pickup_screen.dart';
import '../features/student/quiz_screen.dart';
import '../features/student/sort_game_screen.dart';
import '../features/student/student_screens.dart';
import '../services/app_services.dart';
import 'shells.dart';

/// Role-based access control. The old app let any role open any screen
/// (an NGO could open the student scanner). Every route prefix now declares
/// who may enter; anyone else is sent to their own home.
abstract final class RouteAccess {
  static const Map<String, Set<Role>> _rules = {
    '/student': {Role.student},
    '/educator': {Role.educator},
    '/ngo': {Role.ngo},
    '/manager': {Role.manager},
    '/learn': {Role.student},
    '/quiz': {Role.student},
    '/sort': {Role.student},
    '/claim': {Role.student},
    '/pickup': {Role.student},
    '/scan': {Role.student, Role.ngo},
    '/thread': {Role.student, Role.educator},
  };

  /// Null means any signed-in role may open the route.
  static Set<Role>? allowedFor(String location) {
    for (final e in _rules.entries) {
      if (location == e.key || location.startsWith('${e.key}/')) return e.value;
    }
    return null;
  }
}

Page<void> _page(GoRouterState state, Widget child, {bool quick = false}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: quick ? 180 : 320),
    reverseTransitionDuration: Duration(milliseconds: quick ? 140 : 260),
    transitionsBuilder: (context, animation, secondary, child) {
      if (context.reduceMotion) return child;
      final curved = CurvedAnimation(parent: animation, curve: AqMotion.emphasized);
      if (quick) return FadeTransition(opacity: curved, child: child);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

GoRoute _tab(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, pageBuilder: (context, state) => _page(state, build(state), quick: true));

GoRoute _full(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, pageBuilder: (context, state) => _page(state, build(state)));

GoRouter buildRouter(AppServices services) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: services.auth,
    redirect: (context, state) {
      final user = services.auth.user;
      final loc = state.matchedLocation;
      if (user == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/') return user.role.home;
      final allowed = RouteAccess.allowedFor(loc);
      if (allowed != null && !allowed.contains(user.role)) return user.role.home;
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      _full('/login', (s) => const LoginScreen()),

      ShellRoute(
        builder: (context, state, child) => StudentShell(location: state.uri.path, child: child),
        routes: [
          _tab('/student', (s) => const StudentHomeScreen()),
          _tab('/student/learn', (s) => const LearnScreen()),
          _tab('/student/map', (s) => const StudentMapScreen()),
          _tab('/student/rewards', (s) => const RewardsScreen()),
          _tab('/student/profile', (s) => const ProfileScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => EducatorShell(location: state.uri.path, child: child),
        routes: [
          _tab('/educator', (s) => const EducatorOverviewScreen()),
          _tab('/educator/class', (s) => const EducatorClassScreen()),
          _tab('/educator/messages', (s) => const EducatorMessagesScreen()),
          _tab('/educator/resources', (s) => const EducatorResourcesScreen()),
          _tab('/educator/insights', (s) => const EducatorInsightsScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => NgoShell(location: state.uri.path, child: child),
        routes: [
          _tab('/ngo', (s) => const NgoBroadcastsScreen()),
          _tab('/ngo/activities', (s) => const NgoActivitiesScreen()),
          _tab('/ngo/verify', (s) => const NgoVerifyScreen()),
          _tab('/ngo/map', (s) => const NgoMapScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ManagerShell(location: state.uri.path, child: child),
        routes: [
          _tab('/manager', (s) => const ManagerOverviewScreen()),
          _tab('/manager/directory', (s) => const ManagerDirectoryScreen()),
          _tab('/manager/map', (s) => const ManagerMapScreen()),
        ],
      ),

      _full('/learn/:id', (s) => ModulePlayerScreen(moduleId: s.pathParameters['id']!)),
      _full('/quiz/:id', (s) => QuizScreen(moduleId: s.pathParameters['id']!)),
      _full('/sort', (s) => const SortGameScreen()),
      _full('/claim/:id', (s) => ClaimScreen(claimId: s.pathParameters['id']!)),
      _full('/pickup/:id', (s) => PickupScreen(pickupId: s.pathParameters['id']!)),
      _full('/scan', (s) => const ScanScreen()),
      _full('/thread/:peer', (s) => ThreadScreen(peerId: s.pathParameters['peer']!)),
      _full('/gallery', (s) => const GalleryScreen()),
      _full('/settings', (s) => const SettingsScreen()),
      _full('/security', (s) => const SecurityCenterScreen()),
    ],
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.water_drop_outlined, size: 48),
              const SizedBox(height: 12),
              Text('This page dried up.', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('The link may be old. Go back to your home screen.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.go('/'), child: const Text('Go home')),
            ],
          ),
        ),
      ),
    );
  }
}
