/// Gerrit `AccountInfo`.
class AccountInfo {
  final int? accountId;
  final String? name;
  final String? email;
  final String? username;
  final String? displayName;

  const AccountInfo({
    this.accountId,
    this.name,
    this.email,
    this.username,
    this.displayName,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        accountId: json['_account_id'] as int?,
        name: json['name'] as String?,
        email: json['email'] as String?,
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
      );

  String get bestLabel =>
      displayName ?? name ?? username ?? email ?? 'Account #$accountId';
}
