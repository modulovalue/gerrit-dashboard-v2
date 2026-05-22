import 'package:flutter/material.dart';
import 'package:gerrit_api/gerrit_api.dart';

class StatusBadge extends StatelessWidget {
  final ChangeStatus status;
  final bool work;
  final bool isPrivate;

  const StatusBadge({
    super.key,
    required this.status,
    this.work = false,
    this.isPrivate = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      ChangeStatus.newChange => ('OPEN', scheme.primary),
      ChangeStatus.merged => ('MERGED', Colors.green.shade700),
      ChangeStatus.abandoned => ('ABANDONED', Colors.orange.shade700),
      ChangeStatus.unknown => ('UNKNOWN', scheme.outline),
    };

    final chips = <Widget>[
      _chip(label, color, color.computeLuminance() > 0.5
          ? Colors.black
          : Colors.white),
    ];
    if (work) chips.add(_chip('WIP', Colors.amber.shade800, Colors.white));
    if (isPrivate) {
      chips.add(_chip('PRIVATE', Colors.purple.shade600, Colors.white));
    }

    return Wrap(spacing: 4, children: chips);
  }

  static Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
}
