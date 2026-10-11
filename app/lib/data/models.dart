import 'dart:convert';

/// The five kinds of readable things in the app.
enum EntryKind { episode, post, museum, city, castle }

EntryKind? entryKindFromName(String name) {
  for (final k in EntryKind.values) {
    if (k.name == name) return k;
  }
  return null;
}

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
List<int> _ids(dynamic v) {
  if (v is List) return v.map(_i).where((e) => e != 0).toList();
  final one = _i(v);
  return one == 0 ? const [] : [one];
}

List<String> _strings(dynamic v) =>
    v is List ? v.map(_s).where((e) => e.isNotEmpty).toList() : const [];

Map<String, int> _translations(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), _i(val)));
  }
  return const {};
}

/// Taxonomy term: empire, series, museum type/country, city/castle region.
class Term {
  Term(this.json)
      : id = _i(json['id']),
        slug = _s(json['slug']),
        name = _s(json['name']),
        description = _s(json['description']),
        intro = _s(json['intro']),
        image = _s(json['image']),
        link = _s(json['link']),
        count = _i(json['count']),
        palette = _strings(json['palette']),
        shape = _s(json['shape']),
        translations = _translations(json['translations']);

  final Map<String, dynamic> json;
  final int id;
  final String slug;
  final String name;
  final String description;
  final String intro;
  final String image;
  final String link;
  final int count;
  final List<String> palette;
  final String shape;
  final Map<String, int> translations;

  // Empire
  String get period => _s(json['period']);
  // Series
  int get empireId => _i(json['empire']);
  int get total => _i(json['total']);
  bool get completed => _s(json['status']) == 'completed';

  String get about => intro.isNotEmpty ? intro : description;
}

/// A story episode, blog post, museum, ancient city or castle.
class Entry {
  Entry(this.kind, this.json)
      : id = _i(json['id']),
        slug = _s(json['slug']),
        title = _s(json['title']),
        excerpt = _s(json['excerpt']),
        content = _s(json['content']),
        date = DateTime.tryParse(_s(json['date'])),
        image = _s(json['image']),
        link = _s(json['link']),
        palette = _strings(json['palette']),
        shape = _s(json['shape']),
        translations = _translations(json['translations']),
        meta = json['meta'] is Map
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : const {};

  final EntryKind kind;
  final Map<String, dynamic> json;
  final int id;
  final String slug;
  final String title;
  final String excerpt;
  final String content;
  final DateTime? date;
  final String image;
  final String link;
  final List<String> palette;
  final String shape;
  final Map<String, int> translations;
  final Map<String, dynamic> meta;

  /// Unique across kinds, used for bookmarks and history.
  String get key => '${kind.name}:$id';

  // Episodes
  int get seriesId => _i(json['series']);
  int get empireId => _i(json['empire']);
  int get number => _i(json['number']);
  int get readingMinutes => _i(json['reading_minutes']);
  String get nextRelease => _s(json['next_release']);

  // Posts
  List<String> get categories => _strings(json['categories']);

  // Museums
  List<int> get typeIds => _ids(json['type']);
  List<int> get countryIds => _ids(json['country']);

  // Cities / castles
  List<int> get regionIds => _ids(json['region']);

  String m(String key) => _s(meta[key]);
  List<String> mList(String key) => _strings(meta[key]);
  bool get featured => meta['featured'] == true || meta['featured'] == 1;
  String get tagline => m('tagline').isNotEmpty ? m('tagline') : excerpt;

  List<List<String>> get timeline {
    final t = meta['timeline'];
    if (t is! List) return const [];
    return t
        .whereType<List>()
        .map((row) => row.map(_s).toList())
        .where((row) => row.isNotEmpty)
        .toList();
  }

  double? get lat => double.tryParse(m('lat'));
  double? get lng => double.tryParse(m('lng'));
  bool get hasCoords => lat != null && lng != null;

  int get year => int.tryParse(m('year')) ?? 0;

  String? _plain;

  /// Content without HTML, for search.
  String get plainText => _plain ??= content
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'&[a-z#0-9]+;'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Everything the app shows, for one language.
class Bundle {
  Bundle(this.json)
      : version = _s(json['version']),
        lang = _s(json['lang']),
        empires = _terms(json['empires']),
        series = _terms(json['series']),
        museumTypes = _terms(json['museum_types']),
        museumCountries = _terms(json['museum_countries']),
        cityRegions = _terms(json['city_regions']),
        castleRegions = _terms(json['castle_regions']),
        episodes = _entries(EntryKind.episode, json['episodes']),
        posts = _entries(EntryKind.post, json['posts']),
        museums = _entries(EntryKind.museum, json['museums']),
        cities = _entries(EntryKind.city, json['cities']),
        castles = _entries(EntryKind.castle, json['castles']) {
    for (final list in [episodes, posts]) {
      list.sort((a, b) =>
          (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    }
  }

  factory Bundle.decode(String source) =>
      Bundle(jsonDecode(source) as Map<String, dynamic>);

  final Map<String, dynamic> json;
  final String version;
  final String lang;
  final List<Term> empires;
  final List<Term> series;
  final List<Term> museumTypes;
  final List<Term> museumCountries;
  final List<Term> cityRegions;
  final List<Term> castleRegions;
  final List<Entry> episodes;
  final List<Entry> posts;
  final List<Entry> museums;
  final List<Entry> cities;
  final List<Entry> castles;

  static List<Term> _terms(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Term(Map<String, dynamic>.from(e))).toList()
      : <Term>[];

  static List<Entry> _entries(EntryKind kind, dynamic v) => v is List
      ? v
          .whereType<Map>()
          .map((e) => Entry(kind, Map<String, dynamic>.from(e)))
          .toList()
      : <Entry>[];

  List<Entry> entriesOf(EntryKind kind) => switch (kind) {
        EntryKind.episode => episodes,
        EntryKind.post => posts,
        EntryKind.museum => museums,
        EntryKind.city => cities,
        EntryKind.castle => castles,
      };

  Iterable<Entry> get all sync* {
    for (final k in EntryKind.values) {
      yield* entriesOf(k);
    }
  }

  Entry? find(EntryKind kind, int id) {
    for (final e in entriesOf(kind)) {
      if (e.id == id) return e;
    }
    return null;
  }

  Entry? findByKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final kind = entryKindFromName(parts[0]);
    final id = int.tryParse(parts[1]);
    if (kind == null || id == null) return null;
    return find(kind, id);
  }

  static Term? _term(List<Term> list, int id) {
    for (final t in list) {
      if (t.id == id) return t;
    }
    return null;
  }

  Term? empire(int id) => _term(empires, id);
  Term? seriesTerm(int id) => _term(series, id);
  Term? museumType(int id) => _term(museumTypes, id);
  Term? museumCountry(int id) => _term(museumCountries, id);
  Term? cityRegion(int id) => _term(cityRegions, id);
  Term? castleRegion(int id) => _term(castleRegions, id);

  /// Episodes of a series, in reading order.
  List<Entry> seriesEpisodes(int seriesId) {
    final list = episodes.where((e) => e.seriesId == seriesId).toList()
      ..sort((a, b) => a.number != b.number
          ? a.number.compareTo(b.number)
          : (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
    return list;
  }

  List<Term> empireSeries(int empireId) =>
      series.where((s) => s.empireId == empireId).toList();

  /// Series ordered by their newest episode, newest first.
  List<Term> get seriesByLatest {
    final latest = <int, DateTime>{};
    for (final e in episodes) {
      final d = e.date ?? DateTime(0);
      if (!latest.containsKey(e.seriesId) || latest[e.seriesId]!.isBefore(d)) {
        latest[e.seriesId] = d;
      }
    }
    final list = series.where((s) => latest.containsKey(s.id)).toList()
      ..sort((a, b) => latest[b.id]!.compareTo(latest[a.id]!));
    return list;
  }

  int get totalCount =>
      episodes.length + posts.length + museums.length + cities.length + castles.length;
}
