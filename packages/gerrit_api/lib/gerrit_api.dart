/// Pure Dart bindings for the Gerrit REST API.
///
/// Anonymous, read-only. Works on web (Wasm) and native.
library;

export 'src/client.dart';
export 'src/exceptions.dart';
export 'src/options.dart';
export 'src/models/account_info.dart';
export 'src/models/change_info.dart';
export 'src/models/change_message_info.dart';
export 'src/models/file_info.dart';
export 'src/models/label_info.dart';
export 'src/models/project_info.dart';
export 'src/models/revision_info.dart';
export 'src/xssi.dart' show stripXssiPrefix;
