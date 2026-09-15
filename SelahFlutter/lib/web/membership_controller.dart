import 'dart:async';
import 'package:flutter/foundation.dart';
import 'data/learning_gateway.dart';
import 'domain/membership.dart';
import 'domain/learning_models.dart';

class MembershipController extends ChangeNotifier {
  MembershipController({required this.gateway}) {
    _accountId = gateway.userId;
    _sub = gateway.accountChanges.listen((id) {
      if (id != _accountId) {
        _accountId = id;
        _accountGeneration++;
        _resetAccountScopedState();
        if (!_disposed) notifyListeners();
      }
      unawaited(load());
    });
  }

  final LearningGateway gateway;
  StreamSubscription<String?>? _sub;
  MembershipSummary summary = MembershipSummary.empty();
  bool loading = false;
  bool checked = false;
  String? error;
  bool checkoutLoading = false;
  String? checkoutStatus;
  String? pendingOrderId;
  String? pendingClientRequestId;
  bool _disposed = false;
  String? _accountId;
  int _accountGeneration = 0;

  bool get membershipModeEnabled => summary.membershipModeEnabled;
  bool get trialSignupsAvailable =>
      summary.membershipModeEnabled && summary.trialSignupsEnabled;
  bool get membershipSalesAvailable =>
      summary.membershipModeEnabled &&
      summary.membershipSalesEnabled &&
      summary.paymentProviderConfigured;
  bool get proSalesAvailable =>
      summary.membershipModeEnabled &&
      summary.proSalesEnabled &&
      summary.paymentProviderConfigured &&
      summary.entitlementVersion == 'pro-v1';

  /// Pro has a client-side contract and presentation, but no provider-backed
  /// checkout yet.  Keep this guard explicit so a future server flag cannot
  /// accidentally turn an unconfigured SKU into a false payment flow.
  Future<void> startProCheckout({String? uiLocale}) async {
    final locale = normalizeUiLocale(uiLocale);
    error = locale == 'ja'
        ? 'Pro の決済チャネルはまだ設定されていません。近日公開です。'
        : locale == 'zh-Hant'
        ? 'Pro 的支付渠道尚未設定，暫未開放。'
        : 'Pro 的支付渠道尚未配置，暂未开放。';
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    final expectedAccountId = gateway.userId;
    if (expectedAccountId != _accountId) {
      _accountId = expectedAccountId;
      _accountGeneration++;
      _resetAccountScopedState();
    }
    final requestGeneration = _accountGeneration;
    if (!gateway.configured || expectedAccountId == null) {
      summary = MembershipSummary.empty();
      checked = true;
      if (!_disposed) notifyListeners();
      return;
    }
    loading = true;
    error = null;
    if (!_disposed) notifyListeners();
    try {
      final response = await gateway.invoke('membership-status', {}, get: true);
      if (!_isCurrent(expectedAccountId, requestGeneration)) return;
      summary = MembershipSummary.fromJson(response);
      checked = true;
    } on LearningFailure catch (f) {
      if (!_isCurrent(expectedAccountId, requestGeneration)) return;
      error = f.message;
      checked = true;
    } catch (_) {
      if (!_isCurrent(expectedAccountId, requestGeneration)) return;
      error = '会员状态暂时无法读取，请稍后重试。';
      checked = true;
    } finally {
      if (_isCurrent(expectedAccountId, requestGeneration)) {
        loading = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  /// Creates one server-owned pending order. A pending order is never treated
  /// as paid in the client; refreshing its status is the only path that can
  /// clear the pending state and reload entitlements.
  Future<void> startMonthlyCheckout({String channel = 'mock_channel'}) async {
    if (_disposed) return;
    if (!gateway.configured || gateway.userId == null) {
      error = '登录后才能开通会员。';
      if (!_disposed) notifyListeners();
      return;
    }
    if (!summary.membershipModeEnabled || !summary.membershipSalesEnabled) {
      error = '会员购买暂未开放，请稍后再试。';
      if (!_disposed) notifyListeners();
      return;
    }
    if (!summary.paymentProviderConfigured) {
      error = '支付渠道尚未配置，暂未开放。';
      if (!_disposed) notifyListeners();
      return;
    }
    if (checkoutLoading) return;
    if (pendingOrderId != null || pendingClientRequestId != null) {
      await refreshPendingOrder();
      return;
    }
    checkoutLoading = true;
    error = null;
    checkoutStatus = null;
    final accountId = gateway.userId;
    final requestGeneration = _accountGeneration;
    if (!_disposed) notifyListeners();
    final requestId = newId();
    pendingClientRequestId = requestId;
    try {
      final response = await gateway.invoke('membership-checkout', {
        'clientRequestId': requestId,
        'sku': 'selah_membership_monthly',
        'channel': channel,
      });
      if (!_isCurrent(accountId, requestGeneration)) return;
      pendingOrderId = response['orderId']?.toString();
      checkoutStatus = switch (response['status']?.toString()) {
        'paid' => '付款已核实，正在刷新会员状态。',
        'failed' || 'refunded' => '这笔订单未完成，请重新发起购买。',
        _ => '订单已建立；完成付款后可查询订单状态。',
      };
      if (response['status'] == 'paid') {
        await load();
        _clearPendingOrder();
      }
    } on LearningFailure catch (failure) {
      if (!_isCurrent(accountId, requestGeneration)) return;
      error = failure.message;
      if (failure.code != 'timeout' && failure.code != 'network_unavailable') {
        _clearPendingOrder();
      }
    } catch (_) {
      if (!_isCurrent(accountId, requestGeneration)) return;
      error = '订单暂时无法建立，请稍后重试。';
    } finally {
      if (_isCurrent(accountId, requestGeneration)) {
        checkoutLoading = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  Future<void> refreshPendingOrder() async {
    if (_disposed) return;
    final orderId = pendingOrderId;
    final requestId = pendingClientRequestId;
    if (orderId == null && requestId == null) return;
    checkoutLoading = true;
    error = null;
    final accountId = gateway.userId;
    final requestGeneration = _accountGeneration;
    if (!_disposed) notifyListeners();
    try {
      final response = await gateway.invoke('membership-order-status', {
        ...?orderId != null ? {'orderId': orderId} : null,
        ...?requestId != null ? {'clientRequestId': requestId} : null,
      });
      if (!_isCurrent(accountId, requestGeneration)) return;
      final status = response['status']?.toString() ?? 'pending';
      checkoutStatus = switch (status) {
        'paid' => '付款已核实，会员权益正在刷新。',
        'failed' => '订单未完成，可以重新发起购买。',
        'refunded' => '订单已退款，未发放新的会员权益。',
        _ => '仍在等待付款核验，请稍后再查询。',
      };
      if (status == 'paid') {
        _clearPendingOrder();
        await load();
      } else if (status == 'failed' || status == 'refunded') {
        _clearPendingOrder();
      }
    } on LearningFailure catch (failure) {
      if (!_isCurrent(accountId, requestGeneration)) return;
      error = failure.message;
    } catch (_) {
      if (!_isCurrent(accountId, requestGeneration)) return;
      error = '订单状态暂时无法读取，请稍后重试。';
    } finally {
      if (_isCurrent(accountId, requestGeneration)) {
        checkoutLoading = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  void showTrialInfo() {
    checkoutStatus = '试用会在第一条个人表达成功并由服务器保存后开始计时，共 7 天。';
    if (!_disposed) notifyListeners();
  }

  void _clearPendingOrder() {
    pendingOrderId = null;
    pendingClientRequestId = null;
  }

  bool _isCurrent(String? accountId, int generation) =>
      !_disposed &&
      accountId == gateway.userId &&
      generation == _accountGeneration;

  void _resetAccountScopedState() {
    summary = MembershipSummary.empty();
    loading = false;
    checked = false;
    error = null;
    checkoutLoading = false;
    checkoutStatus = null;
    _clearPendingOrder();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
