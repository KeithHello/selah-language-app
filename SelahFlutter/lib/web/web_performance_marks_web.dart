import 'dart:js_interop';

@JS('performance.mark')
external void _markPerformance(JSString name);

void markSelahPerformance(String name) => _markPerformance(name.toJS);
