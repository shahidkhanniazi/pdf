import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../router.dart';
import '../services/ads.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import 'blog_screen.dart';
import 'dashboard_screen.dart';
import 'explore_screen.dart';
import 'more_screen.dart';
import 'stories_screen.dart';

/// Bottom navigation: Home, Stories, Explore, Blog, More.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taps = NotificationService.instance.taps.stream.listen(_openPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final launch = NotificationService.instance.launchPayload;
      if (launch != null) {
        NotificationService.instance.launchPayload = null;
        _openPayload(launch);
      }
      context.read<AppState>().maybeCheckForUpdates();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().maybeCheckForUpdates();
    }
  }

  void _openPayload(String payload) {
    if (!mounted) return;
    final parts = payload.split('|');
    if (parts.length == 2) openEntryKey(context, parts[1], lang: parts[0]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (!context.watch<AppState>().ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      DashboardScreen(onTab: (i) => setState(() => _tab = i)),
      const StoriesScreen(),
      const ExploreScreen(),
      const BlogScreen(),
      const MoreScreen(),
    ];
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdView(),
            NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: s.t('home')),
                NavigationDestination(
                    icon: const Icon(Icons.auto_stories_outlined),
                    selectedIcon: const Icon(Icons.auto_stories),
                    label: s.t('stories')),
                NavigationDestination(
                    icon: const Icon(Icons.explore_outlined),
                    selectedIcon: const Icon(Icons.explore),
                    label: s.t('explore')),
                NavigationDestination(
                    icon: const Icon(Icons.article_outlined),
                    selectedIcon: const Icon(Icons.article),
                    label: s.t('blog')),
                NavigationDestination(
                    icon: const Icon(Icons.menu),
                    selectedIcon: const Icon(Icons.menu_open),
                    label: s.t('more')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
