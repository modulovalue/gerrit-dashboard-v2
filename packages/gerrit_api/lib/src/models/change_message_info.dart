import 'account_info.dart';

/// Gerrit `ChangeMessageInfo`.
class ChangeMessageInfo {
  final String id;
  final AccountInfo? author;
  final DateTime? date;
  final String message;
  final int? revisionNumber;
  final String? tag;

  const ChangeMessageInfo({
    required this.id,
    required this.message,
    this.author,
    this.date,
    this.revisionNumber,
    this.tag,
  });

  factory ChangeMessageInfo.fromJson(Map<String, dynamic> json) =>
      ChangeMessageInfo(
        id: (json['id'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
        author: json['author'] is Map<String, dynamic>
            ? AccountInfo.fromJson(json['author'] as Map<String, dynamic>)
            : null,
        date: switch (json['date']) {
          final String s => DateTime.tryParse(s.replaceFirst(' ', 'T')),
          _ => null,
        },
        revisionNumber: json['_revision_number'] as int?,
        tag: json['tag'] as String?,
      );
}
