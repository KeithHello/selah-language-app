import 'dart:async';
import 'dart:js_interop';

@JS('window.location')
external _WindowLocation get _location;

@JS()
extension type _WindowLocation(JSObject _) implements JSObject {
  external JSString get hash;
  external JSString get pathname;
  external JSString get search;
}

@JS('window.history')
external _WindowHistory get _history;

@JS()
extension type _WindowHistory(JSObject _) implements JSObject {
  external JSAny? get state;
  external void pushState(JSAny? data, JSString title, JSString url);
  external void replaceState(JSAny? data, JSString title, JSString url);
  external void back();
}

@JS('String')
external JSString _toJsString(JSAny? value);

@JS('window.addEventListener')
external void _addWindowListener(JSString type, JSFunction listener);

void _historyChanged(JSAny? _) => ListenRouteHistory.instance._publish();

class ListenRouteLocation {
  const ListenRouteLocation({
    this.sentenceId,
    this.originTab,
    this.fragment = '',
  });

  final String? sentenceId;
  final int? originTab;
  final String fragment;
}

class ListenRouteHistory {
  ListenRouteHistory._() {
    _addWindowListener('popstate'.toJS, _historyChanged.toJS);
    _addWindowListener('hashchange'.toJS, _historyChanged.toJS);
  }

  static final ListenRouteHistory instance = ListenRouteHistory._();
  final StreamController<ListenRouteLocation> _changes =
      StreamController<ListenRouteLocation>.broadcast();
  int? _originTab;

  Stream<ListenRouteLocation> get changes => _changes.stream;

  ListenRouteLocation get current {
    final fragment = _location.hash.toDart.replaceFirst(RegExp(r'^#'), '');
    final uri = Uri.tryParse(fragment);
    final match = RegExp(r'^/listen/([^/?#]+)$').firstMatch(uri?.path ?? '');
    final originTab = _originFromState(_history.state) ?? _originTab;
    if (match == null) {
      return ListenRouteLocation(originTab: originTab, fragment: fragment);
    }
    try {
      final sentenceId = Uri.decodeComponent(match.group(1)!);
      _originTab = originTab;
      return ListenRouteLocation(
        sentenceId: sentenceId,
        originTab: originTab,
        fragment: fragment,
      );
    } on FormatException {
      return ListenRouteLocation(originTab: originTab, fragment: fragment);
    }
  }

  bool get canReturnToOrigin => current.originTab != null;

  void openDetail(String sentenceId, {required int originTab}) {
    final existing = current;
    if (existing.sentenceId != null) {
      _originTab ??= existing.originTab ?? originTab;
      replaceDetail(sentenceId);
      return;
    }
    _originTab = originTab;
    _history.replaceState(
      _originState(originTab),
      ''.toJS,
      (originTab == 5 && current.fragment == '/admin'
              ? _currentUrl
              : _documentUrl)
          .toJS,
    );
    _history.pushState(
      _originState(originTab),
      ''.toJS,
      _detailUrl(sentenceId).toJS,
    );
  }

  void replaceDetail(String sentenceId) {
    _originTab ??= current.originTab;
    _history.replaceState(
      _originTab == null ? null : _originState(_originTab!),
      ''.toJS,
      _detailUrl(sentenceId).toJS,
    );
  }

  void clear() {
    final fragment = current.fragment;
    if (fragment.startsWith('/listen/')) {
      _history.replaceState(null, ''.toJS, _documentUrl.toJS);
    }
    _originTab = null;
  }

  bool back() {
    if (!canReturnToOrigin) return false;
    _history.back();
    return true;
  }

  String get _documentUrl =>
      '${_location.pathname.toDart}${_location.search.toDart}';

  String get _currentUrl => '$_documentUrl${_location.hash.toDart}';

  String _detailUrl(String sentenceId) =>
      '$_documentUrl#/listen/${Uri.encodeComponent(sentenceId)}';

  int? _originFromState(JSAny? state) {
    if (state == null) return null;
    final match = RegExp(
      r'^selah-listen-origin:([0-5])$',
    ).firstMatch(_toJsString(state).toDart);
    return int.tryParse(match?.group(1) ?? '');
  }

  JSString _originState(int tab) => 'selah-listen-origin:$tab'.toJS;

  void _publish() => _changes.add(current);
}
