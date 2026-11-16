import 'package:flutter_test/flutter_test.dart';
import 'package:offline_ai/l10n/app_strings.dart';

void main() {
  test('all supported locales resolve core chat labels', () {
    for (final locale in ['en', 'tr', 'ru']) {
      final strings = AppStrings(locale);
      expect(strings['new'], isNotEmpty);
      expect(strings['model'], isNotEmpty);
      expect(strings['deleteConfirm'], isNotEmpty);
      expect(strings['fileMissing'], isNotEmpty);
    }
  });
}

