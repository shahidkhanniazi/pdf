import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:something_historic/data/models.dart';

void main() {
  for (final lang in ['en', 'ur']) {
    test('built-in $lang library parses and links up', () {
      final b = Bundle.decode(File('assets/seed/$lang.json').readAsStringSync());
      expect(b.lang, lang);
      expect(b.episodes, isNotEmpty);
      expect(b.posts, isNotEmpty);
      expect(b.museums, isNotEmpty);
      expect(b.cities, isNotEmpty);
      expect(b.castles, isNotEmpty);

      // Every episode belongs to a known series and empire.
      for (final e in b.episodes) {
        expect(b.seriesTerm(e.seriesId), isNotNull, reason: e.title);
        expect(b.empire(e.empireId), isNotNull, reason: e.title);
      }
      // Series episodes are numbered 1..n in order.
      for (final s in b.series) {
        final list = b.seriesEpisodes(s.id);
        expect(list.map((e) => e.number), List.generate(list.length, (i) => i + 1));
      }
      // Places have facts and coordinates.
      expect(b.cities.first.timeline, isNotEmpty);
      expect(b.museums.where((m) => m.hasCoords), isNotEmpty);
      expect(b.findByKey(b.castles.first.key)?.id, b.castles.first.id);
    });
  }

  test('translations point at the same item in the other language', () {
    final en = Bundle.decode(File('assets/seed/en.json').readAsStringSync());
    final ur = Bundle.decode(File('assets/seed/ur.json').readAsStringSync());
    final e = en.episodes.first;
    final u = ur.find(EntryKind.episode, e.translations['ur']!);
    expect(u, isNotNull);
    expect(u!.number, e.number);
  });

  test('a site bundle with missing fields still parses', () {
    final b = Bundle({
      'version': '1',
      'lang': 'en',
      'episodes': [
        {'id': 5, 'title': 'T', 'translations': []}
      ],
      'museums': [
        {'id': 7, 'title': 'M', 'type': [3], 'meta': {'lat': '31.5', 'lng': '74.3', 'highlights': ['a']}}
      ],
    });
    expect(b.episodes.single.translations, isEmpty);
    expect(b.museums.single.typeIds, [3]);
    expect(b.museums.single.hasCoords, isTrue);
    expect(b.cities, isEmpty);
  });
}
