enum QuotaUnit { sentences, characters, transcriptionMs, preparations }

String formatQuotaValue(int value, QuotaUnit unit, String locale) {
  final normalized = locale.toLowerCase();
  final traditional = normalized.startsWith('zh-hant');
  final japanese = normalized.startsWith('ja');
  final label = switch (unit) {
    QuotaUnit.sentences =>
      japanese
          ? '文'
          : traditional
          ? '條'
          : '条',
    QuotaUnit.characters =>
      japanese
          ? '文字'
          : traditional
          ? '字元'
          : '字符',
    QuotaUnit.transcriptionMs =>
      japanese
          ? '分'
          : traditional
          ? '分鐘'
          : '分钟',
    QuotaUnit.preparations => japanese ? '回' : '次',
  };
  final amount = switch (unit) {
    QuotaUnit.characters => _formatCharacters(value),
    QuotaUnit.transcriptionMs => _formatTranscriptionMinutes(value),
    QuotaUnit.sentences || QuotaUnit.preparations => value.toString(),
  };
  final separator =
      unit == QuotaUnit.characters && value >= 10000 && value % 100 == 0
      ? ''
      : ' ';
  return '$amount$separator$label';
}

String _formatCharacters(int value) {
  if (value < 10000 || value % 100 != 0) return value.toString();
  return '${(value / 10000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} 万';
}

String _formatTranscriptionMinutes(int value) {
  final tenths = value ~/ 6000;
  if (tenths % 10 == 0) return (tenths ~/ 10).toString();
  return '${tenths ~/ 10}.${tenths % 10}';
}
