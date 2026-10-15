// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/theme/tokens.dart';
import '../core/utils/geo.dart';
import '../data/seed/community_seed.dart';
import '../services/app_services.dart';
import 'common.dart';

enum PlaceKind {
  collector('Collectors', Icons.recycling),
  school('Schools, colleges and offices', Icons.school_outlined),
  ngo('NGOs', Icons.volunteer_activism_outlined);

  const PlaceKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class MapPlace {
  const MapPlace({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.point,
    required this.kind,
    this.status,
    this.statusTone = Tone.neutral,
    this.icon,
  });
  final String id;
  final String name;
  final String subtitle;
  final GeoPoint point;
  final PlaceKind kind;
  final String? status;
  final Tone statusTone;
  final IconData? icon;
}

/// OpenStreetMap on every platform (the old app showed "map only on mobile"
/// on the web). Pins carry an icon and a status word, never colour alone,
/// and a list view gives the same information without the map — it opens by
/// default when a screen reader is running.
class EcoMap extends StatefulWidget {
  const EcoMap({
    super.key,
    required this.places,
    this.me,
    this.onSelect,
    this.kinds = const {PlaceKind.collector, PlaceKind.school, PlaceKind.ngo},
  });

  final List<MapPlace> places;
  final GeoPoint? me;
  final ValueChanged<MapPlace>? onSelect;
  final Set<PlaceKind> kinds;

  @override
  State<EcoMap> createState() => _EcoMapState();
}

class _EcoMapState extends State<EcoMap> {
  final MapController _controller = MapController();
  late Set<PlaceKind> _visible = {...widget.kinds};
  bool? _listView;

  Color _kindColor(PlaceKind k, ColorScheme s) => switch (k) {
        PlaceKind.collector => s.primary,
        PlaceKind.school => AqColors.ochreInk,
        PlaceKind.ngo => s.tertiary,
      };

  GeoPoint get _origin => widget.me ?? CommunitySeed.city;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listView = _listView ?? MediaQuery.of(context).accessibleNavigation;
    final shown = widget.places.where((p) => _visible.contains(p.kind)).toList()
      ..sort((a, b) => Geo.distanceMeters(_origin, a.point).compareTo(Geo.distanceMeters(_origin, b.point)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AqSpace.gutter, 4, AqSpace.gutter, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final k in widget.kinds)
                FilterChip(
                  avatar: Icon(k.icon, size: 18, color: _kindColor(k, scheme)),
                  label: Text(k.label),
                  selected: _visible.contains(k),
                  showCheckmark: false,
                  onSelected: (on) => setState(() => on ? _visible.add(k) : _visible.remove(k)),
                ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.map_outlined), label: Text('Map')),
                  ButtonSegment(value: true, icon: Icon(Icons.list_alt), label: Text('List')),
                ],
                selected: {listView},
                onSelectionChanged: (s) => setState(() => _listView = s.first),
              ),
            ],
          ),
        ),
        if (context.services.device.isOffline && !listView)
          const Padding(
            padding: EdgeInsets.fromLTRB(AqSpace.gutter, 0, AqSpace.gutter, 10),
            child: InfoNote('You are offline. Map tiles you have seen before still load; the list works fully offline.',
                tone: Tone.warning, icon: Icons.cloud_off_outlined),
          ),
        Expanded(child: listView ? _list(shown, scheme) : _map(shown, scheme)),
      ],
    );
  }

  Widget _map(List<MapPlace> shown, ColorScheme scheme) {
    final me = widget.me;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: LatLng(_origin.lat, _origin.lng),
            initialZoom: 12.5,
            minZoom: 9,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.aquaaware.app',
            ),
            MarkerLayer(
              markers: [
                for (final p in shown)
                  Marker(
                    point: LatLng(p.point.lat, p.point.lng),
                    width: 48,
                    height: 48,
                    child: _Pin(
                      place: p,
                      color: _kindColor(p.kind, scheme),
                      distance: Geo.describeDistance(Geo.distanceMeters(_origin, p.point)),
                      onTap: widget.onSelect == null ? null : () => widget.onSelect!(p),
                    ),
                  ),
                if (me != null)
                  Marker(
                    point: LatLng(me.lat, me.lng),
                    width: 28,
                    height: 28,
                    child: Semantics(
                      label: 'Your location',
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 4)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
            child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 11, color: Colors.black87)),
          ),
        ),
        if (me != null)
          Positioned(
            right: 12,
            top: 12,
            child: FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Centre on my location',
              onPressed: () => _controller.move(LatLng(me.lat, me.lng), 14),
              child: const Icon(Icons.my_location),
            ),
          ),
      ],
    );
  }

  Widget _list(List<MapPlace> shown, ColorScheme scheme) {
    if (shown.isEmpty) {
      return const EmptyState(icon: Icons.layers_clear_outlined, title: 'Nothing to show', message: 'Turn on a layer above.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AqSpace.gutter, 0, AqSpace.gutter, 24),
      itemCount: shown.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = shown[i];
        final dist = Geo.describeDistance(Geo.distanceMeters(_origin, p.point));
        return Card(
          child: ListTile(
            onTap: widget.onSelect == null ? null : () => widget.onSelect!(p),
            leading: CircleAvatar(
              backgroundColor: _kindColor(p.kind, scheme).withValues(alpha: 0.14),
              foregroundColor: _kindColor(p.kind, scheme),
              child: Icon(p.icon ?? p.kind.icon),
            ),
            title: Text(p.name),
            subtitle: Text('${p.subtitle} · $dist ${widget.me == null ? 'from the city centre' : 'away'}'),
            trailing: p.status == null ? null : Pill(p.status!, tone: p.statusTone),
          ),
        );
      },
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.place, required this.color, required this.distance, this.onTap});
  final MapPlace place;
  final Color color;
  final String distance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final busy = place.statusTone == Tone.danger || place.statusTone == Tone.warning;
    return Semantics(
      button: onTap != null,
      label: '${place.name}, ${place.subtitle}${place.status == null ? '' : ', ${place.status}'}, $distance',
      child: Tooltip(
        message: place.status == null ? place.name : '${place.name} — ${place.status}',
        child: Material(
          color: color,
          shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(place.icon ?? place.kind.icon, color: Colors.white, size: 22),
                if (busy)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.remove, size: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
