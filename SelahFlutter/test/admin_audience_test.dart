import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/admin_audience.dart';

void main() {
  test('parses audience denominators and sample suppression explicitly', () {
    final data = AdminAudienceSummary.fromJson({
      'dimension': 'ageGroup',
      'registeredCount': 20,
      'profileCoveredCount': 12,
      'unansweredCount': 5,
      'refusalCount': 2,
      'withdrawnCount': 1,
      'dataStatus': 'ready',
      'groups': [
        {
          'value': 'age_25_34',
          'label': '25～34 岁',
          'sampleSize': 4,
          'active7d': 3,
          'day7RetentionNumerator': 1,
          'day7RetentionDenominator': 4,
          'firstPurchase30dNumerator': 0,
          'firstPurchase30dDenominator': 4,
          'suppressed': true,
        },
      ],
    });

    expect(data.dimension, AdminAudienceDimension.ageGroup);
    expect(data.registeredCount, 20);
    expect(data.profileCoveredCount, 12);
    expect(data.groups.single.suppressed, isTrue);
    expect(data.groups.single.day7RetentionDenominator, 4);
  });

  test('unknown dimension becomes unavailable instead of an invented segment', () {
    final data = AdminAudienceSummary.fromJson({
      'dimension': 'email',
      'registeredCount': 2,
      'groups': [],
    });
    expect(data.dimension, AdminAudienceDimension.unknown);
    expect(data.dataStatus, 'unavailable');
  });
}
