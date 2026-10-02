import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/update/update_check_service.dart';

void main() {
  group('normalizeVersion', () {
    test('strips leading v/V', () {
      expect(UpdateCheckService.normalizeVersion('v1.0.9'), '1.0.9');
      expect(UpdateCheckService.normalizeVersion('V2.3.0'), '2.3.0');
    });

    test('keeps plain versions', () {
      expect(UpdateCheckService.normalizeVersion('1.0.8'), '1.0.8');
      expect(UpdateCheckService.normalizeVersion('1.10.23'), '1.10.23');
    });

    test('trims pre-release suffix', () {
      expect(UpdateCheckService.normalizeVersion('v1.0.9-beta.1'), '1.0.9');
    });

    test('returns null for unparseable tags', () {
      expect(UpdateCheckService.normalizeVersion('release-2026'), isNull);
      expect(UpdateCheckService.normalizeVersion(''), isNull);
    });
  });

  group('isNewerVersion', () {
    test('detects newer versions', () {
      expect(UpdateCheckService.isNewerVersion('1.0.9', '1.0.8'), isTrue);
      expect(UpdateCheckService.isNewerVersion('1.1.0', '1.0.99'), isTrue);
      expect(UpdateCheckService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('same or older versions are not newer', () {
      expect(UpdateCheckService.isNewerVersion('1.0.8', '1.0.8'), isFalse);
      expect(UpdateCheckService.isNewerVersion('1.0.7', '1.0.8'), isFalse);
      expect(UpdateCheckService.isNewerVersion('1.0.0', '1.0'), isFalse);
    });

    test('handles differing segment counts', () {
      expect(UpdateCheckService.isNewerVersion('1.0.9', '1.0'), isTrue);
      expect(UpdateCheckService.isNewerVersion('1.1', '1.0.9'), isTrue);
      expect(UpdateCheckService.isNewerVersion('1.0', '1.0.1'), isFalse);
    });
  });
}
