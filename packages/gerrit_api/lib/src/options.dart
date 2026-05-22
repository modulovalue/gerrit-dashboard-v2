/// `o=` query parameters for the `/changes/` endpoints.
///
/// See https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html
enum ChangeOption {
  currentRevision('CURRENT_REVISION'),
  allRevisions('ALL_REVISIONS'),
  currentCommit('CURRENT_COMMIT'),
  currentFiles('CURRENT_FILES'),
  detailedLabels('DETAILED_LABELS'),
  detailedAccounts('DETAILED_ACCOUNTS'),
  messages('MESSAGES'),
  reviewedFlag('REVIEWED'),
  labels('LABELS'),
  commitFooters('COMMIT_FOOTERS'),
  webLinks('WEB_LINKS');

  final String wire;
  const ChangeOption(this.wire);
}
