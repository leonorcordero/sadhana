import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/features/app_shell/presentation/home_shell.dart';

class StartupSplashPage extends ConsumerStatefulWidget {
  const StartupSplashPage({super.key});

  @override
  ConsumerState<StartupSplashPage> createState() => _StartupSplashPageState();
}

class _StartupSplashPageState extends ConsumerState<StartupSplashPage> {
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    _openHome();
  }

  Future<void> _openHome() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _showHome = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showHome) {
      return const HomeShell();
    }

    final settings = ref.watch(appSettingsProvider);
    final seedHsl = HSLColor.fromColor(settings.themeColor);
    final splashBackground = seedHsl
        .withSaturation((seedHsl.saturation * 0.28).clamp(0.0, 1.0))
        .withLightness(0.36)
        .toColor();

    return Scaffold(
      backgroundColor: splashBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/app_icon_nataraj_splash.png',
                  width: 360,
                  height: 360,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
