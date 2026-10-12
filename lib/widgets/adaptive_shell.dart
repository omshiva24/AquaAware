import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';

class ShellDestination {
  const ShellDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;
}

/// One navigation shell for every role and every screen size:
/// bottom bar on phones, rail on tablets, extended rail on desktop.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.destinations, required this.location, required this.child});

  final List<ShellDestination> destinations;
  final String location;
  final Widget child;

  int get _index {
    var best = 0;
    var bestLen = -1;
    for (var i = 0; i < destinations.length; i++) {
      final p = destinations[i].path;
      if ((location == p || location.startsWith('$p/')) && p.length > bestLen) {
        best = i;
        bestLen = p.length;
      }
    }
    return best;
  }

  Widget _icon(ShellDestination d, bool selected) {
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (d.badgeCount <= 0) return icon;
    return Badge(label: Text(d.badgeCount > 9 ? '9+' : '${d.badgeCount}'), child: icon);
  }

  String _semantic(ShellDestination d) =>
      d.badgeCount > 0 ? '${d.label}, ${d.badgeCount} new' : d.label;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final index = _index;
    void go(int i) {
      if (i != index) context.go(destinations[i].path);
    }

    if (width < 840) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: go,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: _icon(d, false),
                selectedIcon: _icon(d, true),
                label: d.label,
                tooltip: _semantic(d),
              ),
          ],
        ),
      );
    }

    final extended = width >= 1200;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: index,
            onDestinationSelected: go,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _Wordmark(extended: extended),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Tooltip(message: _semantic(d), child: _icon(d, false)),
                  selectedIcon: _icon(d, true),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(AqRadius.control)),
      child: Icon(Icons.water_drop, color: scheme.onPrimary, semanticLabel: 'AquaAware'),
    );
    if (!extended) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        ExcludeSemantics(
          child: Text('AquaAware', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
