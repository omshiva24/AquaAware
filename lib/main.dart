import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never show stack traces to users in release builds.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Material(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Something went wrong on this screen. Go back and try again.', textAlign: TextAlign.center),
            ),
          ),
        );
  }
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error');
    return true;
  };

  runApp(const _Boot());
}

/// Shows a branded splash while keys are loaded and data is decrypted.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  AppServices? _services;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_error != null) setState(() => _error = null);
    try {
      final s = await AppServices.bootstrap();
      if (mounted) setState(() => _services = s);
    } catch (e) {
      debugPrint('Start-up failed: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _services;
    if (s != null) return AquaAwareApp(services: s);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AqTheme.light(),
      darkTheme: AqTheme.dark(),
      home: Scaffold(
        backgroundColor: AqColors.ink,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.water_drop, color: AqColors.shallows, size: 56, semanticLabel: 'AquaAware'),
              const SizedBox(height: 16),
              Text('AquaAware',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontFamily: AqTheme.fontFamily)),
              const SizedBox(height: 24),
              if (_error == null)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6, color: AqColors.shallows),
                )
              else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'AquaAware could not open its secure storage. Restart the app; if it keeps happening, reinstall it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _start, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
