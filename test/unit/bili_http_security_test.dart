import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/services/api/bili_http_client.dart';
import 'package:mobili/services/api/bili_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiliHttpClient & Security Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('BiliHttpClient single-flight init: concurrent calls share the same future', () async {
      final client = BiliHttpClient();
      final future1 = client.init();
      final future2 = client.init();
      final future3 = client.init();

      expect(identical(future1, future2), isTrue);
      expect(identical(future2, future3), isTrue);

      await Future.wait([future1, future2, future3]);
      // After initialization, subsequent init() immediately returns
      await client.init();
    });

    test('BiliHttpClient cookie management and user login state', () async {
      final client = BiliHttpClient();

      // Initially not logged in
      await client.clearUserCookies();
      expect(client.isLoggedIn, isFalse);
      expect(client.sessData, isNull);

      // Save user session cookies
      await client.saveCookies({
        'buvid3': 'buvid_test_123',
        'SESSDATA': 'sessdata_secret_abc',
        'bili_jct': 'csrf_token_xyz',
        'DedeUserID': '10086',
      });

      expect(client.isLoggedIn, isTrue);
      expect(client.sessData, equals('sessdata_secret_abc'));
      expect(client.biliJct, equals('csrf_token_xyz'));
      expect(client.dedeUserId, equals('10086'));
      expect(client.cookies['buvid3'], equals('buvid_test_123'));

      // Logout clears user cookies but preserves device buvid
      await client.clearUserCookies();
      expect(client.isLoggedIn, isFalse);
      expect(client.sessData, isNull);
      expect(client.biliJct, isNull);
      expect(client.dedeUserId, isNull);
      expect(client.cookies['buvid3'], equals('buvid_test_123'));
    });

    test('BiliSecurityService WBI special characters sanitization', () {
      final security = BiliSecurityService();

      // Parameters with ! ' ( ) *
      final dirtyParams = {
        'keyword': "Hello!World's(Test)*Cool",
        'order': 'totalrank',
      };

      final signed = security.signWbi(dirtyParams);

      expect(signed.containsKey('w_rid'), isTrue);
      expect(signed.containsKey('wts'), isTrue);
      expect(signed['order'], equals('totalrank'));
      expect(signed['keyword'], equals("Hello!World's(Test)*Cool"));
    });

    test('BiliSecurityService WBI key expiration check', () {
      final security = BiliSecurityService();

      // Before updating keys: invalid
      expect(security.areWbiKeysValid(), isFalse);

      // Update keys with valid URLs
      security.updateWbiKeys(
        'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png',
        'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png',
      );

      expect(security.areWbiKeysValid(), isTrue);
    });
  });
}
