// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/security/input_rules.dart';
import '../../core/utils/geo.dart';
import '../../data/app_store.dart';
import '../../data/seed/community_seed.dart';
import '../../widgets/common.dart';
import '../../widgets/eco_map.dart';

/// Every collector, school and NGO as map places. [ownNgoId] marks the
/// signed-in NGO so it stands out in the list and on the map.
List<MapPlace> communityPlaces(AppStore store, {String? ownNgoId}) => [
      for (final c in CommunitySeed.collectors)
        MapPlace(
          id: c.id,
          name: c.name,
          subtitle: '${c.wasteType} collector · ${c.area}',
          point: c.location,
          kind: PlaceKind.collector,
          status: store.collectorBusy(c) ? 'Busy' : 'Available',
          statusTone: store.collectorBusy(c) ? Tone.danger : Tone.success,
        ),
      for (final sc in CommunitySeed.schools)
        MapPlace(id: sc.id, name: sc.name, subtitle: sc.type, point: sc.location, kind: PlaceKind.school),
      for (final n in CommunitySeed.ngos)
        MapPlace(
          id: n.id,
          name: n.name,
          subtitle: n.id == ownNgoId ? 'Your organisation · ${n.area}' : 'NGO partner · ${n.area}',
          point: n.location,
          kind: PlaceKind.ngo,
          status: n.id == ownNgoId ? 'You' : null,
          statusTone: Tone.info,
          icon: n.id == ownNgoId ? Icons.home_work_outlined : null,
        ),
    ];

/// Read-only details for any place, with a call button where a public
/// number exists. Collectors' and NGOs' numbers are published contact
/// numbers; students' personal numbers are never shown here.
Future<void> showPlaceSheet(BuildContext context, MapPlace p, {GeoPoint? origin}) {
  final ngo = p.kind == PlaceKind.ngo ? CommunitySeed.ngo(p.id) : null;
  final String? phone = switch (p.kind) {
    PlaceKind.collector => CommunitySeed.collector(p.id).phone,
    PlaceKind.ngo => ngo?.phone,
    PlaceKind.school => null,
  };
  final email = ngo?.email;
  final address = ngo?.address;
  final focus = ngo?.focus;
  final dialable = phone == null ? null : InputRules.normalizePhone(phone);
  final from = origin ?? CommunitySeed.city;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Semantics(header: true, child: Text(p.name, style: text.titleLarge))),
                if (p.status != null) Pill(p.status!, tone: p.statusTone),
              ],
            ),
            const SizedBox(height: 4),
            Text(p.subtitle, style: text.bodyMedium),
            Text(
              '${Geo.describeDistance(Geo.distanceMeters(from, p.point))} from ${origin == null ? 'the city centre' : 'you'}',
              style: text.bodySmall,
            ),
            if (focus != null) ...[
              const SizedBox(height: 12),
              Text(focus, style: text.bodyMedium),
            ],
            if (address != null) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: SelectableText(address),
              ),
            ],
            if (email != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: Text(email),
                onTap: () => unawaited(launchUrl(Uri(scheme: 'mailto', path: email))),
              ),
            if (dialable != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => unawaited(launchUrl(Uri(scheme: 'tel', path: dialable))),
                icon: const Icon(Icons.call_outlined),
                label: Text('Call ${phone ?? dialable}'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
