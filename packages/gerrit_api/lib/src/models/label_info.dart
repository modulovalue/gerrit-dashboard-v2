import 'account_info.dart';

/// Gerrit `LabelInfo` (very abbreviated, just enough to render a badge).
class LabelInfo {
  final bool approved;
  final bool rejected;
  final bool recommended;
  final bool disliked;
  final List<AccountInfo> allVotes;

  const LabelInfo({
    this.approved = false,
    this.rejected = false,
    this.recommended = false,
    this.disliked = false,
    this.allVotes = const [],
  });

  factory LabelInfo.fromJson(Map<String, dynamic> json) {
    final allRaw = json['all'] as List<dynamic>? ?? const [];
    return LabelInfo(
      approved: json['approved'] != null,
      rejected: json['rejected'] != null,
      recommended: json['recommended'] != null,
      disliked: json['disliked'] != null,
      allVotes: [
        for (final v in allRaw)
          if (v is Map<String, dynamic>) AccountInfo.fromJson(v),
      ],
    );
  }
}
