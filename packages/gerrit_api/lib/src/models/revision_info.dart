import 'account_info.dart';
import 'file_info.dart';

/// Gerrit `CommitInfo` (the inner `commit` object of a revision).
class CommitInfo {
  final String? subject;
  final String? message;
  final AccountInfo? author;
  final AccountInfo? committer;

  const CommitInfo({this.subject, this.message, this.author, this.committer});

  factory CommitInfo.fromJson(Map<String, dynamic> json) => CommitInfo(
        subject: json['subject'] as String?,
        message: json['message'] as String?,
        author: json['author'] is Map<String, dynamic>
            ? AccountInfo.fromJson(json['author'] as Map<String, dynamic>)
            : null,
        committer: json['committer'] is Map<String, dynamic>
            ? AccountInfo.fromJson(json['committer'] as Map<String, dynamic>)
            : null,
      );
}

/// Gerrit `RevisionInfo`.
class RevisionInfo {
  final String revisionId;
  final int number;
  final String? ref;
  final CommitInfo? commit;
  final List<FileInfo> files;
  final AccountInfo? uploader;
  final DateTime? created;

  const RevisionInfo({
    required this.revisionId,
    required this.number,
    this.ref,
    this.commit,
    this.files = const [],
    this.uploader,
    this.created,
  });

  factory RevisionInfo.fromJson(String revisionId, Map<String, dynamic> json) {
    final filesRaw = json['files'] as Map<String, dynamic>? ?? const {};
    final files = <FileInfo>[
      for (final entry in filesRaw.entries)
        if (entry.value is Map<String, dynamic>)
          FileInfo.fromJson(entry.key, entry.value as Map<String, dynamic>),
    ];

    return RevisionInfo(
      revisionId: revisionId,
      number: (json['_number'] as int?) ?? 1,
      ref: json['ref'] as String?,
      commit: json['commit'] is Map<String, dynamic>
          ? CommitInfo.fromJson(json['commit'] as Map<String, dynamic>)
          : null,
      files: files,
      uploader: json['uploader'] is Map<String, dynamic>
          ? AccountInfo.fromJson(json['uploader'] as Map<String, dynamic>)
          : null,
      created: switch (json['created']) {
        final String s => DateTime.tryParse(s.replaceFirst(' ', 'T')),
        _ => null,
      },
    );
  }
}
