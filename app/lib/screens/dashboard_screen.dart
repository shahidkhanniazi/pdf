import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover.dart';
import 'collection_screen.dart';
import 'splash_screen.dart';
import 'stories_screen.dart';

Future<void> refreshLibrary(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final s = app.s;
  final result = await app.refresh();
  messenger.showSnackBar(SnackBar(
    content: Text(switch (result) {
      'updated' => s.t('updated'),
      'offline' => s.t('offline_msg'),
      _ => s.t('up_to_date'),
    }),
  ));
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onTab});
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.bundle;
    final s = S.of(context);
    final latest = b.episodes.take(12).toList();
    final series = b.seriesByLatest.take(4).toList();
    final continueReading = app.continueReading;
    final museums = [...b.museums]..sort((a, c) => (c.featured ? 1 : 0) - (a.featured ? 1 : 0));
    final cities = [...b.cities]..sort((a, c) => (c.featured ? 1 : 0) - (a.featured ? 1 : 0));
    final castles = [...b.castles]..sort((a, c) => (c.featured ? 1 : 0) - (a.featured ? 1 : 0));

    return RefreshIndicator(
      onRefresh: () => refreshLibrary(context),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            titleSpacing: 16,
            title: Logo(
              size: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            actions: appBarActions(context),
          ),
          if (app.syncing)
            const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (latest.isNotEmpty) SliverToBoxAdapter(child: _Hero(latest.first)),
          if (continueReading.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(s.t('continue_reading'))),
            SliverToBoxAdapter(
              child: CardRow(
                height: 236,
                children: [for (final h in continueReading) EntryCard(h.$1, width: 210)],
              ),
            ),
          ],
          if (latest.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(s.t('latest_episodes'), onSeeAll: () => onTab(1)),
            ),
            SliverToBoxAdapter(
              child: CardRow(
                height: 236,
                children: [for (final e in latest) EntryCard(e, width: 210)],
              ),
            ),
          ],
          SliverToBoxAdapter(child: SectionHeader(s.t('explore'))),
          SliverToBoxAdapter(child: _ExploreTiles()),
          for (final ser in series) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                ser.name,
                eyebrow: b.empire(ser.empireId)?.name,
                onSeeAll: () => push(context, SeriesScreen(series: ser)),
              ),
            ),
            SliverToBoxAdapter(
              child: CardRow(
                height: 236,
                children: [for (final e in b.seriesEpisodes(ser.id)) EntryCard(e, width: 210)],
              ),
            ),
          ],
          if (b.empires.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(s.t('empires'), onSeeAll: () => onTab(1))),
            SliverToBoxAdapter(
              child: CardRow(
                height: 220,
                children: [
                  for (final em in b.empires)
                    TermCard(
                      term: em,
                      subtitle: em.period,
                      width: 165,
                      onTap: () => push(context, EmpireScreen(empire: em)),
                    ),
                ],
              ),
            ),
          ],
          if (museums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(s.t('museums'),
                  onSeeAll: () => push(context, const CollectionScreen(kind: EntryKind.museum))),
            ),
            SliverToBoxAdapter(
              child: CardRow(height: 236, children: [for (final e in museums.take(10)) EntryCard(e, width: 210)]),
            ),
          ],
          if (cities.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(s.t('cities'),
                  onSeeAll: () => push(context, const CollectionScreen(kind: EntryKind.city))),
            ),
            SliverToBoxAdapter(
              child: CardRow(height: 236, children: [for (final e in cities.take(10)) EntryCard(e, width: 210)]),
            ),
          ],
          if (castles.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(s.t('castles'),
                  onSeeAll: () => push(context, const CollectionScreen(kind: EntryKind.castle))),
            ),
            SliverToBoxAdapter(
              child: CardRow(height: 236, children: [for (final e in castles.take(10)) EntryCard(e, width: 210)]),
            ),
          ],
          if (b.posts.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(s.t('from_the_blog'), onSeeAll: () => onTab(3))),
            SliverToBoxAdapter(
              child: CardRow(height: 236, children: [for (final e in b.posts.take(10)) EntryCard(e, width: 230)]),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(this.episode);
  final Entry episode;

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    final urdu = s.isUrdu;
    final series = b.seriesTerm(episode.seriesId);
    final empire = b.empire(episode.empireId);
    final count = series == null ? 0 : b.seriesEpisodes(series.id).length;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => openEntry(context, episode),
      child: SizedBox(
        height: 440,
        child: Stack(fit: StackFit.expand, children: [
          Cover.entry(episode),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC0B0806), Color(0xFF0B0806)],
                stops: [.25, .7, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  [s.t('new_episode'), if (empire != null) empire.name].join(' · '),
                  color: Brand.gold,
                ),
                const SizedBox(height: 4),
                Text(series?.name ?? episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                if (series != null)
                  Text(
                    '${s.t('episode_n', {'n': episode.number})}: ${episode.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: urdu ? fontUrdu : fontHeading,
                      fontStyle: urdu ? FontStyle.normal : FontStyle.italic,
                      fontSize: 17,
                      height: urdu ? 1.9 : 1.3,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (count > 0) s.t('episodes_n', {'n': count}),
                    if (episode.readingMinutes > 0) s.minutes(episode.readingMinutes),
                    if (empire != null && empire.period.isNotEmpty) empire.period,
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(episode.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .9),
                      fontFamily: urdu ? fontUrdu : fontBody,
                      height: urdu ? 2 : 1.45,
                    )),
                const SizedBox(height: 14),
                Row(children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.gold,
                      foregroundColor: const Color(0xFF1A1208),
                    ),
                    onPressed: () => openEntry(context, episode),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(s.t('read_now')),
                  ),
                  const SizedBox(width: 10),
                  if (series != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: .12),
                        side: BorderSide.none,
                      ),
                      onPressed: () => push(context, SeriesScreen(series: series)),
                      icon: const Icon(Icons.info_outline),
                      label: Text(s.t('full_series')),
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ExploreTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    Widget tile(EntryKind kind, String label, int count, IconData icon, String shape, List<String> palette) {
      return Expanded(
        child: InkWell(
          onTap: () => push(context, CollectionScreen(kind: kind)),
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: .82,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(fit: StackFit.expand, children: [
                Cover(image: '', palette: palette, shape: shape),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black12, Colors.black87],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: Brand.gold, size: 22),
                      const Spacer(),
                      Text(label,
                          maxLines: 2,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white, fontSize: 14)),
                      Text(s.t('items_n', {'n': count}),
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        tile(EntryKind.museum, s.t('museums'), b.museums.length, Icons.account_balance, 'columns',
            const ['#1c2433', '#4f6a8f', '#e7c58a']),
        const SizedBox(width: 10),
        tile(EntryKind.city, s.t('cities'), b.cities.length, Icons.location_city, 'ruins',
            const ['#1d140c', '#8a5a2b', '#e0a95a']),
        const SizedBox(width: 10),
        tile(EntryKind.castle, s.t('castles'), b.castles.length, Icons.fort, 'fort',
            const ['#2b1630', '#8a4f7d', '#f0c48a']),
      ]),
    );
  }
}
