import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'services/app_services.dart';

class AquaAwareApp extends StatefulWidget {
  const AquaAwareApp({super.key, required this.services});
  final AppServices services;

  @override
  State<AquaAwareApp> createState() => _AquaAwareAppState();
}

class _AquaAwareAppState extends State<AquaAwareApp> {
  late final GoRouter _router = buildRouter(widget.services);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return AppScope(
      services: s,
      child: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) {
          final st = s.settings;
          return MaterialApp.router(
            title: 'AquaAware',
            debugShowCheckedModeBanner: false,
            theme: AqTheme.light(highContrast: st.highContrast),
            darkTheme: AqTheme.dark(highContrast: st.highContrast),
            highContrastTheme: AqTheme.light(highContrast: true),
            highContrastDarkTheme: AqTheme.dark(highContrast: true),
            themeMode: st.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              // Respect the system text size, then apply the in-app multiplier.
              final system = mq.textScaler.scale(16) / 16;
              final scale = (system * st.textScale).clamp(0.85, 2.2);
              WidgetsBinding.instance.addPostFrameCallback((_) => s.device.updateScreen(mq.size));
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(scale)),
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => s.auth.touch(),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
