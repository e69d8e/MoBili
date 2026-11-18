import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/user_model.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/screens/video/widgets/video_favorite_folder_sheet.dart';
import 'package:mobili/screens/video/widgets/video_part_grid.dart';

FavFolder _folder(int id, {int favState = 0, String? title}) {
  return FavFolder(
    id: id,
    fid: id,
    mid: 1,
    title: title ?? '收藏夹$id',
    cover: '',
    mediaCount: 0,
    viewCount: 0,
    favState: favState,
  );
}

VideoPage _page(int index, {int duration = 300}) {
  return VideoPage(
    cid: 1000 + index,
    page: index + 1,
    from: 'vupload',
    part: '第 $index 集',
    duration: duration,
  );
}

void main() {
  group('一键收藏的提交计划', () {
    test('没有可用收藏夹时不发请求，交由调用方回退', () {
      final plan = VideoFavoriteFolderSheet.planQuickToggle(
        const [],
        targetFav: true,
      );
      expect(plan.hasChange, isFalse);
      expect(plan.alreadySatisfied, isFalse);
    });

    test('首次收藏投到列表首个（默认）收藏夹', () {
      final plan = VideoFavoriteFolderSheet.planQuickToggle([
        _folder(11),
        _folder(22),
      ], targetFav: true);
      expect(plan.addIds, equals([11]));
      expect(plan.delIds, isEmpty);
      expect(plan.alreadySatisfied, isFalse);
      expect(plan.hasChange, isTrue);
    });

    test('已在收藏夹中则视为已完成，不重复添加', () {
      final plan = VideoFavoriteFolderSheet.planQuickToggle([
        _folder(11, favState: 1),
        _folder(22),
      ], targetFav: true);
      expect(plan.hasChange, isFalse);
      expect(plan.alreadySatisfied, isTrue);
    });

    test('取消收藏会清掉所有已收藏的收藏夹', () {
      final plan = VideoFavoriteFolderSheet.planQuickToggle([
        _folder(11, favState: 1),
        _folder(22, favState: 1),
        _folder(33),
      ], targetFav: false);
      expect(plan.addIds, isEmpty);
      expect(plan.delIds, equals([11, 22]));
      expect(plan.alreadySatisfied, isFalse);
      expect(plan.hasChange, isTrue);
    });

    test('本来就不在收藏夹时取消视为已完成', () {
      final plan = VideoFavoriteFolderSheet.planQuickToggle([
        _folder(11),
        _folder(22),
      ], targetFav: false);
      expect(plan.hasChange, isFalse);
      expect(plan.alreadySatisfied, isTrue);
    });
  });

  group('分 P 宫格', () {
    test('列数按可用宽度收敛，宽屏不会挤成一条', () {
      expect(VideoPartGrid.columnsForWidth(360), equals(3));
      expect(VideoPartGrid.columnsForWidth(600), equals(4));
      expect(VideoPartGrid.columnsForWidth(800), equals(5));
      expect(VideoPartGrid.columnsForWidth(1200), equals(6));
    });

    testWidgets('倒序只影响展示顺序，序号仍按真实分 P 回传', (tester) async {
      final pages = [_page(0), _page(1), _page(2)];
      final tapped = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 320,
              child: VideoPartGrid(
                pages: pages,
                selectedIndex: 0,
                bvid: 'BVtest',
                reversed: true,
                shrinkWrap: true,
                crossAxisCount: 3,
                onSelect: tapped.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 倒序后第一个格子是最末一集，但序号文案必须是真实的 P3
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);

      await tester.tap(find.text('P3'));
      await tester.pumpAndSettle();
      expect(tapped, equals([2]));
    });

    testWidgets('maxItems 只做内联预览，不做完整列表', (tester) async {
      final pages = [_page(0), _page(1), _page(2), _page(3), _page(4)];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 320,
              child: VideoPartGrid(
                pages: pages,
                selectedIndex: 0,
                bvid: 'BVtest',
                maxItems: 3,
                shrinkWrap: true,
                crossAxisCount: 3,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VideoPartTile), findsNWidgets(3));
    });

    testWidgets('内联预览窗口跟随当前播放的分 P', (tester) async {
      final pages = List.generate(10, (i) => _page(i));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 320,
              child: VideoPartGrid(
                pages: pages,
                selectedIndex: 8,
                bvid: 'BVtest',
                maxItems: 3,
                shrinkWrap: true,
                crossAxisCount: 3,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 选中第 9 集时预览窗口必须包含它，而不是永远停在 P1~P3
      expect(find.text('P9'), findsOneWidget);
      expect(find.text('P1'), findsNothing);
      expect(find.byType(VideoPartTile), findsNWidgets(3));
    });

    testWidgets('选集面板打开时滚到当前播放的分 P', (tester) async {
      final pages = List.generate(30, (i) => _page(i));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => VideoPartGridSheet.show(
                    ctx,
                    pages: pages,
                    selectedIndex: 25,
                    bvid: 'BVtest',
                    onSelect: (_) {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 面板首帧后应滚到第 26 集附近，而不是停在 P1
      final grid = tester.widget<GridView>(find.byType(GridView));
      final controller = grid.controller!;
      expect(controller.hasClients, isTrue);
      expect(controller.offset, greaterThan(0));
      expect(find.text('P26'), findsOneWidget);
      expect(find.text('P1'), findsNothing);
    });
  });
}
