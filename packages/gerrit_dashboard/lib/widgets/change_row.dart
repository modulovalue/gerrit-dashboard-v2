import 'package:flutter/material.dart';
import 'package:gerrit_api/gerrit_api.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'status_badge.dart';

class ChangeRow extends StatelessWidget {
  final ChangeInfo change;
  final String host;
  final String project;

  const ChangeRow({
    super.key,
    required this.change,
    required this.host,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = StringBuffer()
      ..write(change.owner?.bestLabel ?? 'unknown')
      ..write(' • ')
      ..write(change.project)
      ..write('/')
      ..write(change.branch);
    if (change.topic != null && change.topic!.isNotEmpty) {
      subtitle.write(' • topic:${change.topic}');
    }

    final updated = change.updated;
    final relTime = updated == null ? '' : _relative(updated);

    return InkWell(
      onTap: () => context.go('/c/${change.number}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#${change.number}',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(
                    status: change.status,
                    work: change.work,
                    isPrivate: change.isPrivate,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    change.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (relTime.isNotEmpty)
                    Text(relTime, style: text.bodySmall),
                  if (change.insertions != null && change.deletions != null)
                    Text(
                      '+${change.insertions} -${change.deletions}',
                      style: text.bodySmall
                          ?.copyWith(color: Colors.green.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relative(DateTime then) {
  final now = DateTime.now().toUtc();
  final t = then.toUtc();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  final fmt = DateFormat.yMMMd();
  return fmt.format(then);
}
