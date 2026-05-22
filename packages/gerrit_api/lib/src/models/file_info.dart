/// Gerrit `FileInfo` (entry inside a RevisionInfo's `files` map).
class FileInfo {
  final String path;
  final String status; // A, M, D, R, C
  final int linesInserted;
  final int linesDeleted;
  final int sizeDelta;
  final bool binary;

  const FileInfo({
    required this.path,
    required this.status,
    required this.linesInserted,
    required this.linesDeleted,
    required this.sizeDelta,
    required this.binary,
  });

  factory FileInfo.fromJson(String path, Map<String, dynamic> json) => FileInfo(
        path: path,
        status: (json['status'] as String?) ?? 'M',
        linesInserted: (json['lines_inserted'] as int?) ?? 0,
        linesDeleted: (json['lines_deleted'] as int?) ?? 0,
        sizeDelta: (json['size_delta'] as int?) ?? 0,
        binary: (json['binary'] as bool?) ?? false,
      );
}
