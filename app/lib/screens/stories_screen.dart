import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover.dart';

/// Stories tab: empires, series and every episode.
class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t('stories')),
          actions: appBarActions(context),
          bottom: TabBar(
            tabs: [
              Tab(text: s.t('empires')),
              Tab(text: s.t('all_series')),
              Tab(text: s.t('episodes')),
            ],
          ),
        ),
        body: TabBarView(children: [
          GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 3 / 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: b.empires.length,
            itemBuilder: (context, i) {
              final em = b.empires[i];
              return TermCard(
                term: em,
                subtitle: [em.period, s.t('episodes_n', {'n': b.episodes.where((e) => e.empireId == em.id).length})]
                    .where((x) => x.isNotEmpty)
                    .join(' · '),
                onTap: () => push(context, EmpireScreen(empire: em)),
              );
            },
          ),
          ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [for (final ser in b.seriesByLatest) SeriesTile(series: ser)],
          ),
          b.episodes.isEmpty
              ? EmptyView(s.t('empty_list'))
              : ListView.builder(
                  itemCount: b.episodes.length,
                  itemBuilder: (_, i) => EntryTile(b.episodes[i]),
                ),
        ]),
      ),
    );
  }
}

class SeriesTile extends StatelessWidget {
  const SeriesTile({super.key, required this.series});
  final Term series;

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    final count = b.seriesEpisodes(series.id).length;
    final empire = b.empire(series.empireId);
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => push(context, SeriesScreen(series: series)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 112,
              height: 76,
              child: Cover(
                image: series.image.isNotEmpty ? series.image : (empire?.image ?? ''),
                palette: series.palette.isNotEmpty ? series.palette : (empire?.palette ?? const []),
                shape: series.shape.isNotEmpty ? series.shape : (empire?.shape ?? 'dome'),
                seed: series.id,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (empire != null) Eyebrow(empire.name),
              Text(series.name, style: theme.textTheme.titleMedium),
              Text(
                [
                  s.t('episodes_n', {'n': count}),
                  s.t(series.completed ? 'completed' : 'ongoing'),
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Big header with cover art used by empire and series pages.
class TermHeader extends StatelessWidget {
  const TermHeader({
    super.key,
    required this.cover,
    required this.title,
    this.eyebrow,
    this.meta,
    this.about,
  });

  final Widget cover;
  final String title;
  final String? eyebrow;
  final String? meta;
  final String? about;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urdu = S.of(context).isUrdu;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 300,
        child: Stack(fit: StackFit.expand, children: [
          cover,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black26, Colors.transparent, Color(0xEE0B0806)],
                stops: [0, .35, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) Eyebrow(eyebrow!, color: Brand.gold),
                Text(title,
                    style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                if (meta != null && meta!.isNotEmpty)
                  Text(meta!, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ]),
      ),
      if (about != null && about!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(about!,
              style: TextStyle(
                fontFamily: urdu ? fontUrdu : fontBody,
                fontSize: 16,
                height: urdu ? 2.1 : 1.6,
                color: theme.colorScheme.onSurface,
              )),
        ),
    ]);
  }
}

class EmpireScreen extends StatelessWidget {
  const EmpireScreen({super.key, required this.empire});
  final Term empire;

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    final series = b.empireSeries(empire.id);
    final episodes = b.episodes.where((e) => e.empireId == empire.id).toList();
    final museums = b.museums
        .where((m) => (m.meta['empires'] is List) && (m.meta['empires'] as List).contains(empire.id))
        .toList();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: appBarActions(context),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          TermHeader(
            cover: Cover.term(empire),
            title: empire.name,
            eyebrow: s.t('empires'),
            meta: [empire.period, s.t('episodes_n', {'n': episodes.length})]
                .where((x) => x.isNotEmpty)
                .join(' · '),
            about: empire.about,
          ),
          if (series.isNotEmpty) SectionHeader(s.t('series')),
          for (final ser in series) SeriesTile(series: ser),
          if (museums.isNotEmpty) ...[
            SectionHeader(s.t('museums')),
            CardRow(height: 236, children: [for (final m in museums) EntryCard(m, width: 210)]),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key, required this.series});
  final Term series;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.bundle;
    final s = S.of(context);
    final episodes = b.seriesEpisodes(series.id);
    final empire = b.empire(series.empireId);
    final total = series.total > episodes.length ? series.total : episodes.length;
    final next = episodes.where((e) => app.progressOf(e) < .95).firstOrNull ??
        episodes.firstOrNull;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: appBarActions(context),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          TermHeader(
            cover: Cover(
              image: series.image.isNotEmpty ? series.image : (empire?.image ?? ''),
              palette: series.palette.isNotEmpty ? series.palette : (empire?.palette ?? const []),
              shape: series.shape.isNotEmpty ? series.shape : (empire?.shape ?? 'dome'),
              seed: series.id,
            ),
            title: series.name,
            eyebrow: empire?.name,
            meta: [
              s.t('episodes_n', {'n': episodes.length}),
              s.t(series.completed ? 'completed' : 'ongoing'),
            ].join(' · '),
            about: series.about,
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton.icon(
                onPressed: () => openEntry(context, next),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(app.progressOf(episodes.first) > 0
                    ? s.t('continue_reading')
                    : s.t('read_now')),
              ),
            ),
          SectionHeader(s.t('episodes_n', {'n': episodes.length})),
          for (final e in episodes)
            EntryTile(
              e,
              trailing: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
                child: app.progressOf(e) >= .95
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20)
                    : Text('${e.number}/$total', style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          if (!series.completed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s.t('more_coming'), style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
