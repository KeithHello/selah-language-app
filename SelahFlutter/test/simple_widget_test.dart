import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('静态页面可渲染', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('hello'))),
    );
    expect(find.text('hello'), findsOneWidget);
  });
}
