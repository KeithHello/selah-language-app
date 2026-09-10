import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/web_status.dart';

void main() {
  test('local save failure is visible even before cloud sync state', () {
    final status = WebSyncPresentation.evaluate(
      configured: false,
      hasSession: false,
      online: true,
      initialized: true,
      savingLocal: false,
      localSaveFailed: true,
      syncing: false,
      syncFailed: false,
      hasPendingCloudChanges: false,
      lastSyncAt: null,
    );
    expect(status.state, WebSyncState.localSaveFailed);
    expect(status.label, contains('本機保存失敗'));
  });

  test('guest input is local-only and never reported as cloud synced', () {
    final status = WebSyncPresentation.evaluate(
      configured: true,
      hasSession: false,
      online: true,
      initialized: true,
      savingLocal: false,
      localSaveFailed: false,
      syncing: false,
      syncFailed: false,
      hasPendingCloudChanges: false,
      lastSyncAt: null,
    );
    expect(status.state, WebSyncState.localOnly);
    expect(status.detail, contains('登入後才能同步'));
  });

  test('authenticated account with no successful sync shows pending changes', () {
    final status = WebSyncPresentation.evaluate(
      configured: true,
      hasSession: true,
      online: true,
      initialized: true,
      savingLocal: false,
      localSaveFailed: false,
      syncing: false,
      syncFailed: false,
      hasPendingCloudChanges: false,
      lastSyncAt: null,
    );
    expect(status.state, WebSyncState.pendingChanges);
  });

  test('syncing and failure take precedence over browser online state', () {
    expect(
      WebSyncPresentation.evaluate(
        configured: true,
        hasSession: true,
        online: true,
        initialized: true,
        savingLocal: false,
        localSaveFailed: false,
        syncing: true,
        syncFailed: false,
        hasPendingCloudChanges: true,
        lastSyncAt: DateTime(2026),
      ).state,
      WebSyncState.syncing,
    );
    expect(
      WebSyncPresentation.evaluate(
        configured: true,
        hasSession: true,
        online: true,
        initialized: true,
        savingLocal: false,
        localSaveFailed: false,
        syncing: false,
        syncFailed: true,
        hasPendingCloudChanges: true,
        lastSyncAt: DateTime(2026),
      ).state,
      WebSyncState.syncFailed,
    );
  });

  test('offline account shows offline state without claiming sync success', () {
    final status = WebSyncPresentation.evaluate(
      configured: true,
      hasSession: true,
      online: false,
      initialized: true,
      savingLocal: false,
      localSaveFailed: false,
      syncing: false,
      syncFailed: false,
      hasPendingCloudChanges: true,
      lastSyncAt: DateTime(2026),
    );
    expect(status.state, WebSyncState.offline);
    expect(status.detail, contains('連線後自動重試'));
  });
}
