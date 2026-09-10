import 'app/native_entry.dart'
    if (dart.library.js_interop) 'web/web_entry.dart'
    as entry;

Future<void> main() async => entry.launch();
