import 'account_info.dart';
import 'change_message_info.dart';
import 'label_info.dart';
import 'revision_info.dart';

enum ChangeStatus {
  newChange('NEW'),
  merged('MERGED'),
  abandoned('ABANDONED'),
  unknown('UNKNOWN');

  final String wire;
  const ChangeStatus(this.wire);

  static ChangeStatus parse(String raw) {
    final upper = raw.toUpperCase();
    return ChangeStatus.values.firstWhere(
      (s) => s.wire == upper,
      orElse: () => ChangeStatus.unknown,
    );
  }
}

/// Gerrit `ChangeInfo`.
class ChangeInfo {
  final int number;
  final String changeId;
  final String subject;
  final ChangeStatus status;
  final String project;
  final String branch;
  final String? topic;
  final List<String> hashtags;
  final AccountInfo? owner;
  final String? currentRevision;
  final Map<String, RevisionInfo> revisions;
  final Map<String, LabelInfo> labels;
  final List<ChangeMessageInfo> messages;
  final DateTime? created;
  final DateTime? updated;
  final DateTime? submitted;
  final int? insertions;
  final int? deletions;
  final int? totalCommentCount;
  final int? unresolvedCommentCount;
  final bool? mergeable;
  final bool work;
  final bool isPrivate;

  const ChangeInfo({
    required this.number,
    required this.changeId,
    required this.subject,
    required this.status,
    required this.project,
    required this.branch,
    this.topic,
    this.hashtags = const [],
    this.owner,
    this.currentRevision,
    this.revisions = const {},
    this.labels = const {},
    this.messages = const [],
    this.created,
    this.updated,
    this.submitted,
    this.insertions,
    this.deletions,
    this.totalCommentCount,
    this.unresolvedCommentCount,
    this.mergeable,
    this.work = false,
    this.isPrivate = false,
  });

  factory ChangeInfo.fromJson(Map<String, dynamic> json) {
    final revisionsRaw = json['revisions'] as Map<String, dynamic>? ?? const {};
    final revisions = <String, RevisionInfo>{
      for (final entry in revisionsRaw.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key:
              RevisionInfo.fromJson(entry.key, entry.value as Map<String, dynamic>),
    };

    final labelsRaw = json['labels'] as Map<String, dynamic>? ?? const {};
    final labels = <String, LabelInfo>{
      for (final entry in labelsRaw.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: LabelInfo.fromJson(entry.value as Map<String, dynamic>),
    };

    final messagesRaw = json['messages'] as List<dynamic>? ?? const [];
    final messages = <ChangeMessageInfo>[
      for (final m in messagesRaw)
        if (m is Map<String, dynamic>) ChangeMessageInfo.fromJson(m),
    ];

    final hashtagsRaw = json['hashtags'] as List<dynamic>? ?? const [];
    final hashtags = <String>[
      for (final h in hashtagsRaw)
        if (h is String) h,
    ];

    return ChangeInfo(
      number: (json['_number'] as int?) ?? 0,
      changeId: (json['change_id'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '',
      status: ChangeStatus.parse((json['status'] as String?) ?? 'UNKNOWN'),
      project: (json['project'] as String?) ?? '',
      branch: (json['branch'] as String?) ?? '',
      topic: json['topic'] as String?,
      hashtags: hashtags,
      owner: json['owner'] is Map<String, dynamic>
          ? AccountInfo.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      currentRevision: json['current_revision'] as String?,
      revisions: revisions,
      labels: labels,
      messages: messages,
      created: _parseDate(json['created']),
      updated: _parseDate(json['updated']),
      submitted: _parseDate(json['submitted']),
      insertions: json['insertions'] as int?,
      deletions: json['deletions'] as int?,
      totalCommentCount: json['total_comment_count'] as int?,
      unresolvedCommentCount: json['unresolved_comment_count'] as int?,
      mergeable: json['mergeable'] as bool?,
      work: (json['work_in_progress'] as bool?) ?? false,
      isPrivate: (json['is_private'] as bool?) ?? false,
    );
  }

  RevisionInfo? get currentRevisionInfo {
    final id = currentRevision;
    if (id == null) return null;
    return revisions[id];
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
}
