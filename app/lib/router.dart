import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models.dart';
import 'screens/place_screen.dart';
import 'screens/reader_screen.dart';
import 'services/ads.dart';
import 'state/app_state.dart';

/// Opens any story, post, museum, city or castle.
void openEntry(BuildContext context, Entry entry, {bool replace = false}) {
  final app = context.read<AppState>();
  final page = switch (entry.kind) {
    EntryKind.episode || EntryKind.post => ReaderScreen(entry: entry),
    _ => PlaceScreen(entry: entry),
  };
  final route = MaterialPageRoute(builder: (_) => page);
  final nav = Navigator.of(context);
  if (replace) {
    nav.pushReplacement(route);
  } else {
    nav.push(route);
  }
  if (app.shouldShowInterstitial()) {
    AdService.instance.showInterstitial();
  }
}

/// Opens something by its saved key ("episode:123"), e.g. from a notification.
void openEntryKey(BuildContext context, String key, {String? lang}) {
  final app = context.read<AppState>();
  if (lang != null && lang != app.lang && app.bundleFor(lang) != null) {
    app.lang = lang;
  }
  final entry = app.bundle.findByKey(key);
  if (entry != null) openEntry(context, entry);
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
