import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

String kindTitle(S s, EntryKind kind) => switch (kind) {
      EntryKind.episode => s.t('stories'),
      EntryKind.post => s.t('blog'),
      EntryKind.museum => s.t('museums'),
      EntryKind.city => s.t('cities'),
      EntryKind.castle => s.t('castles'),
    };

/// Museums, cities or castles, with filter chips (type, country, region).
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.kind, this.initialFilter});
  final EntryKind kind;
  final int? initialFilter;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  int? _filterA; // type or region
  int? _filterB; // country (museums)

  @override
  void initState() {
    super.initState();
    _filterA = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    final kind = widget.kind;

    List<Term> groupA;
    List<Term> groupB = const [];
    List<int> Function(Entry) idsA;
    List<int> Function(Entry) idsB = (_) => const [];
    switch (kind) {
      case EntryKind.museum:
        groupA = b.museumTypes;
        groupB = b.museumCountries;
        idsA = (e) => e.typeIds;
        idsB = (e) => e.countryIds;
      case EntryKind.city:
        groupA = b.cityRegions;
        idsA = (e) => e.regionIds;
      case EntryKind.castle:
        groupA = b.castleRegions;
        idsA = (e) => e.regionIds;
      default:
        groupA = const [];
        idsA = (_) => const [];
    }

    final all = b.entriesOf(kind);
    // Only show filters that have something in them.
    groupA = groupA.where((t) => all.any((e) => idsA(e).contains(t.id))).toList();
    groupB = groupB.where((t) => all.any((e) => idsB(e).contains(t.id))).toList();

    final items = all
        .where((e) => _filterA == null || idsA(e).contains(_filterA))
        .where((e) => _filterB == null || idsB(e).contains(_filterB))
        .toList()
      ..sort((a, c) {
        final f = (c.featured ? 1 : 0) - (a.featured ? 1 : 0);
        return f != 0 ? f : a.title.compareTo(c.title);
      });

    Term? selectedA = _filterA == null ? null : groupA.where((t) => t.id == _filterA).firstOrNull;

    Widget chips(List<Term> terms, int? selected, ValueChanged<int?> onSelect) {
      return SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            ChoiceChip(
              label: Text(s.t('all')),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
            for (final t in terms) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(t.name),
                selected: selected == t.id,
                onSelected: (_) => onSelect(selected == t.id ? null : t.id),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(kindTitle(s, kind)), actions: appBarActions(context)),
      body: CustomScrollView(slivers: [
        if (groupA.isNotEmpty)
          SliverToBoxAdapter(child: chips(groupA, _filterA, (v) => setState(() => _filterA = v))),
        if (groupB.isNotEmpty)
          SliverToBoxAdapter(child: chips(groupB, _filterB, (v) => setState(() => _filterB = v))),
        if (selectedA != null && selectedA.about.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(selectedA.about, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(s.t('items_n', {'n': items.length}),
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: EmptyView(s.t('empty_list')))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 228,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => EntryCard(items[i], width: double.infinity),
                childCount: items.length,
              ),
            ),
          ),
      ]),
    );
  }
}
