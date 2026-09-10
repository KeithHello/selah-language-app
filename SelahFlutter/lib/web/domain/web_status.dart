import 'learning_models.dart';
import '../l10n/selah_strings.dart';

enum WebSyncState {
  unconfigured,
  localOnly,
  savingLocal,
  localSaveFailed,
  syncing,
  syncFailed,
  pendingChanges,
  offline,
  synced,
}

class WebSyncPresentation {
  const WebSyncPresentation({
    required this.state,
    required this.label,
    required this.detail,
  });

  final WebSyncState state;
  final String label;
  final String detail;

  bool get muted =>
      state != WebSyncState.synced && state != WebSyncState.syncing;

  factory WebSyncPresentation.evaluate({
    required bool configured,
    required bool hasSession,
    required bool online,
    required bool initialized,
    required bool savingLocal,
    required bool localSaveFailed,
    required bool syncing,
    required bool syncFailed,
    required bool hasPendingCloudChanges,
    required DateTime? lastSyncAt,
    String uiLocale = defaultUiLocale,
  }) {
    final strings = SelahStrings.of(uiLocale);
    if (!initialized) {
      return WebSyncPresentation(
        state: WebSyncState.savingLocal,
        label: strings.text('sync.loading'),
        detail: strings.text('sync.loadingDetail'),
      );
    }
    if (localSaveFailed) {
      return WebSyncPresentation(
        state: WebSyncState.localSaveFailed,
        label: strings.text('sync.localSaveFailed'),
        detail: strings.text('sync.localSaveFailedDetail'),
      );
    }
    if (savingLocal) {
      return WebSyncPresentation(
        state: WebSyncState.savingLocal,
        label: strings.text('sync.savingLocal'),
        detail: strings.text('sync.savingLocalDetail'),
      );
    }
    if (!configured || !hasSession) {
      return WebSyncPresentation(
        state: WebSyncState.localOnly,
        label: strings.text('sync.localOnly'),
        detail: strings.text('sync.localOnlyDetail'),
      );
    }
    if (syncing) {
      return WebSyncPresentation(
        state: WebSyncState.syncing,
        label: strings.text('sync.syncing'),
        detail: strings.text('sync.syncingDetail'),
      );
    }
    if (syncFailed) {
      return WebSyncPresentation(
        state: WebSyncState.syncFailed,
        label: strings.text('sync.syncFailed'),
        detail: strings.text('sync.syncFailedDetail'),
      );
    }
    if (!online) {
      return WebSyncPresentation(
        state: WebSyncState.offline,
        label: strings.text('sync.offline'),
        detail: strings.text('sync.offlineDetail'),
      );
    }
    if (hasPendingCloudChanges || lastSyncAt == null) {
      return WebSyncPresentation(
        state: WebSyncState.pendingChanges,
        label: strings.text('sync.pending'),
        detail: strings.text('sync.pendingDetail'),
      );
    }
    return WebSyncPresentation(
      state: WebSyncState.synced,
      label: strings.text('sync.synced'),
      detail: strings.message('sync.syncedDetail', {
        'time': _formatTime(lastSyncAt),
      }),
    );
  }

  static String _formatTime(DateTime? time) {
    if (time == null) return '尚未同步';
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
