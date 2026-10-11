import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover.dart';

/// A museum, ancient city or castle.
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key, required this.entry});
  final Entry entry;

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().recordProgress(widget.entry, 0);
  }

  void _switchLanguage(AppState app) {
    final e = widget.entry;
    final other = app.lang == 'ur' ? 'en' : 'ur';
    final id = e.translations[other];
    final translated = id == null ? null : app.bundleFor(other)?.find(e.kind, id);
    if (translated == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('no_translation'))));
      return;
    }
    app.lang = other;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PlaceScreen(entry: translated)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.bundle;
    final s = S.of(context);
    final e = widget.entry;
    final theme = Theme.of(context);
    final urdu = s.isUrdu;
    final saved = app.isBookmarked(e);

    final facts = <(IconData, String, String)>[];
    void fact(IconData icon, String label, String value) {
      if (value.trim().isNotEmpty) facts.add((icon, label, value));
    }

    String statusLabel(String v) => v.isEmpty ? '' : s.t(v);

    switch (e.kind) {
      case EntryKind.museum:
        fact(Icons.place_outlined, s.t('city'), e.m('city'));
        if (e.countryIds.isNotEmpty) {
          fact(Icons.flag_outlined, s.t('country'), b.museumCountry(e.countryIds.first)?.name ?? '');
        }
        if (e.typeIds.isNotEmpty) {
          fact(Icons.category_outlined, s.t('type'), b.museumType(e.typeIds.first)?.name ?? '');
        }
        fact(Icons.history_edu, s.t('founded'), e.m('founded'));
        fact(Icons.signpost_outlined, s.t('address'), e.m('address'));
        fact(Icons.schedule, s.t('hours'), e.m('hours'));
        fact(Icons.confirmation_number_outlined, s.t('tickets'), e.m('tickets'));
      case EntryKind.city:
        fact(Icons.place_outlined, s.t('location'), e.m('location'));
        fact(Icons.history_edu, s.t('founded'), e.m('founded'));
        fact(Icons.groups_outlined, s.t('civilization'), e.m('civilization'));
        fact(Icons.info_outline, s.t('status'), statusLabel(e.m('status')));
        if (e.regionIds.isNotEmpty) {
          fact(Icons.public, s.t('region'), b.cityRegion(e.regionIds.first)?.name ?? '');
        }
      case EntryKind.castle:
        fact(Icons.place_outlined, s.t('location'), e.m('location'));
        fact(Icons.history_edu, s.t('built'), e.m('built'));
        fact(Icons.person_outline, s.t('built_by'), e.m('builder'));
        fact(Icons.fort, s.t('type'), statusLabel(e.m('type')));
        fact(Icons.info_outline, s.t('status'), statusLabel(e.m('status')));
        if (e.regionIds.isNotEmpty) {
          fact(Icons.public, s.t('region'), b.castleRegion(e.regionIds.first)?.name ?? '');
        }
      default:
        break;
    }
    final unesco = e.m('unesco');
    if (unesco.isNotEmpty && unesco != '0') {
      fact(Icons.verified_outlined, s.t('unesco'), s.t('unesco_since', {'y': unesco}));
    }

    // Related: same region/type, and stories from linked empires.
    List<int> group(Entry x) => switch (x.kind) {
          EntryKind.museum => x.countryIds,
          _ => x.regionIds,
        };
    final siblings = b
        .entriesOf(e.kind)
        .where((x) => x.id != e.id && group(x).any(group(e).contains))
        .take(8)
        .toList();
    final empireIds = e.meta['empires'] is List
        ? (e.meta['empires'] as List).map((v) => int.tryParse('$v') ?? 0).toSet()
        : <int>{};
    final stories = b.episodes.where((x) => empireIds.contains(x.empireId)).take(8).toList();

    final body = readingStyle(context, urdu: urdu, scale: app.textScale);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 300,
          foregroundColor: Colors.white,
          backgroundColor: theme.brightness == Brightness.dark ? Brand.dSurface : Brand.lAccentStrong,
          actions: [
            IconButton(
              tooltip: s.t('read_in_other'),
              icon: const Icon(Icons.translate),
              onPressed: () => _switchLanguage(app),
            ),
            IconButton(
              tooltip: s.t('save'),
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () {
                final now = app.toggleBookmark(e);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(s.t(now ? 'saved' : 'removed'))));
              },
            ),
            IconButton(
              tooltip: s.t('share'),
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(ShareParams(text: '${e.title}\n${e.link}')),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'cover-${e.key}', child: Cover.entry(e)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black45, Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(entryEyebrow(context, e, b)),
              const SizedBox(height: 4),
              Text(e.title, style: theme.textTheme.headlineMedium),
              if (e.tagline.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(e.tagline,
                    style: body.copyWith(
                      fontSize: body.fontSize! * .95,
                      fontStyle: urdu ? FontStyle.normal : FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (e.hasCoords)
                  FilledButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.google.com/maps/search/?api=1&query=${e.lat},${e.lng}'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(s.t('view_on_map')),
                  ),
                if (e.m('website').isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(e.m('website')),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.language),
                    label: Text(s.t('website')),
                  ),
              ]),
              if (facts.isNotEmpty) ...[
                SectionHeaderPlain(s.t('at_a_glance')),
                Card(
                  child: Column(children: [
                    for (var i = 0; i < facts.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: Icon(facts[i].$1, color: theme.colorScheme.primary),
                        title: Text(facts[i].$2, style: theme.textTheme.bodySmall),
                        subtitle: Text(facts[i].$3, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ]),
                ),
              ],
              SectionHeaderPlain(s.t('the_story')),
              HtmlWidget(
                e.content,
                textStyle: body,
                customStylesBuilder: (el) => el.localName == 'p' ? {'margin': '0 0 1em 0'} : null,
                onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              ),
              if (e.mList('highlights').isNotEmpty) ...[
                SectionHeaderPlain(s.t('must_see')),
                for (final h in e.mList('highlights'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: EdgeInsets.only(top: urdu ? 12 : 6),
                        child: Icon(Icons.star, size: 14, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(h, style: body.copyWith(fontSize: body.fontSize! * .9))),
                    ]),
                  ),
              ],
              if (e.timeline.isNotEmpty) ...[
                SectionHeaderPlain(s.t('through_the_ages')),
                _Timeline(rows: e.timeline),
              ],
            ]),
          ),
        ),
        if (stories.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader(s.t('related_episodes'))),
          SliverToBoxAdapter(
            child: CardRow(height: 236, children: [for (final x in stories) EntryCard(x, width: 210)]),
          ),
        ],
        if (siblings.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader(s.t('you_may_like'))),
          SliverToBoxAdapter(
            child: CardRow(height: 236, children: [for (final x in siblings) EntryCard(x, width: 210)]),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }
}

class SectionHeaderPlain extends StatelessWidget {
  const SectionHeaderPlain(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.rows});
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Column(children: [
      for (var i = 0; i < rows.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                ),
                if (i < rows.length - 1)
                  Expanded(child: Container(width: 2, color: c.primary.withValues(alpha: .35))),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (rows[i].isNotEmpty && rows[i][0].isNotEmpty)
                    Text(rows[i][0],
                        style: theme.textTheme.titleSmall?.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
                  if (rows[i].length > 1) Text(rows[i][1], style: theme.textTheme.bodyMedium),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
