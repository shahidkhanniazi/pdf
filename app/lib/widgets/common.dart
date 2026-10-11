import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../router.dart';
import '../screens/notifications_screen.dart';
import '../screens/search_screen.dart';
import '../state/app_state.dart';
import 'cover.dart';

/// Small upper-case label above titles ("NEW EPISODE · OTTOMAN EMPIRE").
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final urdu = S.of(context).isUrdu;
    return Text(
      urdu ? text : text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color ?? Theme.of(context).colorScheme.primary,
            fontSize: urdu ? 12 : 11,
          ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.eyebrow, this.onSeeAll});
  final String title;
  final String? eyebrow;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) Eyebrow(eyebrow!),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(context.t('see_all')),
                const Icon(Icons.chevron_right, size: 18),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling row of cards.
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.children, this.height = 250});
  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

/// Subtitle line for an entry: "Episode 2 · 4 min read" etc.
String entryMeta(BuildContext context, Entry e, Bundle b) {
  final s = S.of(context);
  switch (e.kind) {
    case EntryKind.episode:
      return [
        if (e.number > 0) s.t('episode_n', {'n': e.number}),
        if (e.readingMinutes > 0) s.minutes(e.readingMinutes),
      ].join(' · ');
    case EntryKind.post:
      return [
        s.date(e.date),
        if (e.readingMinutes > 0) s.minutes(e.readingMinutes),
      ].join(' · ');
    case EntryKind.museum:
      final country = e.countryIds.isEmpty ? null : b.museumCountry(e.countryIds.first);
      return [e.m('city'), if (country != null) country.name]
          .where((x) => x.isNotEmpty)
          .join(', ');
    case EntryKind.city:
      return [e.m('founded'), e.m('location')].where((x) => x.isNotEmpty).join(' · ');
    case EntryKind.castle:
      return [e.m('built'), e.m('location')].where((x) => x.isNotEmpty).join(' · ');
  }
}

/// Eyebrow for an entry: series name, category, type or region.
String entryEyebrow(BuildContext context, Entry e, Bundle b) {
  final s = S.of(context);
  switch (e.kind) {
    case EntryKind.episode:
      return b.seriesTerm(e.seriesId)?.name ?? b.empire(e.empireId)?.name ?? s.t('stories');
    case EntryKind.post:
      return e.categories.isNotEmpty ? e.categories.first : s.t('blog');
    case EntryKind.museum:
      return e.typeIds.isEmpty ? s.t('museums') : (b.museumType(e.typeIds.first)?.name ?? s.t('museums'));
    case EntryKind.city:
      return e.regionIds.isEmpty ? s.t('cities') : (b.cityRegion(e.regionIds.first)?.name ?? s.t('cities'));
    case EntryKind.castle:
      return e.regionIds.isEmpty ? s.t('castles') : (b.castleRegion(e.regionIds.first)?.name ?? s.t('castles'));
  }
}

/// Poster-style card for horizontal rows.
class EntryCard extends StatelessWidget {
  const EntryCard(this.entry, {super.key, this.width = 220, this.onTap});
  final Entry entry;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.bundle;
    final theme = Theme.of(context);
    final progress = entry.kind == EntryKind.episode || entry.kind == EntryKind.post
        ? app.progressOf(entry)
        : 0.0;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap ?? () => openEntry(context, entry),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(fit: StackFit.expand, children: [
                  Hero(tag: 'cover-${entry.key}', child: Cover.entry(entry)),
                  if (entry.kind == EntryKind.episode && entry.number > 0)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${entry.number}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (progress > 0)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.black26,
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Eyebrow(entryEyebrow(context, entry, b)),
            Text(entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(height: S.of(context).isUrdu ? 1.7 : 1.25)),
            const SizedBox(height: 2),
            Text(entryMeta(context, entry, b),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Full-width list row with a thumbnail.
class EntryTile extends StatelessWidget {
  const EntryTile(this.entry, {super.key, this.trailing, this.onTap});
  final Entry entry;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap ?? () => openEntry(context, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 112, height: 76, child: Cover.entry(entry)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(entryEyebrow(context, entry, b)),
                  Text(entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium),
                  Text(entryMeta(context, entry, b),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Wide card for a term (empire, series, region).
class TermCard extends StatelessWidget {
  const TermCard({
    super.key,
    required this.term,
    required this.subtitle,
    required this.onTap,
    this.width = 180,
    this.aspect = 3 / 4,
    this.fallbackShape = 'dome',
  });

  final Term term;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final double aspect;
  final String fallbackShape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              Cover.term(term, fallbackShape: fallbackShape),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [.45, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(term.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 18)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key, this.icon = Icons.auto_stories_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
    );
  }
}

/// Search and notification-bell buttons for app bars.
List<Widget> appBarActions(BuildContext context, {bool search = true}) {
  final unread = context.watch<AppState>().unreadNotices;
  return [
    if (search)
      IconButton(
        tooltip: context.t('search'),
        icon: const Icon(Icons.search),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
      ),
    IconButton(
      tooltip: context.t('notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none),
      ),
      onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen())),
    ),
  ];
}
