import 'dart:js_interop';

import 'package:flutter/foundation.dart';

// Bridge defined in web/index.html (window.rallyPwa).
@JS('rallyPwa')
external _RallyPwa? get _bridge;

@JS('rallyOnInstallChange')
external set _onInstallChange(JSFunction? f);

extension type _RallyPwa._(JSObject _) implements JSObject {
  external bool canPrompt();
  external bool isStandalone();
  external bool isIos();
  external JSPromise<JSBoolean> prompt();
}

class PwaInstall {
  PwaInstall._() {
    _onInstallChange = (() => changes.value++).toJS;
  }
  static final PwaInstall instance = PwaInstall._();

  /// Bumped when the browser's install state changes (prompt became
  /// available, app installed).
  final ValueNotifier<int> changes = ValueNotifier(0);

  bool get isStandalone => _bridge?.isStandalone() ?? false;
  bool get isIos => _bridge?.isIos() ?? false;
  bool get canPrompt => _bridge?.canPrompt() ?? false;

  /// Shows the browser's install dialog; true if the user accepted.
  Future<bool> prompt() async {
    final bridge = _bridge;
    if (bridge == null) return false;
    return (await bridge.prompt().toDart).toDart;
  }
}

final pwaInstall = PwaInstall.instance;
