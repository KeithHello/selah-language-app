import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/admin_dashboard.dart';

void main() {
  test('parses summary and keeps estimated and vendor cost separate', () {
    final dashboard = AdminDashboardData.fromJson({
      'generatedAt': '2026-09-10T12:00:00.000Z',
      'summary': {
        'activeLearners': 128,
        'learningSessions': 486,
        'effectiveLearningMinutes': 2540,
        'featureUsage': [
          {'feature': 'listen_completed', 'count': 620},
        ],
        'dailyActivity': [
          {
            'date': '2026-09-08T00:00:00.000Z',
            'activeLearners': 68,
            'effectiveLearningMinutes': 440,
          },
        ],
        'api': {
          'businessRequests': 520,
          'reusedRequests': 34,
          'providerAttempts': 118,
          'knownEstimatedCostUsd': 8.42,
          'unknownUsageAttempts': 3,
          'providerRecordedCostUsd': 8.30,
          'byFeature': [
            {
              'feature': 'tts',
              'attempts': 50,
              'estimatedCostUsd': 6.0,
              'unknownAttempts': 2,
            },
          ],
        },
      },
      'attempts': [
        {
          'id': 'attempt-1',
          'feature': 'tts',
          'model': 'tts-1',
          'provider_status': 'unknown',
          'delivery_status': 'failed',
          'estimated_cost_usd': null,
          'usage_source': 'unknown',
        },
      ],
    });

    expect(dashboard.summary.activeLearners, 128);
    expect(dashboard.summary.learningSessions, 486);
    expect(dashboard.summary.effectiveDurationLabel, '42 小时 20 分');
    expect(dashboard.summary.api.knownEstimatedCostUsd, 8.42);
    expect(dashboard.summary.api.providerRecordedCostUsd, 8.30);
    expect(dashboard.summary.api.unknownUsageAttempts, 3);
    expect(dashboard.attempts.single.featureLabelTextValue, '语音合成');
    expect(dashboard.attempts.single.statusLabel, '结果未知');
  });

  test(
    'uses zero defaults and an explicit unknown state for missing fields',
    () {
      final summary = AdminSummary.fromJson({});
      expect(summary.activeLearners, 0);
      expect(summary.effectiveDurationLabel, '0 分钟');
      expect(summary.api.providerAttempts, 0);
    expect(
      AdminAttempt.fromJson({'feature': 'unknown'}).featureLabelTextValue,
      '其他',
    );
    },
  );
}
