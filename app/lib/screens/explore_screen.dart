import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/cover.dart';
import 'collection_screen.dart';

/// Museums, ancient cities and castles, grouped like on the website.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);

    List<Widget> section(EntryKind kind, List<Term> groups, List<int> Function(Entry) ids, String shape) {
      final all = b.entriesOf(kind);
      if (all.isEmpty) return const [];
      final featured = all.where((e) => e.featured).toList();
      return [
        _Banner(kind: kind, count: all.length, shape: shape, sample: featured.isNotEmpty ? featured.first : all.first),
        if (groups.isNotEmpty)
          CardRow(
            height: 150,
            children: [
              for (final g in groups)
                if (all.any((e) => ids(e).contains(g.id)))
                  TermCard(
                    term: g,
                    width: 200,
                    aspect: 4 / 3,
                    fallbackShape: shape,
                    subtitle: s.t('items_n', {'n': all.where((e) => ids(e).contains(g.id)).length}),
                    onTap: () => push(context, CollectionScreen(kind: kind, initialFilter: g.id)),
                  ),
            ],
          ),
        if (featured.isNotEmpty) ...[
          SectionHeader(s.t('featured'),
              eyebrow: kindTitle(s, kind),
              onSeeAll: () => push(context, CollectionScreen(kind: kind))),
          CardRow(height: 236, children: [for (final e in featured) EntryCard(e, width: 210)]),
        ],
        const SizedBox(height: 12),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('explore')), actions: appBarActions(context)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...section(EntryKind.museum, b.museumTypes, (e) => e.typeIds, 'columns'),
          ...section(EntryKind.city, b.cityRegions, (e) => e.regionIds, 'ruins'),
          ...section(EntryKind.castle, b.castleRegions, (e) => e.regionIds, 'fort'),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.kind, required this.count, required this.shape, required this.sample});
  final EntryKind kind;
  final int count;
  final String shape;
  final Entry sample;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: InkWell(
        onTap: () => push(context, CollectionScreen(kind: kind)),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 150,
            child: Stack(fit: StackFit.expand, children: [
              Cover(image: sample.image, palette: sample.palette, shape: shape, seed: sample.id),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kindTitle(s, kind),
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                    Text(s.t('items_n', {'n': count}), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(s.t('see_all'), style: const TextStyle(color: Colors.white)),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                    ]),
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
