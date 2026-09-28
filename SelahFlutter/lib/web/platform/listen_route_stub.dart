import 'dart:async';

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
  static final ListenRouteHistory instance = ListenRouteHistory._();

  ListenRouteHistory._();

  ListenRouteLocation get current => const ListenRouteLocation();

  Stream<ListenRouteLocation> get changes => const Stream.empty();

  bool get canReturnToOrigin => false;

  void openDetail(String sentenceId, {required int originTab}) {}

  void replaceDetail(String sentenceId) {}

  void clear() {}

  bool back() => false;
}
