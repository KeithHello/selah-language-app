import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/admin_membership.dart';

void main() {
  test('parses recent login time and provider usage attempts', () {
    final user = AdminUserItem.fromJson({
      'userId': 'user-1',
      'emailMasked': 'u***@example.com',
      'plan': 'pro',
      'status': 'active',
      'createdAt': '2026-09-24T00:00:00Z',
      'lastLoginAt': '2026-10-03T06:30:00Z',
    });

    expect(user.lastLoginAt, DateTime.utc(2026, 10, 3, 6, 30));

    final detail = AdminUserDetailData.fromJson({
      'userId': 'user-1',
      'periods': [],
      'orders': [],
      'auditLogs': [],
      'usageAttempts': [
        {
          'id': 'attempt-1',
          'feature': 'sentence',
          'model': 'gpt-4o-mini',
          'provider_status': 'succeeded',
          'delivery_status': 'succeeded',
          'item_count': 1,
          'input_characters': null,
          'duration_ms': null,
          'estimated_cost_usd': '0.0001234567',
          'usage_source': 'provider',
          'started_at': '2026-10-03T06:20:00Z',
        },
      ],
      'login': {'lastLoginAt': '2026-10-03T06:30:00Z'},
    });

    expect(detail.usageAttempts, hasLength(1));
    expect(detail.usageAttempts.single.featureLabel, '单句生成');
    expect(detail.usageAttempts.single.unitsLabel, '1 条');
    expect(detail.usageAttempts.single.estimatedCostUsd, 0.0001234567);
    expect(detail.login?.lastLoginAt, DateTime.utc(2026, 10, 3, 6, 30));
    final unavailableLogin = AdminLoginInfo.fromJson({'available': false});
    expect(unavailableLogin.lastLoginLabel, '暂时无法读取');
    expect(unavailableLogin.createdAtLabel, '暂时无法读取');
  });
}
