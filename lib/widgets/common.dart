// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';
import '../data/models/models.dart';
import '../services/app_services.dart';

/// Centres page content with a readable max width and the standard gutter.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.children, this.padding, this.controller, this.maxWidth = AqSpace.maxContent});
  final List<Widget> children;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          controller: controller,
          padding: padding ?? const EdgeInsets.fromLTRB(AqSpace.gutter, 8, AqSpace.gutter, 32),
          children: children,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.subtitle});
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: text.titleLarge)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// A grouped surface. Outlined, not shadowed — elevation is reserved for
/// things that actually float.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, this.semanticLabel});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      color: color,
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              label: semanticLabel,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

class StatItem {
  const StatItem(this.label, this.value, {this.icon, this.tone});
  final String label;
  final String value;
  final IconData? icon;
  final Color? tone;
}

/// Several numbers in one panel, separated by hairlines — one surface rather
/// than a row of identical cards. Wraps to two columns on narrow screens.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.items});
  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget cell(StatItem s) => Semantics(
          container: true,
          label: '${s.label}: ${s.value}',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (s.icon != null) ...[
                        Icon(s.icon, size: 18, color: s.tone ?? scheme.primary),
                        const SizedBox(width: 6),
                      ],
                      Flexible(child: Text(s.label, style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(s.value, style: text.headlineSmall),
                ],
              ),
            ),
          ),
        );

    return Card(
      child: LayoutBuilder(builder: (context, c) {
        final perRow = c.maxWidth < 420 && items.length > 2 ? 2 : items.length;
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i += perRow) {
          final slice = items.sublist(i, math.min(i + perRow, items.length));
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < slice.length; j++) ...[
                  if (j > 0) VerticalDivider(width: 1, color: scheme.outlineVariant),
                  Expanded(child: cell(slice[j])),
                ],
              ],
            ),
          ));
          if (i + perRow < items.length) rows.add(const Divider(height: 1));
        }
        return Column(children: rows);
      }),
    );
  }
}

enum Tone { neutral, info, success, warning, danger }

({Color bg, Color fg, IconData icon}) toneColors(BuildContext context, Tone tone) {
  final s = Theme.of(context).colorScheme;
  return switch (tone) {
    Tone.neutral => (bg: s.surfaceContainerHigh, fg: s.onSurface, icon: Icons.info_outline),
    Tone.info => (bg: s.primaryContainer, fg: s.onPrimaryContainer, icon: Icons.info_outline),
    Tone.success => (bg: s.tertiaryContainer, fg: s.onTertiaryContainer, icon: Icons.check_circle_outline),
    Tone.warning => (bg: s.secondaryContainer, fg: s.onSecondaryContainer, icon: Icons.warning_amber_rounded),
    Tone.danger => (bg: s.errorContainer, fg: s.onErrorContainer, icon: Icons.error_outline),
  };
}

/// An inline note. Tone is carried by icon and words as well as colour.
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.tone = Tone.info, this.icon, this.action});
  final String text;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(AqRadius.control)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? c.icon, color: c.fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.fg)),
                if (action != null) Padding(padding: const EdgeInsets.only(top: 6), child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = Tone.neutral, this.icon});
  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(AqRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: c.fg), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 44, color: scheme.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(message, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 14), child: action),
        ],
      ),
    );
  }
}

/// A filled button that runs an async action, shows progress, and can't be
/// double-tapped (no duplicate submissions).
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.icon, this.busyLabel, this.tonal = false, this.expand = true});
  final String label;
  final String? busyLabel;
  final IconData? icon;
  final Future<void> Function()? onPressed;
  final bool tonal;
  final bool expand;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    final action = widget.onPressed;
    if (_busy || action == null) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
              const SizedBox(width: 12),
              Flexible(child: Text(widget.busyLabel ?? 'Working…', overflow: TextOverflow.ellipsis)),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final button = widget.tonal
        ? FilledButton.tonal(onPressed: onPressed, child: child)
        : FilledButton(onPressed: onPressed, child: child);
    return Semantics(
      liveRegion: _busy,
      child: widget.expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Network image with Q1 adaptive quality, a calm placeholder, an offline
/// fallback, and alt text for screen readers.
class AdaptiveImage extends StatelessWidget {
  const AdaptiveImage({super.key, required this.seed, required this.alt, this.width = 800, this.height = 500, this.fit = BoxFit.cover});
  final String seed;
  final String alt;
  final int width;
  final int height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final low = s.settings.dataSaver || s.device.isCellular || s.device.lowEndDevice;
    final w = low ? (width / 3).round() : width;
    final h = low ? (height / 3).round() : height;
    final url = 'https://picsum.photos/seed/aquaaware-$seed/$w/$h';
    final scheme = Theme.of(context).colorScheme;
    Widget fallback(IconData icon) => Container(
          color: scheme.primaryContainer,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: scheme.onPrimaryContainer),
              const SizedBox(height: 6),
              Text(alt, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
            ],
          ),
        );
    return Image.network(
      url,
      fit: fit,
      semanticLabel: alt,
      filterQuality: low ? FilterQuality.low : FilterQuality.medium,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(color: scheme.surfaceContainerHigh, alignment: Alignment.center,
              child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      errorBuilder: (context, error, stack) => fallback(Icons.image_not_supported_outlined),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// The icon for each kind of group, used wherever groups are listed.
IconData kindIcon(InstitutionKind kind) => switch (kind) {
      InstitutionKind.school => Icons.school_outlined,
      InstitutionKind.college => Icons.account_balance_outlined,
      InstitutionKind.office => Icons.business_center_outlined,
      InstitutionKind.community => Icons.groups_outlined,
    };

class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});
  final Role role;

  @override
  Widget build(BuildContext context) {
    final tone = switch (role) {
      Role.student => Tone.info,
      Role.educator => Tone.neutral,
      Role.ngo => Tone.success,
      Role.manager => Tone.warning,
    };
    return Pill(role.label, tone: tone);
  }
}

/// The account button in every app bar: settings, privacy, gallery, sign out.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.services.auth.user;
    final initials = (user?.name ?? '?')
        .split(' ')
        .where((p) => p.isNotEmpty && !p.endsWith('.'))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return PopupMenuButton<String>(
      tooltip: 'Account and settings',
      position: PopupMenuPosition.under,
      onSelected: (v) async {
        switch (v) {
          case 'settings':
            context.push('/settings');
          case 'security':
            context.push('/security');
          case 'gallery':
            context.push('/gallery');
          case 'about':
            context.push('/about');
          case 'signout':
            final ok = await confirmAction(context,
                title: 'Sign out?', message: 'You will need your details to sign in again.', confirmLabel: 'Sign out');
            if (ok && context.mounted) await context.services.auth.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user?.name ?? '', style: Theme.of(context).textTheme.titleSmall),
            // Their own group's word: Student, Employee, Teacher, Team lead…
            subtitle: user == null
                ? null
                : Text(roleTitle(user.role, context.services.store.kindOf(user.classCode))),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.tune), title: Text('Settings and accessibility'))),
        const PopupMenuItem(value: 'security', child: ListTile(leading: Icon(Icons.shield_outlined), title: Text('Privacy and security'))),
        const PopupMenuItem(value: 'gallery', child: ListTile(leading: Icon(Icons.photo_library_outlined), title: Text('Impact gallery'))),
        const PopupMenuItem(value: 'about', child: ListTile(leading: Icon(Icons.water_drop_outlined), title: Text('About AquaAware'))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'signout', child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out'))),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
    );
  }
}

/// Standard app bar: title on the left, account button on the right.
PreferredSizeWidget aqAppBar(BuildContext context, String title, {List<Widget> actions = const [], Widget? leading, bool account = true}) {
  return AppBar(
    leading: leading,
    title: Semantics(header: true, child: Text(title)),
    actions: [...actions, if (account) const AccountButton(), const SizedBox(width: 8)],
  );
}
