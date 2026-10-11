import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../l10n/strings.dart';
import '../services/notifications.dart';

/// One in-app notice (shown under the bell in the app bar).
class Notice {
  Notice({
    required this.title,
    required this.body,
    required this.time,
    this.entryKey,
    this.lang,
    this.read = false,
  });

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        time: DateTime.tryParse(j['time']?.toString() ?? '') ?? DateTime.now(),
        entryKey: j['entry']?.toString(),
        lang: j['lang']?.toString(),
        read: j['read'] == true,
      );

  final String title;
  final String body;
  final DateTime time;
  final String? entryKey;
  final String? lang;
  bool read;

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'time': time.toIso8601String(),
        'entry': entryKey,
        'lang': lang,
        'read': read,
      };
}

/// Reading position for "Continue reading".
class HistoryItem {
  HistoryItem(this.key, this.progress, this.time);
  final String key;
  final double progress;
  final DateTime time;
}

/// Everything the screens need: settings, the offline library, saved items,
/// reading history and notifications.
class AppState extends ChangeNotifier {
  AppState(this._prefs, this._repo);

  final SharedPreferences _prefs;
  final Repository _repo;

  // ------------------------------------------------------------ Settings
  ThemeMode get themeMode =>
      ThemeMode.values.firstWhere((m) => m.name == _prefs.getString('theme'),
          orElse: () => ThemeMode.system);
  set themeMode(ThemeMode m) {
    _prefs.setString('theme', m.name);
    notifyListeners();
  }

  String get lang => _prefs.getString('lang') ?? 'en';
  set lang(String l) {
    _prefs.setString('lang', l);
    notifyListeners();
  }

  bool get isUrdu => lang == 'ur';
  S get s => S(lang);

  bool get onboarded => _prefs.getBool('onboarded') ?? false;
  set onboarded(bool v) {
    _prefs.setBool('onboarded', v);
    notifyListeners();
  }

  double get textScale => _prefs.getDouble('text_scale') ?? 1.0;
  set textScale(double v) {
    _prefs.setDouble('text_scale', v.clamp(0.8, 1.6));
    notifyListeners();
  }

  bool get notifyNew => _prefs.getBool('notify_new') ?? true;
  set notifyNew(bool v) {
    _prefs.setBool('notify_new', v);
    if (v) NotificationService.instance.requestPermission();
    notifyListeners();
  }

  // ------------------------------------------------------------- Library
  Map<String, Bundle> _bundles = {};
  LibrarySource _source = LibrarySource.builtIn;
  bool syncing = false;
  double syncProgress = 0;

  bool get ready => _bundles.isNotEmpty;
  Bundle get bundle => _bundles[lang] ?? _bundles.values.first;
  Bundle? bundleFor(String l) => _bundles[l];
  LibrarySource get source => _source;

  DateTime? get lastSync {
    final s = _prefs.getString('last_sync');
    return s == null ? null : DateTime.tryParse(s);
  }

  DateTime? get _lastCheck {
    final s = _prefs.getString('last_check');
    return s == null ? null : DateTime.tryParse(s);
  }

  /// Loads the saved library. On the very first run (nothing saved from the
  /// site yet) it downloads the library once, with progress, and falls back
  /// to the built-in copy when offline.
  Future<void> start() async {
    if (ready) return;
    final local = await _repo.loadLocal();
    _bundles = local.bundles;
    _source = local.source;
    notifyListeners();

    // Wait for the download only on the very first launch; after that the
    // app opens straight away and checks for updates in the background.
    if (_source == LibrarySource.builtIn && _lastCheck == null) {
      await refresh(firstRun: true);
    }
  }

  /// Quiet background check, at most every [AppConfig.updateCheckInterval].
  Future<void> maybeCheckForUpdates() async {
    final last = _lastCheck;
    if (last != null &&
        DateTime.now().difference(last) < AppConfig.updateCheckInterval) {
      return;
    }
    await refresh();
  }

  /// Checks the site and downloads new content when there is some.
  /// Returns 'updated', 'up_to_date' or 'offline'.
  Future<String> refresh({bool firstRun = false, bool force = false}) async {
    if (syncing) return 'up_to_date';
    syncing = true;
    syncProgress = 0;
    notifyListeners();
    try {
      final wasSite = _source == LibrarySource.site;
      final result = await _repo.sync(
        _bundles,
        force: force || !wasSite,
        onProgress: (p) {
          syncProgress = p;
          notifyListeners();
        },
      );
      await _prefs.setString('last_check', DateTime.now().toIso8601String());
      if (result.error != null) return 'offline';
      if (!result.updated) return 'up_to_date';

      final local = await _repo.loadLocal();
      _bundles = local.bundles;
      _source = local.source;
      await _prefs.setString('last_sync', DateTime.now().toIso8601String());

      if (wasSite) {
        _announce(result.newEntries);
      } else if (firstRun) {
        _addNotice(Notice(
          title: S(lang).t('app_name'),
          body: S(lang).t('welcome_notice'),
          time: DateTime.now(),
        ));
      }
      return 'updated';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void _announce(Map<String, List<Entry>> fresh) {
    // Announce in the reader's language only.
    final list = fresh[lang] ?? const <Entry>[];
    if (list.isEmpty) return;
    final s = S(lang);
    for (final e in list.take(10)) {
      final body = switch (e.kind) {
        EntryKind.episode => s.t('new_episode_notice', {'t': e.title}),
        EntryKind.post => s.t('new_post_notice', {'t': e.title}),
        _ => s.t('new_item_notice', {'t': e.title}),
      };
      _addNotice(Notice(
        title: s.t('new_content_title'),
        body: body,
        time: DateTime.now(),
        entryKey: e.key,
        lang: lang,
      ));
    }
    if (notifyNew) {
      final first = list.first;
      final body = list.length == 1
          ? first.title
          : '${first.title} (+${list.length - 1})';
      NotificationService.instance.show(
        title: list.first.kind == EntryKind.episode
            ? s.t('new_episode')
            : s.t('new_content_title'),
        body: body,
        payload: '$lang|${first.key}',
      );
    }
  }

  Future<void> resetLibrary() async {
    await _repo.clear();
    await _prefs.remove('last_sync');
    await _prefs.remove('last_check');
    final local = await _repo.loadLocal();
    _bundles = local.bundles;
    _source = local.source;
    notifyListeners();
  }

  // ---------------------------------------------------------- Bookmarks
  List<String> get _bookmarkKeys =>
      _prefs.getStringList('bookmarks_$lang') ?? const [];

  bool isBookmarked(Entry e) => _bookmarkKeys.contains(e.key);

  /// Returns true when the entry is now saved.
  bool toggleBookmark(Entry e) {
    final list = [..._bookmarkKeys];
    final saved = !list.remove(e.key);
    if (saved) list.insert(0, e.key);
    _prefs.setStringList('bookmarks_$lang', list);
    notifyListeners();
    return saved;
  }

  List<Entry> get bookmarks => _bookmarkKeys
      .map(bundle.findByKey)
      .whereType<Entry>()
      .toList();

  // ------------------------------------------------------------ History
  List<HistoryItem> get _history {
    final raw = _prefs.getString('history_$lang');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => HistoryItem(
                m['k'].toString(),
                (m['p'] as num?)?.toDouble() ?? 0,
                DateTime.tryParse(m['t'].toString()) ?? DateTime.now(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveHistory(List<HistoryItem> list) {
    _prefs.setString(
      'history_$lang',
      jsonEncode(list
          .take(60)
          .map((h) => {'k': h.key, 'p': h.progress, 't': h.time.toIso8601String()})
          .toList()),
    );
  }

  double progressOf(Entry e) {
    for (final h in _history) {
      if (h.key == e.key) return h.progress;
    }
    return 0;
  }

  void recordProgress(Entry e, double progress, {bool notify = false}) {
    final list = _history.where((h) => h.key != e.key).toList()
      ..insert(0, HistoryItem(e.key, progress.clamp(0, 1), DateTime.now()));
    _saveHistory(list);
    // May be called while a screen is closing, so notify after this frame.
    if (notify) Future.microtask(notifyListeners);
  }

  List<(Entry, double)> get history => _history
      .map((h) {
        final e = bundle.findByKey(h.key);
        return e == null ? null : (e, h.progress);
      })
      .whereType<(Entry, double)>()
      .toList();

  /// Started but unfinished stories, newest first.
  List<(Entry, double)> get continueReading => history
      .where((h) =>
          (h.$1.kind == EntryKind.episode || h.$1.kind == EntryKind.post) &&
          h.$2 > 0.02 &&
          h.$2 < 0.95)
      .take(10)
      .toList();

  void clearHistory() {
    _prefs.remove('history_$lang');
    notifyListeners();
  }

  // ------------------------------------------------------ Notifications
  List<Notice> get notices {
    final raw = _prefs.getString('notices');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => Notice.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  int get unreadNotices => notices.where((n) => !n.read).length;

  void _saveNotices(List<Notice> list) => _prefs.setString(
      'notices', jsonEncode(list.take(50).map((n) => n.toJson()).toList()));

  void _addNotice(Notice n) {
    _saveNotices([n, ...notices]);
    notifyListeners();
  }

  void markNoticesRead() {
    _saveNotices(notices..forEach((n) => n.read = true));
    notifyListeners();
  }

  void clearNotices() {
    _prefs.remove('notices');
    notifyListeners();
  }

  // ---------------------------------------------------------------- Ads
  int _opens = 0;
  DateTime? _lastInterstitial;

  /// Called each time a story or place is opened. Returns true when it is
  /// a good moment for a full-screen ad.
  bool shouldShowInterstitial() {
    _opens++;
    if (_opens % AppConfig.interstitialEvery != 0) return false;
    final last = _lastInterstitial;
    if (last != null &&
        DateTime.now().difference(last) < AppConfig.interstitialCooldown) {
      return false;
    }
    _lastInterstitial = DateTime.now();
    return true;
  }
}
