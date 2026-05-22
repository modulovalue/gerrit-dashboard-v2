const _xssiGuard = ")]}'";

/// Gerrit prefixes every JSON response with `)]}'` to prevent JSON
/// hijacking. Strip it before decoding.
String stripXssiPrefix(String body) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith(_xssiGuard)) {
    return trimmed.substring(_xssiGuard.length).trimLeft();
  }
  return trimmed;
}
