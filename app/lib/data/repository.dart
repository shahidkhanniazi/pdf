import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'models.dart';

/// Where the library came from.
enum LibrarySource { site, builtIn }

class LoadedLibrary {
  LoadedLibrary(this.bundles, this.source);
  final Map<String, Bundle> bundles;
  final LibrarySource source;
}

class SyncResult {
  SyncResult({required this.updated, this.newEntries = const {}, this.error});

  /// True when fresh content was downloaded and saved.
  final bool updated;

  /// Per language: entries that were not in the old library.
  final Map<String, List<Entry>> newEntries;
  final String? error;
}

/// Loads the library from the phone, the built-in copy, or the website.
///
/// The website is downloaded once (both languages) and saved as files on the
/// phone. After that everything is read from those files, so the app works
/// without internet. A quiet check for new content runs now and then.
class Repository {
  Repository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Directory? _dir;

  Future<Directory> _folder() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/library');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _dir = dir;
  }

  Future<File> _file(String lang) async =>
      File('${(await _folder()).path}/bundle_$lang.json');

  /// Saved copy from the site if there is one, otherwise the built-in copy.
  Future<LoadedLibrary> loadLocal() async {
    final bundles = <String, Bundle>{};
    var fromSite = true;
    for (final lang in AppConfig.languages) {
      Bundle? b;
      try {
        final f = await _file(lang);
        if (f.existsSync()) b = Bundle.decode(await f.readAsString());
      } catch (_) {
        b = null;
      }
      if (b == null) {
        fromSite = false;
        b = Bundle.decode(await rootBundle.loadString('assets/seed/$lang.json'));
      }
      bundles[lang] = b;
    }
    return LoadedLibrary(
        bundles, fromSite ? LibrarySource.site : LibrarySource.builtIn);
  }

  /// The site's current content version, or null when offline or the site
  /// does not have the app plugin.
  Future<String?> remoteVersion() async {
    try {
      final res = await _client
          .get(Uri.parse(AppConfig.versionUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return data is Map ? data['version']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads both languages and saves them. Old files are only replaced
  /// when every language downloaded correctly.
  Future<SyncResult> sync(Map<String, Bundle> current,
      {bool force = false, void Function(double)? onProgress}) async {
    final version = await remoteVersion();
    if (version == null) {
      return SyncResult(updated: false, error: 'offline');
    }
    final same = current.values.every((b) => b.version == version);
    if (same && !force) return SyncResult(updated: false);

    final downloaded = <String, String>{};
    var step = 0;
    for (final lang in AppConfig.languages) {
      try {
        final res = await _client
            .get(Uri.parse(AppConfig.bundleUrl(lang)))
            .timeout(const Duration(seconds: 60));
        if (res.statusCode != 200) {
          return SyncResult(updated: false, error: 'http ${res.statusCode}');
        }
        final body = utf8.decode(res.bodyBytes);
        Bundle.decode(body); // Make sure it parses before saving.
        downloaded[lang] = body;
      } catch (e) {
        return SyncResult(updated: false, error: e.toString());
      }
      step++;
      onProgress?.call(step / AppConfig.languages.length);
    }

    final newEntries = <String, List<Entry>>{};
    for (final entry in downloaded.entries) {
      final f = await _file(entry.key);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(entry.value, flush: true);
      await tmp.rename(f.path);

      final fresh = Bundle.decode(entry.value);
      final old = current[entry.key];
      if (old != null) {
        final known = old.all.map((e) => e.key).toSet();
        newEntries[entry.key] =
            fresh.all.where((e) => !known.contains(e.key)).toList();
      }
    }
    return SyncResult(updated: true, newEntries: newEntries);
  }

  Future<void> clear() async {
    final dir = await _folder();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _dir = null;
  }
}
