import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// The list under the bell icon in the app bar.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AppState _app = context.read<AppState>();

  @override
  void dispose() {
    // Opening the list counts as reading it.
    Future.microtask(_app.markNoticesRead);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final notices = app.notices;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('notifications')),
        actions: [
          if (notices.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'read' ? app.markNoticesRead() : app.clearNotices(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'read', child: Text(s.t('mark_all_read'))),
                PopupMenuItem(value: 'clear', child: Text(s.t('clear_all'))),
              ],
            ),
        ],
      ),
      body: notices.isEmpty
          ? EmptyView(s.t('no_notifications'), icon: Icons.notifications_none)
          : ListView.separated(
              itemCount: notices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = notices[i];
                final theme = Theme.of(context);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: .15),
                    child: Icon(
                      n.entryKey == null ? Icons.celebration_outlined : Icons.auto_stories,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(n.body,
                      style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w600)),
                  subtitle: Text('${n.title} · ${s.date(n.time)}'),
                  trailing: n.read
                      ? null
                      : Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
                  onTap: n.entryKey == null
                      ? null
                      : () => openEntryKey(context, n.entryKey!, lang: n.lang),
                );
              },
            ),
    );
  }
}
