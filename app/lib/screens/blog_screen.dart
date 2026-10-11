import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/cover.dart';

/// Blog posts, newest first, with category chips.
class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bundle;
    final s = S.of(context);
    final categories = <String>{for (final p in b.posts) ...p.categories}.toList();
    final posts = b.posts
        .where((p) => _category == null || p.categories.contains(_category))
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('blog')), actions: appBarActions(context)),
      body: posts.isEmpty
          ? EmptyView(s.t('empty_list'), icon: Icons.article_outlined)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: posts.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  if (categories.length < 2) return const SizedBox(height: 8);
                  return SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        ChoiceChip(
                          label: Text(s.t('all')),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                        for (final c in categories) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                final p = posts[i - 1];
                if (i == 1) {
                  // Lead post as a big card.
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: InkWell(
                      onTap: () => openEntry(context, p),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(aspectRatio: 16 / 9, child: Cover.entry(p)),
                        ),
                        const SizedBox(height: 10),
                        Eyebrow(entryEyebrow(context, p, b)),
                        Text(p.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(p.excerpt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(entryMeta(context, p, b), style: theme.textTheme.bodySmall),
                      ]),
                    ),
                  );
                }
                return EntryTile(p);
              },
            ),
    );
  }
}
