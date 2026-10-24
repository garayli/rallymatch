// "Add to home screen" support for the web (PWA) build. On Android/iOS
// native builds every call is a no-op, so callers need no kIsWeb checks.
export 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';
