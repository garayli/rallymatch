// The only file that may import `package:clarity_flutter`, and only through
// the native half: its `xxh3` dependency uses 64-bit integer literals that
// dart2js cannot compile, so importing it anywhere on the web build path
// breaks `flutter build web`. Web gets the no-op stub instead.
export 'clarity_sdk_stub.dart'
    if (dart.library.io) 'clarity_sdk_native.dart';
