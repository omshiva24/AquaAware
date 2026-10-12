import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../widgets/adaptive_shell.dart';

class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final u = s.auth.user;
        final tasks = u == null ? 0 : s.store.openTasksFor(u).length;
        final newFiles = u?.classCode == null ? 0 : s.store.unseenResources(u!.classCode!, u.id);
        return AdaptiveShell(
          location: location,
          destinations: [
            ShellDestination(path: '/student', label: 'Home', icon: Icons.water_drop_outlined, selectedIcon: Icons.water_drop, badgeCount: tasks),
            ShellDestination(path: '/student/learn', label: 'Learn', icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book, badgeCount: newFiles),
            const ShellDestination(path: '/student/map', label: 'Eco-map', icon: Icons.map_outlined, selectedIcon: Icons.map),
            const ShellDestination(path: '/student/rewards', label: 'Rewards', icon: Icons.redeem_outlined, selectedIcon: Icons.redeem),
            const ShellDestination(path: '/student/profile', label: 'Me', icon: Icons.person_outline, selectedIcon: Icons.person),
          ],
          child: child,
        );
      },
    );
  }
}

class EducatorShell extends StatelessWidget {
  const EducatorShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final unread = s.auth.user == null ? 0 : s.store.unreadFor(s.auth.user!.id);
        return AdaptiveShell(
          location: location,
          destinations: [
            const ShellDestination(path: '/educator', label: 'Overview', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
            const ShellDestination(path: '/educator/class', label: 'Class', icon: Icons.groups_outlined, selectedIcon: Icons.groups),
            ShellDestination(path: '/educator/messages', label: 'Messages', icon: Icons.forum_outlined, selectedIcon: Icons.forum, badgeCount: unread),
            const ShellDestination(path: '/educator/resources', label: 'Resources', icon: Icons.folder_outlined, selectedIcon: Icons.folder),
            const ShellDestination(path: '/educator/insights', label: 'Insights', icon: Icons.insights_outlined, selectedIcon: Icons.insights),
          ],
          child: child,
        );
      },
    );
  }
}

class NgoShell extends StatelessWidget {
  const NgoShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(
      location: location,
      destinations: const [
        ShellDestination(path: '/ngo', label: 'Broadcasts', icon: Icons.campaign_outlined, selectedIcon: Icons.campaign),
        ShellDestination(path: '/ngo/activities', label: 'Activities', icon: Icons.event_outlined, selectedIcon: Icons.event),
        ShellDestination(path: '/ngo/verify', label: 'Reward desk', icon: Icons.qr_code_scanner, selectedIcon: Icons.qr_code_scanner),
        ShellDestination(path: '/ngo/map', label: 'Map', icon: Icons.map_outlined, selectedIcon: Icons.map),
      ],
      child: child,
    );
  }
}

class ManagerShell extends StatelessWidget {
  const ManagerShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(
      location: location,
      destinations: const [
        ShellDestination(path: '/manager', label: 'Overview', icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard),
        ShellDestination(path: '/manager/directory', label: 'Directory', icon: Icons.contacts_outlined, selectedIcon: Icons.contacts),
        ShellDestination(path: '/manager/map', label: 'Map', icon: Icons.map_outlined, selectedIcon: Icons.map),
      ],
      child: child,
    );
  }
}
