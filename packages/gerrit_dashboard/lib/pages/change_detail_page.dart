import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gerrit_api/gerrit_api.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/settings_controller.dart';
import '../widgets/status_badge.dart';

final _changeDetailProvider =
    FutureProvider.family<ChangeInfo, int>((ref, number) async {
  final client = ref.watch(gerritClientProvider);
  return client.getChangeDetail(number);
});

class ChangeDetailPage extends ConsumerWidget {
  final int number;
  const ChangeDetailPage({super.key, required this.number});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(_changeDetailProvider(number));

    return Scaffold(
      appBar: AppBar(
        title: Text('CL $number'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          async.maybeWhen(
            data: (change) {
              final starred = ref.watch(starredProvider);
              final key =
                  starKey(settings.webHost, change.project, change.number);
              final isStarred = starred.contains(key);
              return IconButton(
                tooltip: isStarred ? 'Unstar' : 'Star this CL',
                icon: Icon(
                  isStarred ? Icons.star : Icons.star_outline,
                  color: isStarred ? Colors.amber.shade700 : null,
                ),
                onPressed: () =>
                    ref.read(starredProvider.notifier).toggle(key),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_changeDetailProvider(number)),
          ),
          async.maybeWhen(
            data: (change) => IconButton(
              tooltip: 'Open in Gerrit',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openInGerrit(
                webHost: settings.webHost,
                project: change.project,
                number: change.number,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText('Error loading CL $number:\n\n$e'),
        ),
        data: (change) => _ChangeBody(change: change),
      ),
    );
  }
}

Future<void> _openInGerrit({
  required String webHost,
  required String project,
  required int number,
}) async {
  final uri = Uri.https(webHost, '/c/$project/+/$number');
  await launchUrl(uri, webOnlyWindowName: '_blank');
}

class _ChangeBody extends StatelessWidget {
  final ChangeInfo change;
  const _ChangeBody({required this.change});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd().add_jm();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(change.subject, style: text.headlineSmall),
            ),
            const SizedBox(width: 12),
            StatusBadge(
              status: change.status,
              work: change.work,
              isPrivate: change.isPrivate,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _meta('Owner', change.owner?.bestLabel ?? 'unknown'),
            _meta('Project', change.project),
            _meta('Branch', change.branch),
            if (change.topic != null && change.topic!.isNotEmpty)
              _meta('Topic', change.topic!),
            if (change.updated != null)
              _meta('Updated', dateFmt.format(change.updated!)),
            if (change.insertions != null && change.deletions != null)
              _meta('Diff', '+${change.insertions} / -${change.deletions}'),
          ],
        ),
        if (change.labels.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Labels', style: text.titleMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final entry in change.labels.entries)
                _LabelChip(name: entry.key, label: entry.value),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _CommitMessageSection(change: change),
        const SizedBox(height: 24),
        _FilesSection(change: change),
        const SizedBox(height: 24),
        _MessagesSection(change: change),
      ],
    );
  }

  Widget _meta(String key, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF888888)),
          children: [
            TextSpan(text: '$key: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFFCFCFCF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _LabelChip extends StatelessWidget {
  final String name;
  final LabelInfo label;
  const _LabelChip({required this.name, required this.label});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    if (label.approved) {
      icon = Icons.check_circle;
      color = Colors.green.shade600;
    } else if (label.rejected) {
      icon = Icons.cancel;
      color = Colors.red.shade600;
    } else if (label.recommended) {
      icon = Icons.thumb_up;
      color = Colors.green.shade400;
    } else if (label.disliked) {
      icon = Icons.thumb_down;
      color = Colors.orange.shade600;
    } else {
      icon = Icons.help_outline;
      color = Theme.of(context).colorScheme.outline;
    }
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(name),
    );
  }
}

class _FilesSection extends StatelessWidget {
  final ChangeInfo change;
  const _FilesSection({required this.change});

  @override
  Widget build(BuildContext context) {
    final rev = change.currentRevisionInfo;
    if (rev == null || rev.files.isEmpty) {
      return const SizedBox.shrink();
    }
    final files = [...rev.files]
      ..removeWhere((f) => f.path == '/COMMIT_MSG');
    if (files.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Files (${files.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final file in files)
                ListTile(
                  dense: true,
                  leading: _statusIcon(file.status),
                  title: Text(
                    file.path,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  trailing: file.binary
                      ? const Text('binary')
                      : Text(
                          '+${file.linesInserted} -${file.linesDeleted}',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusIcon(String status) {
    final (icon, color) = switch (status) {
      'A' => (Icons.add, Colors.green),
      'D' => (Icons.remove, Colors.red),
      'R' => (Icons.swap_horiz, Colors.blue),
      'C' => (Icons.content_copy, Colors.blue),
      _ => (Icons.edit, Colors.amber),
    };
    return Icon(icon, color: color, size: 18);
  }
}

class _CommitMessageSection extends StatelessWidget {
  final ChangeInfo change;
  const _CommitMessageSection({required this.change});

  @override
  Widget build(BuildContext context) {
    final commit = change.currentRevisionInfo?.commit;
    if (commit == null || commit.message == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Commit message', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              commit.message!,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessagesSection extends StatelessWidget {
  final ChangeInfo change;
  const _MessagesSection({required this.change});

  @override
  Widget build(BuildContext context) {
    if (change.messages.isEmpty) return const SizedBox.shrink();
    final messages = [...change.messages]
      ..sort((a, b) {
        final ad = a.date;
        final bd = b.date;
        if (ad == null || bd == null) return 0;
        return bd.compareTo(ad);
      });
    final dateFmt = DateFormat.yMMMd().add_jm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Messages (${messages.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < messages.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text(
                    messages[i].author?.bestLabel ?? 'system',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: SelectableText(messages[i].message),
                  trailing: Text(
                    messages[i].date == null
                        ? ''
                        : dateFmt.format(messages[i].date!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
