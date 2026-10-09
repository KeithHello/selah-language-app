import 'web_performance_marks_stub.dart'
    if (dart.library.js_interop) 'web_performance_marks_web.dart'
    as platform;

void markSelahPerformance(String name) => platform.markSelahPerformance(name);
