import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';

void main() {
  // Without this, Flutter web uses hash URLs (`/#/u/alice`) and direct
  // path-style links like `/gerrit-dashboard-v2/u/alice` boot to `/`.
  usePathUrlStrategy();
  runApp(const ProviderScope(child: GerritDashboardApp()));
}
