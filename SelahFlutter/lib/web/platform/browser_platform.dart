import 'dart:convert';
import 'dart:js_interop';
import 'learning_platform.dart';

@JS('selahBridge')
external JSPromise<JSString> _bridge(JSString action, JSString payload);

class BrowserLearningPlatform implements LearningPlatform {
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    final result = await _bridge(action.toJS, jsonEncode(payload).toJS).toDart;
    return jsonDecode(result.toDart);
  }
}
