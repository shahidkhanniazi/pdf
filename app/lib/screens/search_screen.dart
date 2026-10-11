import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Searches the whole offline library: titles first, then summaries and text.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  EntryKind? _kind;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Lower-case and strip Arabic-script diacritics so Urdu matches loosely.
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ہ', 'ه');

  List<Entry> _search(Bundle b) {
    final words = _norm(_query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final scored = <(Entry, int)>[];
    final source = _kind == null ? b.all : b.entriesOf(_kind!);
    for (final e in source) {
      final title = _norm(e.title);
      final summary = _norm('${e.excerpt} ${e.tagline} ${e.m('city')} ${e.m('location')} ${entryEyebrowPlain(b, e)}');
      var score = 0;
      var all = true;
      for (final w in words) {
        if (title.contains(w)) {
          score += title.startsWith(w) ? 12 : 8;
        } else if (summary.contains(w)) {
          score += 4;
        } else if (_norm(e.plainText).contains(w)) {
          score += 1;
        } else {
          all = false;
          break;
        }
      }
      if (all) scored.add((e, score));
    }
    scored.sort((a, c) => c.$2.compareTo(a.$2));
    return scored.map((x) => x.$1).take(100).toList();
  }

  static String entryEyebrowPlain(Bundle b, Entry e) => switch (e.kind) {
        EntryKind.episode => '${b.seriesTerm(e.seriesId)?.name ?? ''} ${b.empire(e.empireId)?.name ?? ''}',
        EntryKind.post => e.categories.join(' '),
        EntryKind.museum => e.countryIds.map((id) => b.museumCountry(id)?.name ?? '').join(' '),
        EntryKind.city => e.regionIds.map((id) => b.cityRegion(id)?.name ?? '').join(' '),
        EntryKind.castle => e.regionIds.map((id) => b.castleRegion(id)?.name ?? '').join(' '),
      };

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    final results = _search(b);

    // Matching empires and series to jump into directly.
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.t('search_hint'),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                ChoiceChip(
                  label: Text(s.t('all')),
                  selected: _kind == null,
                  onSelected: (_) => setState(() => _kind = null),
                ),
                for (final k in EntryKind.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(s.t('kind_${k.name}')),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = _kind == k ? null : k),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: _query.trim().isEmpty
          ? EmptyView(s.t('type_to_search'), icon: Icons.search)
          : results.isEmpty
              ? EmptyView(s.t('no_results'), icon: Icons.search_off)
              : ListView.builder(
                  itemCount: results.length + 1,
                  itemBuilder: (context, i) => i == 0
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(s.t('results_n', {'n': results.length}),
                              style: Theme.of(context).textTheme.bodySmall),
                        )
                      : EntryTile(results[i - 1]),
                ),
    );
  }
}
