// Copyright (c) 2026 P Om Shiva. All rights reserved.
// Unauthorised copying, modification or distribution of this file, by any
// means, is prohibited without the author's written permission. See LICENSE.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/reservoir.dart';

/// The creator line shown under the sign-in form, so everyone who opens the
/// app sees who made it.
class CreatorCredit extends StatelessWidget {
  const CreatorCredit({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Column(
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Created by '),
              TextSpan(text: AppInfo.author, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
            ]),
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '${AppInfo.authorDegree} · ${AppInfo.authorInstitution}',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: () => context.push('/about'),
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text(AppInfo.missionTitle),
          ),
          Text(AppInfo.copyright, style: text.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Who made AquaAware, why, who it is for, and the copyright notice. Open
/// to everyone, signed in or not.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Semantics(header: true, child: const Text('About AquaAware'))),
      body: PageFrame(
        maxWidth: 720,
        children: [
          // The author, on deep water: the first thing anyone sees here.
          Card(
            clipBehavior: Clip.antiAlias,
            color: AqColors.tideDeep,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.water_drop, color: AqColors.shallows, size: 36),
                      const SizedBox(height: 10),
                      Text('${AppInfo.appName} ${AppInfo.version}',
                          style: text.labelLarge?.copyWith(color: AqColors.shallows)),
                      const SizedBox(height: 14),
                      Text('Created by', style: text.bodyMedium?.copyWith(color: Colors.white70)),
                      Text(AppInfo.author, style: text.headlineMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(AppInfo.authorDegreeLong, style: text.bodyMedium?.copyWith(color: Colors.white)),
                      Text(AppInfo.authorInstitution, style: text.bodyMedium?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
                WaveHorizon(color: Colors.white.withValues(alpha: 0.16), height: 28),
              ],
            ),
          ),

          const SectionHeader(AppInfo.missionTitle),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < AppInfo.mission.length; i++) ...[
                  Text(
                    AppInfo.mission[i],
                    style: i == AppInfo.mission.length - 1
                        ? text.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)
                        : text.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                ],
                Text('— ${AppInfo.missionSignature}', style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),

          const SectionHeader('Made for everyone'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Any group can use AquaAware. Its leader registers it and shares the code; '
                    'members join with that code and a PIN they choose.'),
                const SizedBox(height: 12),
                for (final k in InstitutionKind.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(kindIcon(k)),
                    title: Text(k.label),
                    subtitle: Text('A ${k.leaderNoun} and ${k.membersNoun}, joining with a ${k.codeLabel.toLowerCase()}'),
                  ),
              ],
            ),
          ),

          const SectionHeader('Copyright'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppInfo.copyright, style: text.titleMedium),
                const SizedBox(height: 8),
                const Text(AppInfo.licenceSummary),
                const SizedBox(height: 8),
                Text(
                  'Open-source libraries, the Atkinson Hyperlegible Next typeface and OpenStreetMap '
                  'map data are used under their own licences.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(AppInfo.authorGitHub), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Author on GitHub'),
                    ),
                    TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: AppInfo.appName,
                        applicationVersion: AppInfo.version,
                        applicationLegalese: '${AppInfo.copyright}\n${AppInfo.licenceSummary}',
                      ),
                      child: const Text('Open-source licences'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
