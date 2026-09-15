import 'admin_audience.dart';

class AdminDashboardData {
  const AdminDashboardData({
    required this.summary,
    required this.attempts,
    required this.generatedAt,
    this.audience,
  });

  final AdminSummary summary;
  final List<AdminAttempt> attempts;
  final DateTime? generatedAt;
  final AdminAudienceSummary? audience;

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      summary: AdminSummary.fromJson(objectMap(json['summary'])),
      attempts: mapList(
        json['attempts'],
      ).map((item) => AdminAttempt.fromJson(objectMap(item))).toList(),
      generatedAt: DateTime.tryParse(stringValue(json['generatedAt'] ?? '')),
      audience: json['audience'] is Map
          ? AdminAudienceSummary.fromJson(objectMap(json['audience']))
          : null,
    );
  }
}

class AdminSummary {
  const AdminSummary({
    required this.activeLearners,
    required this.learningSessions,
    required this.effectiveLearningMinutes,
    required this.featureUsage,
    required this.dailyActivity,
    required this.api,
  });

  final int activeLearners;
  final int learningSessions;
  final num effectiveLearningMinutes;
  final List<AdminFeatureCount> featureUsage;
  final List<AdminDailyActivity> dailyActivity;
  final AdminApiSummary api;

  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    return AdminSummary(
      activeLearners: intValue(json['activeLearners']),
      learningSessions: intValue(json['learningSessions']),
      effectiveLearningMinutes: numValue(json['effectiveLearningMinutes']),
      featureUsage: mapList(
        json['featureUsage'],
      ).map((item) => AdminFeatureCount.fromJson(objectMap(item))).toList(),
      dailyActivity: mapList(
        json['dailyActivity'],
      ).map((item) => AdminDailyActivity.fromJson(objectMap(item))).toList(),
      api: AdminApiSummary.fromJson(objectMap(json['api'])),
    );
  }

  String get effectiveDurationLabel {
    final total = effectiveLearningMinutes.round();
    final hours = total ~/ 60;
    final minutes = total % 60;
    if (hours == 0) return '$minutes 分钟';
    if (minutes == 0) return '$hours 小时';
    return '$hours 小时 $minutes 分';
  }
}

class AdminApiSummary {
  const AdminApiSummary({
    required this.businessRequests,
    required this.reusedRequests,
    required this.providerAttempts,
    required this.knownEstimatedCostUsd,
    required this.providerRecordedCostUsd,
    required this.unknownUsageAttempts,
    required this.byFeature,
  });

  final int businessRequests;
  final int reusedRequests;
  final int providerAttempts;
  final num knownEstimatedCostUsd;
  final num providerRecordedCostUsd;
  final int unknownUsageAttempts;
  final List<AdminFeatureCost> byFeature;

  factory AdminApiSummary.fromJson(Map<String, dynamic> json) {
    return AdminApiSummary(
      businessRequests: intValue(json['businessRequests']),
      reusedRequests: intValue(json['reusedRequests']),
      providerAttempts: intValue(json['providerAttempts']),
      knownEstimatedCostUsd: numValue(json['knownEstimatedCostUsd']),
      providerRecordedCostUsd: numValue(json['providerRecordedCostUsd']),
      unknownUsageAttempts: intValue(json['unknownUsageAttempts']),
      byFeature: mapList(
        json['byFeature'],
      ).map((item) => AdminFeatureCost.fromJson(objectMap(item))).toList(),
    );
  }
}

class AdminFeatureCount {
  const AdminFeatureCount({required this.feature, required this.count});
  final String feature;
  final int count;

  factory AdminFeatureCount.fromJson(Map<String, dynamic> json) =>
      AdminFeatureCount(
        feature: stringValue(json['feature']),
        count: intValue(json['count']),
      );

  String get label => featureLabel(feature);
}

class AdminFeatureCost {
  const AdminFeatureCost({
    required this.feature,
    required this.attempts,
    required this.estimatedCostUsd,
    required this.unknownAttempts,
  });

  final String feature;
  final int attempts;
  final num estimatedCostUsd;
  final int unknownAttempts;

  factory AdminFeatureCost.fromJson(Map<String, dynamic> json) =>
      AdminFeatureCost(
        feature: stringValue(json['feature']),
        attempts: intValue(json['attempts']),
        estimatedCostUsd: numValue(json['estimatedCostUsd']),
        unknownAttempts: intValue(json['unknownAttempts']),
      );

  String get featureLabelText => featureLabel(feature);
}

class AdminDailyActivity {
  const AdminDailyActivity({
    required this.date,
    required this.activeLearners,
    required this.effectiveLearningMinutes,
  });

  final DateTime? date;
  final int activeLearners;
  final num effectiveLearningMinutes;

  factory AdminDailyActivity.fromJson(Map<String, dynamic> json) =>
      AdminDailyActivity(
        date: DateTime.tryParse(stringValue(json['date'])),
        activeLearners: intValue(json['activeLearners']),
        effectiveLearningMinutes: numValue(json['effectiveLearningMinutes']),
      );
}

class AdminAttempt {
  const AdminAttempt({
    required this.id,
    required this.feature,
    required this.model,
    required this.providerStatus,
    required this.deliveryStatus,
    required this.estimatedCostUsd,
    required this.usageSource,
    required this.startedAt,
  });

  final String id;
  final String feature;
  final String model;
  final String providerStatus;
  final String deliveryStatus;
  final num? estimatedCostUsd;
  final String usageSource;
  final DateTime? startedAt;

  factory AdminAttempt.fromJson(Map<String, dynamic> json) => AdminAttempt(
    id: stringValue(json['id']),
    feature: stringValue(json['feature']),
    model: stringValue(json['model']),
    providerStatus: stringValue(json['provider_status']),
    deliveryStatus: stringValue(json['delivery_status']),
    estimatedCostUsd: json['estimated_cost_usd'] == null
        ? null
        : num.tryParse(stringValue(json['estimated_cost_usd'])),
    usageSource: stringValue(json['usage_source']),
    startedAt: DateTime.tryParse(stringValue(json['started_at'])),
  );

  String get featureLabelTextValue => featureLabel(feature);

  String get statusLabel => switch (providerStatus) {
    'succeeded' => '成功',
    'failed' => '失败',
    'unknown' => '结果未知',
    'started' => '进行中',
    _ => '其他',
  };
}

String featureLabel(String feature) => switch (feature) {
  'transcription' => '转写',
  'sentence' => '单句生成',
  'preparation' => '长文本整理',
  'batch' => '批量生成',
  'tts' => '语音合成',
  'listen_completed' => '聆听',
  'practice_rated' => '开口练习',
  'preview_completed' => '预览',
  'sentence_created' => '生成句子',
  _ => '其他',
};

Map<String, dynamic> objectMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> mapList(Object? value) => value is List ? value : const [];

String stringValue(Object? value) => value is String ? value : '';

int intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num numValue(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
