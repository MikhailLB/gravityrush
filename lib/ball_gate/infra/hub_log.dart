import 'package:flutter/foundation.dart';

/// Debug-only logger. The closure and its string literals are stripped from
/// release builds by the Dart compiler because the call is inside `assert`.
/// Never use bare `debugPrint` — literal tags survive tree-shaking.
void hubLog(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}
