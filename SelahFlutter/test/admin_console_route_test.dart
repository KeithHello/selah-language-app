import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/admin/admin_console_route.dart';

void main() {
  test('recognizes the hidden console fragment and ignores the legacy route', () {
    final uri = Uri.parse('https://selah.example/#$adminConsolePath/login');

    expect(isAdminConsoleUri(uri), isTrue);
    expect(
      isAdminConsoleUri(Uri.parse('https://selah.example/#/admin')),
      isFalse,
    );
    expect(
      isAdminConsoleUri(Uri.parse('https://selah.example/')),
      isFalse,
    );
  });
}
