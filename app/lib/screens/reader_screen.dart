import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover.dart';
import 'stories_screen.dart';

/// Reads an episode or a blog post, fully offline.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.entry});
  final Entry entry;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);
  late final AppState _app = context.read<AppState>();
  DateTime _lastSave = DateTime.now();
  bool _restored = false;

  Entry get e => widget.entry;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final saved = _app.progressOf(e);
    _app.recordProgress(e, saved);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore(saved));
  }

  /// Jump back to where the reader stopped last time.
  Future<void> _restore(double saved) async {
    if (saved <= 0.03 || saved >= 0.95) {
      _restored = true;
      return;
    }
    // Wait for the HTML to lay out.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo((max * saved).clamp(0, max));
    _restored = true;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final p = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    _progress.value = p;
    if (_restored && DateTime.now().difference(_lastSave).inSeconds >= 2) {
      _lastSave = DateTime.now();
      _app.recordProgress(e, p);
    }
  }

  @override
  void dispose() {
    if (_restored) _app.recordProgress(e, _progress.value, notify: true);
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _switchLanguage() {
    final other = _app.lang == 'ur' ? 'en' : 'ur';
    final otherBundle = _app.bundleFor(other);
    final id = e.translations[other];
    final translated = (otherBundle != null && id != null) ? otherBundle.find(e.kind, id) : null;
    if (translated == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('no_translation'))));
      return;
    }
    _app.lang = other;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReaderScreen(entry: translated)));
  }

  void _textSize() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer<AppState>(
        builder: (context, app, _) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(context.t('text_size'), style: Theme.of(context).textTheme.titleMedium),
            Row(children: [
              const Icon(Icons.text_decrease),
              Expanded(
                child: Slider(
                  value: app.textScale,
                  min: .8,
                  max: 1.6,
                  divisions: 8,
                  label: '${(app.textScale * 100).round()}%',
                  onChanged: (v) => app.textScale = v,
                ),
              ),
              const Icon(Icons.text_increase),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.bundle;
    final s = S.of(context);
    final theme = Theme.of(context);
    final urdu = s.isUrdu;
    final saved = app.isBookmarked(e);

    final series = e.kind == EntryKind.episode ? b.seriesTerm(e.seriesId) : null;
    final list = series == null ? <Entry>[] : b.seriesEpisodes(series.id);
    final index = list.indexWhere((x) => x.id == e.id);
    final prev = index > 0 ? list[index - 1] : null;
    final next = index >= 0 && index < list.length - 1 ? list[index + 1] : null;
    final total = series == null ? 0 : (series.total > list.length ? series.total : list.length);

    final meta = <String>[
      if (e.kind == EntryKind.episode && e.number > 0 && total > 0)
        s.t('episode_x_of_y', {'x': e.number, 'y': total}),
      if (e.kind == EntryKind.post) s.date(e.date),
      if (e.readingMinutes > 0) s.minutes(e.readingMinutes),
    ].join(' · ');

    final related = e.kind == EntryKind.post
        ? b.posts.where((p) => p.id != e.id).take(6).toList()
        : b.episodes.where((x) => x.empireId == e.empireId && x.seriesId != e.seriesId).take(6).toList();

    return Scaffold(
      body: Stack(children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 280,
              foregroundColor: Colors.white,
              backgroundColor: theme.brightness == Brightness.dark ? Brand.dSurface : Brand.lAccentStrong,
              actions: [
                IconButton(
                  tooltip: s.t('read_in_other'),
                  icon: const Icon(Icons.translate),
                  onPressed: _switchLanguage,
                ),
                IconButton(
                  tooltip: s.t('text_size'),
                  icon: const Icon(Icons.format_size),
                  onPressed: _textSize,
                ),
                IconButton(
                  tooltip: s.t('save'),
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () {
                    final now = app.toggleBookmark(e);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(s.t(now ? 'saved' : 'removed'))));
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'share') {
                      SharePlus.instance.share(ShareParams(text: '${e.title}\n${e.link}'));
                    } else if (v == 'web') {
                      launchUrl(Uri.parse(e.link), mode: LaunchMode.externalApplication);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'share', child: Text(s.t('share'))),
                    if (e.link.isNotEmpty) PopupMenuItem(value: 'web', child: Text(s.t('open_website'))),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  Hero(tag: 'cover-${e.key}', child: Cover.entry(e)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (series != null)
                        InkWell(
                          onTap: () => push(context, SeriesScreen(series: series)),
                          child: Eyebrow([
                            series.name,
                            if (b.empire(e.empireId) != null) b.empire(e.empireId)!.name,
                          ].join(' · ')),
                        )
                      else
                        Eyebrow(entryEyebrow(context, e, b)),
                      const SizedBox(height: 6),
                      Text(e.title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(meta, style: theme.textTheme.bodySmall),
                      if (e.excerpt.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          e.excerpt,
                          style: readingStyle(context, urdu: urdu, scale: app.textScale).copyWith(
                            fontStyle: urdu ? FontStyle.normal : FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Divider(height: 36),
                      HtmlWidget(
                        e.content,
                        textStyle: readingStyle(context, urdu: urdu, scale: app.textScale),
                        customStylesBuilder: (el) {
                          switch (el.localName) {
                            case 'p':
                              return {'margin': '0 0 1em 0'};
                            case 'blockquote':
                              return {
                                'margin': '0 0 1em 0',
                                'padding': '0 1em',
                                'font-style': urdu ? 'normal' : 'italic',
                              };
                            case 'img':
                              return {'max-width': '100%', 'height': 'auto'};
                          }
                          return null;
                        },
                        onTapUrl: (url) => launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication),
                      ),
                      if (e.nextRelease.isNotEmpty && next == null) ...[
                        const SizedBox(height: 8),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.event),
                            title: Text(s.t('next_release', {
                              'd': s.date(DateTime.tryParse(e.nextRelease)).isEmpty
                                  ? e.nextRelease
                                  : s.date(DateTime.tryParse(e.nextRelease)),
                            })),
                          ),
                        ),
                      ],
                      if (series != null) ...[
                        const Divider(height: 36),
                        Row(children: [
                          if (prev != null)
                            Expanded(
                              child: _NavButton(
                                label: s.t('prev_episode'),
                                title: prev.title,
                                icon: Icons.arrow_back,
                                onTap: () => openEntry(context, prev, replace: true),
                              ),
                            ),
                          if (prev != null && next != null) const SizedBox(width: 12),
                          if (next != null)
                            Expanded(
                              child: _NavButton(
                                label: s.t('next_episode'),
                                title: next.title,
                                icon: Icons.arrow_forward,
                                end: true,
                                primary: true,
                                onTap: () => openEntry(context, next, replace: true),
                              ),
                            ),
                        ]),
                        if (next == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              series.completed ? s.t('end_of_series') : s.t('more_coming'),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
            if (related.isNotEmpty) ...[
              SliverToBoxAdapter(
                  child: SectionHeader(e.kind == EntryKind.post ? s.t('you_may_like') : s.t('related_episodes'))),
              SliverToBoxAdapter(
                child: CardRow(height: 236, children: [for (final r in related) EntryCard(r, width: 210)]),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
        // Reading progress bar.
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.paddingOf(context).top,
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 3,
              backgroundColor: Colors.transparent,
              color: Brand.gold,
            ),
          ),
        ),
      ]),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.title,
    required this.icon,
    required this.onTap,
    this.end = false,
    this.primary = false,
  });

  final String label, title;
  final IconData icon;
  final VoidCallback onTap;
  final bool end, primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary ? c.primary.withValues(alpha: .12) : null,
          border: Border.all(color: primary ? c.primary : c.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (!end) Icon(icon, size: 16, color: c.primary),
              if (!end) const SizedBox(width: 4),
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: c.primary)),
              if (end) const SizedBox(width: 4),
              if (end) Icon(icon, size: 16, color: c.primary),
            ]),
            const SizedBox(height: 2),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: end ? TextAlign.end : TextAlign.start,
                style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
