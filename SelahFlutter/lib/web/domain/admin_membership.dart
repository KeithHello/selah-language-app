class AdminServiceControls {
  const AdminServiceControls({
    this.version = '2026-09-17-v1',
    this.membershipEnforcementEnabled = false,
    this.trialSignupsEnabled = false,
    this.membershipSalesEnabled = false,
    this.generationEnabled = true,
    this.configured = false,
    this.updatedAt,
  });

  final String version;
  final bool membershipEnforcementEnabled;
  final bool trialSignupsEnabled;
  final bool membershipSalesEnabled;
  final bool generationEnabled;
  final bool configured;
  final DateTime? updatedAt;

  factory AdminServiceControls.fromJson(Map<String, dynamic> json) {
    bool flag(String camel, String snake, bool fallback) => json[camel] is bool
        ? json[camel] as bool
        : json[snake] is bool
        ? json[snake] as bool
        : fallback;
    return AdminServiceControls(
      version: json['version']?.toString() ?? '2026-09-17-v1',
      membershipEnforcementEnabled: flag(
        'membershipEnforcementEnabled',
        'membership_enforcement_enabled',
        false,
      ),
      trialSignupsEnabled: flag(
        'trialSignupsEnabled',
        'trial_signups_enabled',
        false,
      ),
      membershipSalesEnabled: flag(
        'membershipSalesEnabled',
        'membership_sales_enabled',
        false,
      ),
      generationEnabled: flag('generationEnabled', 'generation_enabled', true),
      configured: json['configured'] == true,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class AdminUserItem {
  const AdminUserItem({
    required this.userId,
    required this.emailMasked,
    required this.plan,
    required this.status,
    this.expiresAt,
    this.serviceStatus = 'active',
    required this.createdAt,
    this.lastLoginAt,
  });

  final String userId;
  final String emailMasked;
  final String plan;
  final String status;
  final DateTime? expiresAt;
  final String serviceStatus;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  factory AdminUserItem.fromJson(Map<String, dynamic> json) => AdminUserItem(
    userId: json['userId']?.toString() ?? '',
    emailMasked: json['emailMasked']?.toString() ?? '',
    plan: json['plan']?.toString() ?? 'free',
    status: json['status']?.toString() ?? 'none',
    expiresAt: json['expiresAt'] != null
        ? DateTime.tryParse(json['expiresAt'].toString())
        : null,
    serviceStatus: json['serviceStatus']?.toString() ?? 'active',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    lastLoginAt: json['lastLoginAt'] == null
        ? null
        : DateTime.tryParse(json['lastLoginAt'].toString()),
  );
}

class AdminUsageAttempt {
  const AdminUsageAttempt({
    required this.id,
    required this.feature,
    required this.model,
    required this.providerStatus,
    required this.deliveryStatus,
    required this.usageSource,
    this.itemCount = 1,
    this.inputCharacters,
    this.durationMs,
    this.estimatedCostUsd,
    this.startedAt,
  });

  final String id;
  final String feature;
  final String model;
  final String providerStatus;
  final String deliveryStatus;
  final String usageSource;
  final int itemCount;
  final int? inputCharacters;
  final int? durationMs;
  final num? estimatedCostUsd;
  final DateTime? startedAt;

  factory AdminUsageAttempt.fromJson(Map<String, dynamic> json) =>
      AdminUsageAttempt(
        id: json['id']?.toString() ?? '',
        feature: json['feature']?.toString() ?? 'unknown',
        model: json['model']?.toString() ?? '',
        providerStatus: json['provider_status']?.toString() ?? 'unknown',
        deliveryStatus: json['delivery_status']?.toString() ?? 'pending',
        usageSource: json['usage_source']?.toString() ?? 'unknown',
        itemCount: json['item_count'] is num
            ? (json['item_count'] as num).toInt()
            : int.tryParse(json['item_count']?.toString() ?? '') ?? 1,
        inputCharacters: _optionalInt(json['input_characters']),
        durationMs: _optionalInt(json['duration_ms']),
        estimatedCostUsd: json['estimated_cost_usd'] == null
            ? null
            : num.tryParse(json['estimated_cost_usd'].toString()),
        startedAt: json['started_at'] == null
            ? null
            : DateTime.tryParse(json['started_at'].toString()),
      );

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String get featureLabel => switch (feature) {
    'sentence' => '单句生成',
    'batch' => '批量生成',
    'preparation' => '长文整理',
    'transcription' => '录音转写',
    'tts' => 'AI 配音',
    _ => '其他用量',
  };

  String get unitsLabel => switch (feature) {
    'sentence' || 'batch' => '$itemCount 条',
    'preparation' => '$itemCount 次',
    'tts' => '${inputCharacters ?? 0} 字元',
    'transcription' => _durationLabel,
    _ => '$itemCount 次',
  };

  String get _durationLabel {
    final duration = durationMs ?? 0;
    final minutes = duration ~/ 60000;
    final seconds = (duration % 60000) ~/ 1000;
    if (minutes == 0) return '$seconds 秒';
    if (seconds == 0) return '$minutes 分';
    return '$minutes 分 $seconds 秒';
  }

  String get statusLabel => switch (providerStatus) {
    'succeeded' => '成功',
    'failed' => '失败',
    'unknown' => '结果未知',
    'started' => '进行中',
    _ => '其他',
  };

  String get deliveryStatusLabel => switch (deliveryStatus) {
    'succeeded' => '交付成功',
    'failed' => '交付失败',
    'pending' => '交付处理中',
    _ => '交付状态未知',
  };

  String get usageSourceLabel => switch (usageSource) {
    'provider' => '供应商用量',
    'request_estimate' => '按请求估算',
    _ => '用量来源未知',
  };
}

class AdminLoginInfo {
  const AdminLoginInfo({
    this.lastLoginAt,
    this.createdAt,
    this.available = true,
  });

  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final bool available;

  String get lastLoginLabel {
    if (!available) return '暂时无法读取';
    final value = lastLoginAt;
    return value == null
        ? '未记录'
        : value.toLocal().toString().substring(0, 16);
  }

  String get createdAtLabel {
    if (!available) return '暂时无法读取';
    final value = createdAt;
    return value == null
        ? '未记录'
        : value.toLocal().toString().substring(0, 10);
  }

  factory AdminLoginInfo.fromJson(Map<String, dynamic> json) =>
      AdminLoginInfo(
        available: json['available'] != false,
        lastLoginAt: json['lastLoginAt'] == null
            ? null
            : DateTime.tryParse(json['lastLoginAt'].toString()),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'].toString()),
      );
}

class AdminUserDetailData {
  const AdminUserDetailData({
    required this.userId,
    required this.periods,
    required this.orders,
    required this.auditLogs,
    this.usageAttempts = const [],
    this.login,
  });

  final String userId;
  final List<Map<String, dynamic>> periods;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> auditLogs;
  final List<AdminUsageAttempt> usageAttempts;
  final AdminLoginInfo? login;

  factory AdminUserDetailData.fromJson(Map<String, dynamic> json) =>
      AdminUserDetailData(
        userId: json['userId']?.toString() ?? '',
        periods:
            (json['periods'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        orders:
            (json['orders'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        auditLogs:
            (json['auditLogs'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        usageAttempts:
            (json['usageAttempts'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((e) => AdminUsageAttempt.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        login: json['login'] is Map
            ? AdminLoginInfo.fromJson(
                Map<String, dynamic>.from(json['login'] as Map),
              )
            : null,
      );
}
