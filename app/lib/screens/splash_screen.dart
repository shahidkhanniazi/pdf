import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// Animated splash. Loads the saved library (or downloads it the first time)
/// and then goes to onboarding or the dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final app = context.read<AppState>();
    final minimum = Future.delayed(const Duration(milliseconds: 1800));
    if (app.onboarded) {
      try {
        await app.start();
      } catch (e, st) {
        debugPrint('Library failed to load: $e\n$st');
      }
    }
    await minimum;
    if (!mounted) return;
    final Widget next =
        app.onboarded ? const HomeShell() : const OnboardingScreen();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => next,
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S(app.lang);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(.2, 1, curve: Curves.easeOut));
    final rise = Tween(begin: const Offset(0, .15), end: Offset.zero).animate(fade);
    return Scaffold(
      backgroundColor: Brand.cinema,
      body: Stack(fit: StackFit.expand, children: [
        Opacity(
          opacity: .9,
          child: CustomPaint(
            painter: CoverPainter(
                paletteFor(const ['#160e07', '#6b3f1c', '#e2b85c'], 0), 'dome', 0),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87],
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            FadeTransition(
              opacity: fade,
              child: SlideTransition(position: rise, child: const Logo(size: 46)),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: fade,
              child: Text(s.t('tagline'),
                  textDirection: s.isUrdu ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: s.isUrdu ? fontUrdu : fontBody,
                    fontStyle: s.isUrdu ? FontStyle.normal : FontStyle.italic,
                    fontSize: 16,
                    height: s.isUrdu ? 2 : 1.3,
                  )),
            ),
            const Spacer(flex: 3),
            if (app.syncing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: LinearProgressIndicator(
                  value: app.syncProgress == 0 ? null : app.syncProgress,
                  color: Brand.gold,
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 12),
              Text(s.t('downloading_library'),
                  textDirection: s.isUrdu ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                      color: Colors.white70,
                      fontFamily: s.isUrdu ? fontUrdu : fontUi,
                      height: s.isUrdu ? 2 : 1.3)),
            ] else
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Brand.gold),
              ),
            const SizedBox(height: 48),
          ]),
        ),
      ]),
    );
  }
}

/// The "Something Historic" word mark, like the site header.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 28, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('SOMETHING',
            style: TextStyle(
              fontFamily: fontUi,
              fontSize: size * .28,
              letterSpacing: size * .18,
              fontWeight: FontWeight.w600,
              color: Brand.gold,
            )),
        Text('Historic',
            style: TextStyle(
              fontFamily: fontHeading,
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.05,
            )),
      ]),
    );
  }
}
