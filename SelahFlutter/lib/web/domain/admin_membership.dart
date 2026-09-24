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
  });

  final String userId;
  final String emailMasked;
  final String plan;
  final String status;
  final DateTime? expiresAt;
  final String serviceStatus;
  final DateTime createdAt;

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
  );
}

class AdminUserDetailData {
  const AdminUserDetailData({
    required this.userId,
    required this.periods,
    required this.orders,
    required this.auditLogs,
  });

  final String userId;
  final List<Map<String, dynamic>> periods;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> auditLogs;

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
      );
}
