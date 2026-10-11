import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/repository.dart';
import '../l10n/strings.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'splash_screen.dart';

/// Saved items, history, theme, language, notifications and content updates.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final theme = Theme.of(context);
    final last = app.lastSync;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Eyebrow(text),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('more')), actions: appBarActions(context)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Logo(size: 30, color: theme.colorScheme.onSurface),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: Text(s.t('bookmarks')),
            trailing: Text('${app.bookmarks.length}'),
            onTap: () => push(context, const SavedScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(s.t('history')),
            onTap: () => push(context, const HistoryScreen()),
          ),
          header(s.t('appearance')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(s.t('theme_light'))),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(s.t('theme_dark'))),
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(s.t('theme_system'))),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (v) => app.themeMode = v.first,
            ),
          ),
          header(s.t('language')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ur', label: Text('اردو')),
              ],
              selected: {app.lang},
              onSelectionChanged: (v) => app.lang = v.first,
            ),
          ),
          header(s.t('reading')),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(s.t('text_size')),
            subtitle: Slider(
              value: app.textScale,
              min: .8,
              max: 1.6,
              divisions: 8,
              label: '${(app.textScale * 100).round()}%',
              onChanged: (v) => app.textScale = v,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(s.t('notify_new')),
            value: app.notifyNew,
            onChanged: (v) => app.notifyNew = v,
          ),
          header(s.t('content')),
          ListTile(
            leading: const Icon(Icons.offline_pin_outlined),
            title: Text(s.t('library_size', {'n': app.bundle.totalCount})),
            subtitle: Text(app.source == LibrarySource.site && last != null
                ? s.t('last_updated', {'d': s.date(last)})
                : s.t('never_updated')),
          ),
          ListTile(
            leading: app.syncing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            title: Text(app.syncing ? s.t('updating') : s.t('update_now')),
            onTap: app.syncing ? null : () => refreshLibrary(context),
          ),
          header(s.t('about')),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(s.t('visit_site')),
            onTap: () => launchUrl(Uri.parse(AppConfig.siteUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(s.t('rate_app')),
            onTap: () => SharePlus.instance.share(ShareParams(
                text: '${s.t('app_name')}: ${s.t('tagline')}\n${AppConfig.siteUrl}')),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(s.t('version', {'v': '1.0.0'}),
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final items = app.bookmarks;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('bookmarks'))),
      body: items.isEmpty
          ? EmptyView(s.t('empty_saved'), icon: Icons.bookmark_outline)
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => EntryTile(
                items[i],
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  onPressed: () => app.toggleBookmark(items[i]),
                ),
              ),
            ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final items = app.history;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('history')),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: s.t('clear_history'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: app.clearHistory,
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyView(s.t('empty_history'), icon: Icons.history)
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => EntryTile(
                items[i].$1,
                trailing: items[i].$2 > 0
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
                        child: Text('${(items[i].$2 * 100).round()}%',
                            style: Theme.of(context).textTheme.bodySmall),
                      )
                    : null,
              ),
            ),
    );
  }
}
