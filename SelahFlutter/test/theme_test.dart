import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_theme.dart';

void main() {
  testWidgets('主题可构建且品牌色正确', (tester) async {
    final theme = SelahTheme.light();
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFBF8F4));
    expect(theme.colorScheme.primary, const Color(0xFFE06B54));
    expect(theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), const Color(0xFFE06B54));
  });
}
