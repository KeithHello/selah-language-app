import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/learning_gateway.dart';
import '../domain/admin_dashboard.dart';

class AdminController extends ChangeNotifier {
  AdminController({required this.gateway});

  final LearningGateway gateway;
  AdminDashboardData? data;
  bool loading = false;
  bool checked = false;
  String? error;
  DateTimeRangePreset rangePreset = DateTimeRangePreset.last7Days;

  bool get hasData => data != null;

  Future<void> load({
    DateTime? start,
    DateTime? end,
    String? feature,
    String? status,
  }) async {
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
        if (feature != null) 'feature': feature,
        if (status != null) 'status': status,
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
  }

  Future<void> setRange(DateTimeRangePreset preset) async {
    rangePreset = preset;
    notifyListeners();
    await load();
  }
}

enum DateTimeRangePreset {
  today('今天', Duration(days: 1)),
  last7Days('最近 7 天', Duration(days: 7)),
  last30Days('最近 30 天', Duration(days: 30));

  const DateTimeRangePreset(this.label, this.duration);
  final String label;
  final Duration duration;
}
