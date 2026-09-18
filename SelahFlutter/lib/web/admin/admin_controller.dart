import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/learning_gateway.dart';
import '../domain/admin_audience.dart';
import '../domain/admin_dashboard.dart';
import '../domain/admin_membership.dart';
import '../domain/learning_models.dart';

class AdminController extends ChangeNotifier {
  AdminController({required this.gateway});

  final LearningGateway gateway;
  AdminDashboardData? data;
  AdminServiceControls controls = const AdminServiceControls();
  List<AdminUserItem> users = const [];
  int? usersNextCursor;
  bool loading = false;
  bool checked = false;
  bool controlsLoading = false;
  bool usersLoading = false;
  String? error;
  String? controlsError;
  String? usersError;
  AdminAudienceSummary? audience;
  bool audienceLoading = false;
  String? audienceError;
  AdminAudienceDimension audienceDimension =
      AdminAudienceDimension.learningGoal;
  String userSearch = '';
  DateTimeRangePreset rangePreset = DateTimeRangePreset.last7Days;

  bool get hasData => data != null;

  Future<void> load({
    DateTime? start,
    DateTime? end,
    String? feature,
    String? status,
  }) async {
    if (!gateway.configured || gateway.userId == null) {
      loading = false;
      checked = true;
      data = null;
      error = '请先登录管理员账号。';
      notifyListeners();
      return;
    }
    final now = DateTime.now().toUtc();
    final resolvedEnd = end ?? now;
    final resolvedStart = start ?? resolvedEnd.subtract(rangePreset.duration);
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await gateway.invoke('admin-summary', {
        'start': resolvedStart.toIso8601String(),
        'end': resolvedEnd.toIso8601String(),
        'environment': 'production',
        ...?feature != null ? {'feature': feature} : null,
        ...?status != null ? {'status': status} : null,
        'limit': 100,
      });
      data = AdminDashboardData.fromJson(response);
      checked = true;
    } on LearningFailure catch (failure) {
      checked = true;
      data = null;
      error = failure.code == 'unauthorized'
          ? '当前账号没有管理台访问权限。'
          : '管理数据暂时无法读取，请稍后重试。';
    } catch (_) {
      checked = true;
      data = null;
      error = '管理数据暂时无法读取，请稍后重试。';
    } finally {
      loading = false;
      notifyListeners();
    }
    // These panels are independent of the usage summary. A read failure in
    // one panel stays visible there and does not erase already loaded data.
    await Future.wait<void>([loadControls(), loadUsers(search: userSearch)]);
  }

  Future<void> setRange(DateTimeRangePreset preset) async {
    rangePreset = preset;
    notifyListeners();
    await load();
  }

  Future<void> loadControls() async {
    if (!gateway.configured || gateway.userId == null) return;
    controlsLoading = true;
    controlsError = null;
    notifyListeners();
    try {
      final response = await gateway.invoke(
        'admin-service-controls',
        {},
        get: true,
      );
      controls = AdminServiceControls.fromJson(response);
    } on LearningFailure catch (failure) {
      controlsError = failure.code == 'admin_write_forbidden'
          ? '当前账号只能查看管理数据。'
          : failure.message;
    } catch (_) {
      controlsError = '服务开关暂时无法读取。';
    } finally {
      controlsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateControls({
    bool? membershipEnforcementEnabled,
    bool? trialSignupsEnabled,
    bool? membershipSalesEnabled,
    bool? generationEnabled,
    bool? anonymousTestModeEnabled,
    required String reason,
  }) async {
    if (controlsLoading) return false;
    controlsLoading = true;
    controlsError = null;
    notifyListeners();
    try {
      final response = await gateway.invoke('admin-service-controls', {
        'action': 'update',
        'expectedVersion': controls.version,
        'clientRequestId': newId(),
        'reason': reason,
        ...?membershipEnforcementEnabled != null
            ? {'membershipEnforcementEnabled': membershipEnforcementEnabled}
            : null,
        ...?trialSignupsEnabled != null
            ? {'trialSignupsEnabled': trialSignupsEnabled}
            : null,
        ...?membershipSalesEnabled != null
            ? {'membershipSalesEnabled': membershipSalesEnabled}
            : null,
        ...?generationEnabled != null
            ? {'generationEnabled': generationEnabled}
            : null,
        ...?anonymousTestModeEnabled != null
            ? {'anonymousTestModeEnabled': anonymousTestModeEnabled}
            : null,
      });
      controls = AdminServiceControls.fromJson(response);
      return true;
    } on LearningFailure catch (failure) {
      controlsError = failure.message;
    } catch (_) {
      controlsError = '服务开关暂时无法更新。';
    } finally {
      controlsLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Maps one product mode to the existing service-control flags.
  ///
  /// Test mode still keeps generation enabled so it cannot accidentally look
  /// active while all cloud creation paths are disabled.
  Future<bool> setProductMode(ProductMode mode, {required String reason}) {
    final test = mode == ProductMode.test;
    return updateControls(
      membershipEnforcementEnabled: !test,
      generationEnabled: true,
      anonymousTestModeEnabled: test,
      reason: reason,
    );
  }

  Future<void> loadUsers({String? search, int? cursor}) async {
    if (!gateway.configured || gateway.userId == null) return;
    final resolvedSearch = search ?? userSearch;
    userSearch = resolvedSearch;
    usersLoading = true;
    usersError = null;
    notifyListeners();
    try {
      final response = await gateway.invoke('admin-users', {
        'search': resolvedSearch,
        'limit': 50,
        ...?cursor != null ? {'cursor': cursor} : null,
      });
      final list = response['users'];
      users = list is List
          ? list
                .whereType<Map>()
                .map(
                  (item) =>
                      AdminUserItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [];
      final next = response['nextCursor'];
      usersNextCursor = next is num ? next.toInt() : null;
    } on LearningFailure catch (failure) {
      usersError = failure.message;
    } catch (_) {
      usersError = '用户列表暂时无法读取。';
    } finally {
      usersLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAudience({AdminAudienceDimension? dimension}) async {
    if (!gateway.configured || gateway.userId == null) return;
    audienceDimension = dimension ?? audienceDimension;
    final now = DateTime.now().toUtc();
    final start = now.subtract(rangePreset.duration);
    audienceLoading = true;
    audienceError = null;
    notifyListeners();
    try {
      final response = await gateway.invoke('admin-summary', {
        'start': start.toIso8601String(),
        'end': now.toIso8601String(),
        'environment': 'production',
        'view': 'audience',
        'dimension': _audienceDimensionName(audienceDimension),
      });
      final raw = response['audience'];
      if (raw is! Map) throw const LearningFailure('管理画像数据格式无效。');
      audience = AdminAudienceSummary.fromJson(Map<String, dynamic>.from(raw));
    } on LearningFailure catch (failure) {
      audienceError = failure.code == 'admin_forbidden'
          ? '当前账号没有管理台访问权限。'
          : '用户画像摘要暂时无法读取，请稍后重试。';
    } catch (_) {
      audienceError = '用户画像摘要暂时无法读取，请稍后重试。';
    } finally {
      audienceLoading = false;
      notifyListeners();
    }
  }
}

String _audienceDimensionName(AdminAudienceDimension dimension) =>
    switch (dimension) {
      AdminAudienceDimension.learningGoal => 'learningGoal',
      AdminAudienceDimension.englishLevel => 'englishLevel',
      AdminAudienceDimension.ageGroup => 'ageGroup',
      AdminAudienceDimension.lifeStage => 'lifeStage',
      AdminAudienceDimension.gender => 'gender',
      AdminAudienceDimension.unknown => 'learningGoal',
    };

enum DateTimeRangePreset {
  today('今天', Duration(days: 1)),
  last7Days('最近 7 天', Duration(days: 7)),
  last30Days('最近 30 天', Duration(days: 30));

  const DateTimeRangePreset(this.label, this.duration);
  final String label;
  final Duration duration;
}
