import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobili/models/dynamic_model.dart';
import 'package:mobili/models/user_model.dart';
import 'package:mobili/providers/auth_provider.dart';
import 'package:mobili/providers/listen_video_provider.dart';
import 'package:mobili/widgets/dynamic_card.dart';
import 'package:mobili/widgets/image_viewer.dart';
import 'package:mobili/widgets/network_image_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Interaction and Performance Optimization Tests', () {
    test('FavFolder model parses favState and isFav getter correctly', () {
      final jsonWithFav = {
        'id': 12345,
        'fid': 67890,
        'mid': 11111,
        'title': '我的默认收藏夹',
        'media_count': 42,
        'fav_state': 1,
      };

      final folder1 = FavFolder.fromJson(jsonWithFav);
      expect(folder1.id, equals(12345));
      expect(folder1.title, equals('我的默认收藏夹'));
      expect(folder1.mediaCount, equals(42));
      expect(folder1.favState, equals(1));
      expect(folder1.isFav, isTrue);

      final jsonWithoutFav = {
        'id': 54321,
        'fid': 9876,
        'mid': 11111,
        'title': '音乐收藏',
        'media_count': 10,
        'fav_state': 0,
      };

      final folder2 = FavFolder.fromJson(jsonWithoutFav);
      expect(folder2.isFav, isFalse);

      final copied = folder2.copyWith(favState: 1);
      expect(copied.isFav, isTrue);
      expect(copied.title, equals('音乐收藏'));
    });

    testWidgets('DynamicCard image tap opens ImageViewer fullscreen overlay', (tester) async {
      final item = DynamicItem(
        id: '99887766',
        type: 'DYNAMIC_TYPE_DRAW',
        author: DynamicAuthor(
          mid: 12345,
          name: '画师小王',
          face: 'https://i0.hdslb.com/bfs/face/avatar.jpg',
          pubTime: '1小时前',
          pubAction: '投稿了动态',
        ),
        stat: DynamicStat(
          commentCount: 15,
          likeCount: 99,
          isLiked: false,
        ),
        text: '今日作品发布',
        pictures: [
          DynamicPicture(
            url: 'https://i0.hdslb.com/bfs/draw/sample1.jpg',
            width: 1080,
            height: 1920,
          ),
          DynamicPicture(
            url: 'https://i0.hdslb.com/bfs/draw/sample2.jpg',
            width: 1080,
            height: 1080,
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ListenVideoProvider>(create: (_) => ListenVideoProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DynamicCard(item: item),
            ),
          ),
        ),
      );

      expect(find.text('今日作品发布'), findsOneWidget);
      expect(find.byType(NetworkImageView), findsWidgets);

      // Tap on one of the multi-images (last NetworkImageView)
      await tester.tap(find.byType(NetworkImageView).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that ImageViewer is pushed to Navigator
      expect(find.byType(ImageViewer), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
    });
  });
}
