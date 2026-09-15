enum AdminAudienceDimension {
  learningGoal,
  englishLevel,
  ageGroup,
  lifeStage,
  gender,
  unknown,
}

AdminAudienceDimension _dimension(Object? value) => switch (value?.toString()) {
      'learningGoal' || 'learning_goal' => AdminAudienceDimension.learningGoal,
      'englishLevel' || 'english_level' => AdminAudienceDimension.englishLevel,
      'ageGroup' || 'age_group' => AdminAudienceDimension.ageGroup,
      'lifeStage' || 'life_stage' => AdminAudienceDimension.lifeStage,
      'gender' => AdminAudienceDimension.gender,
      _ => AdminAudienceDimension.unknown,
    };

class AdminAudienceGroup {
  const AdminAudienceGroup({
    required this.value,
    required this.label,
    required this.sampleSize,
    required this.active7d,
    required this.day7RetentionNumerator,
    required this.day7RetentionDenominator,
    required this.firstPurchase30dNumerator,
    required this.firstPurchase30dDenominator,
    required this.suppressed,
  });

  final String value;
  final String label;
  final int sampleSize;
  final int active7d;
  final int day7RetentionNumerator;
  final int day7RetentionDenominator;
  final int firstPurchase30dNumerator;
  final int firstPurchase30dDenominator;
  final bool suppressed;

  factory AdminAudienceGroup.fromJson(Map<String, dynamic> json) =>
      AdminAudienceGroup(
        value: _stringValue(json['value'] ?? json['group_value']),
        label: _stringValue(json['label'] ?? json['group_label']),
        sampleSize: _intValue(json['sampleSize'] ?? json['sample_size']),
        active7d: _intValue(json['active7d'] ?? json['active_7d']),
        day7RetentionNumerator: _intValue(
          json['day7RetentionNumerator'] ?? json['day7_retention_numerator'],
        ),
        day7RetentionDenominator: _intValue(
          json['day7RetentionDenominator'] ?? json['day7_retention_denominator'],
        ),
        firstPurchase30dNumerator: _intValue(
          json['firstPurchase30dNumerator'] ??
              json['first_purchase_30d_numerator'],
        ),
        firstPurchase30dDenominator: _intValue(
          json['firstPurchase30dDenominator'] ??
              json['first_purchase_30d_denominator'],
        ),
        suppressed: json['suppressed'] == true ||
            json['sampleSuppressed'] == true ||
            json['sample_suppressed'] == true,
      );
}

class AdminAudienceSummary {
  const AdminAudienceSummary({
    required this.dimension,
    required this.registeredCount,
    required this.profileCoveredCount,
    required this.unansweredCount,
    required this.refusalCount,
    required this.withdrawnCount,
    required this.groups,
    required this.dataStatus,
    this.start,
    this.end,
    this.generatedAt,
  });

  final AdminAudienceDimension dimension;
  final int registeredCount;
  final int profileCoveredCount;
  final int unansweredCount;
  final int refusalCount;
  final int withdrawnCount;
  final List<AdminAudienceGroup> groups;
  final String dataStatus;
  final DateTime? start;
  final DateTime? end;
  final DateTime? generatedAt;

  factory AdminAudienceSummary.fromJson(Map<String, dynamic> json) {
    final groups = _mapList(json['groups'])
        .map((item) => AdminAudienceGroup.fromJson(_objectMap(item)))
        .toList(growable: false);
    final dimension = _dimension(json['dimension']);
    final rawStatus = _stringValue(json['dataStatus'] ?? json['data_status']);
    return AdminAudienceSummary(
      dimension: dimension,
      registeredCount: _intValue(
        json['registeredCount'] ?? json['registered'] ?? json['registered_count'],
      ),
      profileCoveredCount: _intValue(
        json['profileCoveredCount'] ??
            json['profile_covered_count'] ??
            json['profileCovered'],
      ),
      unansweredCount: _intValue(
        json['unansweredCount'] ?? json['unanswered_count'],
      ),
      refusalCount: _intValue(json['refusalCount'] ?? json['refusal_count']),
      withdrawnCount: _intValue(
        json['withdrawnCount'] ?? json['withdrawn_count'],
      ),
      groups: groups,
      dataStatus: dimension == AdminAudienceDimension.unknown || rawStatus.isEmpty
          ? 'unavailable'
          : rawStatus,
      start: _date(json['start'] ?? json['startAt'] ?? json['start_at']),
      end: _date(json['end'] ?? json['endAt'] ?? json['end_at']),
      generatedAt: _date(json['generatedAt'] ?? json['generated_at']),
    );
  }
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

Map<String, dynamic> _objectMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _mapList(Object? value) => value is List ? value : const [];

String _stringValue(Object? value) => value is String ? value : '';

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
