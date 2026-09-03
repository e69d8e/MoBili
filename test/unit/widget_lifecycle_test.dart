import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobili/models/comment_model.dart';
import 'package:mobili/models/dynamic_model.dart';
import 'package:mobili/providers/auth_provider.dart';
import 'package:mobili/widgets/comment_item_widget.dart';
import 'package:mobili/widgets/dynamic_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Widget Lifecycle & Recycling Synchronization Tests', () {
    testWidgets('DynamicCard didUpdateWidget updates like state on item change', (tester) async {
      final itemInitial = DynamicItem(
        id: 'dyn_001',
        type: 'DYNAMIC_TYPE_WORD',
        author: DynamicAuthor(
          mid: 1001,
          name: '作者A',
          face: '',
          pubTime: '刚刚',
          pubAction: '发表动态',
        ),
        text: '动态初始内容',
        stat: DynamicStat(
          likeCount: 10,
          isLiked: false,
        ),
      );

      final itemUpdated = DynamicItem(
        id: 'dyn_002',
        type: 'DYNAMIC_TYPE_WORD',
        author: DynamicAuthor(
          mid: 1002,
          name: '作者B',
          face: '',
          pubTime: '10分钟前',
          pubAction: '发表动态',
        ),
        text: '动态更新内容',
        stat: DynamicStat(
          likeCount: 42,
          isLiked: true,
        ),
      );

      final authProvider = AuthProvider();

      // Initial pump
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: authProvider,
            child: Scaffold(
              body: DynamicCard(item: itemInitial),
            ),
          ),
        ),
      );

      expect(find.text('动态初始内容'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Pump updated widget (simulating ListView element recycling)
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: authProvider,
            child: Scaffold(
              body: DynamicCard(item: itemUpdated),
            ),
          ),
        ),
      );

      expect(find.text('动态更新内容'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('CommentItemWidget didUpdateWidget updates like state on comment reuse', (tester) async {
      final comment1 = CommentItem(
        rpid: 101,
        oid: 1000,
        mid: 501,
        root: 0,
        parent: 0,
        count: 0,
        rcount: 0,
        like: 5,
        ctime: 1700000000,
        message: '第一条评论',
        member: CommentMember(mid: 501, uname: '用户一', avatar: '', level: 2),
        isLiked: false,
      );

      final comment2 = CommentItem(
        rpid: 102,
        oid: 1000,
        mid: 502,
        root: 0,
        parent: 0,
        count: 0,
        rcount: 0,
        like: 99,
        ctime: 1700000100,
        message: '第二条评论',
        member: CommentMember(mid: 502, uname: '用户二', avatar: '', level: 5),
        isLiked: true,
      );

      // Initial pump
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentItemWidget(comment: comment1),
          ),
        ),
      );

      expect(find.text('第一条评论'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Re-pump with comment2
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentItemWidget(comment: comment2),
          ),
        ),
      );

      expect(find.text('第二条评论'), findsOneWidget);
      expect(find.text('99'), findsOneWidget);
    });
  });
}
