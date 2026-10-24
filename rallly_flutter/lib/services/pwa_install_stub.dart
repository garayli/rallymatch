import 'package:flutter/foundation.dart';

/// Native build: the app is already installed, nothing to offer.
class PwaInstall {
  PwaInstall._();
  static final PwaInstall instance = PwaInstall._();

  /// Bumped when the browser's install state changes.
  final ValueNotifier<int> changes = ValueNotifier(0);

  bool get isStandalone => true;
  bool get isIos => false;
  bool get canPrompt => false;

  Future<bool> prompt() async => false;
}

final pwaInstall = PwaInstall.instance;
