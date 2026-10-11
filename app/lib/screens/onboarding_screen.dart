import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import 'splash_screen.dart';

/// Three intro pages, then language and theme choice.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  static const _slides = [
    ('onb_title_1', 'onb_body_1', 'dome', ['#160e07', '#7a3b1a', '#f2c27b'], Icons.auto_stories),
    ('onb_title_2', 'onb_body_2', 'fort', ['#0d1420', '#3b5a85', '#f0c98a'], Icons.account_balance),
    ('onb_title_3', 'onb_body_3', 'columns', ['#14231d', '#3f7a5c', '#e9d49a'], Icons.offline_pin),
  ];

  int get _count => _slides.length + 1;

  void _next() {
    if (_index < _count - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final app = context.read<AppState>();
    app.onboarded = true;
    await NotificationService.instance.requestPermission();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S(app.lang);
    final last = _index == _count - 1;
    return Scaffold(
      backgroundColor: Brand.cinema,
      body: Stack(children: [
        PageView.builder(
          controller: _page,
          itemCount: _count,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            if (i == _slides.length) return _ChoicesPage(s: s);
            final slide = _slides[i];
            return _Slide(
              title: s.t(slide.$1),
              body: s.t(slide.$2),
              shape: slide.$3,
              palette: slide.$4,
              icon: slide.$5,
              urdu: s.isUrdu,
            );
          },
        ),
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: last
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _page.animateToPage(_count - 1,
                        duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
                    child: Text(s.t('skip'), style: const TextStyle(color: Colors.white70)),
                  ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(children: [
                Row(
                  children: List.generate(
                    _count,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? Brand.gold : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.gold,
                    foregroundColor: const Color(0xFF1A1208),
                  ),
                  onPressed: _next,
                  child: Text(last ? s.t('get_started') : s.t('next')),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.title,
    required this.body,
    required this.shape,
    required this.palette,
    required this.icon,
    required this.urdu,
  });

  final String title, body, shape;
  final List<String> palette;
  final IconData icon;
  final bool urdu;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Column(children: [
      SizedBox(
        height: size.height * .52,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: CoverPainter(paletteFor(palette, 0), shape, 3)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Brand.cinema],
                stops: [.6, 1],
              ),
            ),
          ),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Brand.gold, size: 30),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                  fontFamily: urdu ? fontUrdu : fontHeading,
                  fontWeight: FontWeight.w700,
                  fontSize: urdu ? 24 : 30,
                  height: urdu ? 1.9 : 1.15,
                  color: Colors.white,
                )),
            const SizedBox(height: 12),
            Text(body,
                style: TextStyle(
                  fontFamily: urdu ? fontUrdu : fontBody,
                  fontSize: 16,
                  height: urdu ? 2.1 : 1.6,
                  color: Colors.white70,
                )),
          ]),
        ),
      ),
    ]);
  }
}

class _ChoicesPage extends StatelessWidget {
  const _ChoicesPage({required this.s});
  final S s;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final urdu = s.isUrdu;
    TextStyle head = TextStyle(
      fontFamily: urdu ? fontUrdu : fontHeading,
      fontWeight: FontWeight.w700,
      fontSize: urdu ? 20 : 24,
      height: urdu ? 1.9 : 1.2,
      color: Colors.white,
    );

    Widget option(String label, bool selected, VoidCallback onTap, {IconData? icon, String? font}) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? Brand.gold.withValues(alpha: .16) : Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Brand.gold : Colors.white24, width: selected ? 2 : 1),
            ),
            child: Column(children: [
              if (icon != null) Icon(icon, color: selected ? Brand.gold : Colors.white70),
              if (icon != null) const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: font ?? (urdu ? fontUrdu : fontUi),
                    fontSize: 15,
                    height: (font ?? (urdu ? fontUrdu : '')) == fontUrdu ? 1.9 : 1.3,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: Logo(size: 40)),
          const SizedBox(height: 40),
          Text(s.t('choose_language'), style: head),
          const SizedBox(height: 12),
          Row(children: [
            option('English', app.lang == 'en', () => app.lang = 'en', font: fontUi, icon: Icons.translate),
            const SizedBox(width: 12),
            option('اردو', app.lang == 'ur', () => app.lang = 'ur', font: fontUrdu, icon: Icons.translate),
          ]),
          const SizedBox(height: 32),
          Text(s.t('choose_theme'), style: head),
          const SizedBox(height: 12),
          Row(children: [
            option(s.t('theme_light'), app.themeMode == ThemeMode.light,
                () => app.themeMode = ThemeMode.light, icon: Icons.light_mode_outlined),
            const SizedBox(width: 10),
            option(s.t('theme_dark'), app.themeMode == ThemeMode.dark,
                () => app.themeMode = ThemeMode.dark, icon: Icons.dark_mode_outlined),
            const SizedBox(width: 10),
            option(s.t('theme_system'), app.themeMode == ThemeMode.system,
                () => app.themeMode = ThemeMode.system, icon: Icons.brightness_auto_outlined),
          ]),
        ]),
      ),
    );
  }
}
