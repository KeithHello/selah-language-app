import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/membership_quota_format.dart';

void main() {
  test('characters use wan only when the remainder stays exact', () {
    expect(formatQuotaValue(90000, QuotaUnit.characters, 'zh-Hans'), '9 万字符');
    expect(formatQuotaValue(42000, QuotaUnit.characters, 'zh-Hans'), '4.2 万字符');
    expect(
      formatQuotaValue(42150, QuotaUnit.characters, 'zh-Hans'),
      '42150 字符',
    );
    expect(formatQuotaValue(3000, QuotaUnit.characters, 'zh-Hant'), '3000 字元');
  });

  test('transcription minutes floor to one decimal', () {
    expect(
      formatQuotaValue(300000, QuotaUnit.transcriptionMs, 'zh-Hans'),
      '5 分钟',
    );
    expect(
      formatQuotaValue(5766000, QuotaUnit.transcriptionMs, 'zh-Hans'),
      '96.1 分钟',
    );
    expect(formatQuotaValue(59999, QuotaUnit.transcriptionMs, 'ja'), '0.9 分');
  });
}
