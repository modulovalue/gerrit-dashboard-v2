/// Gerrit `ProjectInfo`.
class ProjectInfo {
  final String id;
  final String? name;
  final String? description;
  final String? state;

  const ProjectInfo({
    required this.id,
    this.name,
    this.description,
    this.state,
  });

  factory ProjectInfo.fromJson(String name, Map<String, dynamic> json) =>
      ProjectInfo(
        id: (json['id'] as String?) ?? name,
        name: (json['name'] as String?) ?? name,
        description: json['description'] as String?,
        state: json['state'] as String?,
      );
}
