import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/video_model.dart';
import 'package:mobili/screens/video/widgets/video_season_sheet.dart';

UgcSeason _buildSeason(int count, {int duration = 300}) {
  final episodes = List.generate(count, (i) {
    return UgcEpisode(
      id: i,
      aid: i,
      bvid: 'BV$i',
      cid: 100 + i,
      title: 'Episode $i',
      cover: '',
      duration: duration,
      page: 1,
    );
  });
  return UgcSeason(
    id: 1,
    title: 'Test Season',
    cover: '',
    mid: 2,
    intro: '',
    epCount: count,
    sections: [UgcSection(seasonId: 1, id: 1, title: '正片', episodes: episodes)],
  );
}

Future<void> _pumpSheet(WidgetTester tester, UgcSeason season, String currentBvid) async {
  BuildContext? capturedContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          capturedContext = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  VideoSeasonSheet.show(
    capturedContext!,
    season: season,
    currentBvid: currentBvid,
    onSelectEpisode: (_) {},
  );
  await tester.pumpAndSettle();
}

Rect _listViewportRect(WidgetTester tester) {
  return tester.getRect(find.byType(ListView));
}

void main() {
  testWidgets('长合集打开时自动定位到正在播放的剧集', (tester) async {
    const currentIndex = 30;
    await _pumpSheet(tester, _buildSeason(40), 'BV$currentIndex');

    // 目标项必须已被构建（懒加载列表只构建可视范围内的项）
    final target = find.text('${currentIndex + 1}. Episode $currentIndex');
    expect(target, findsOneWidget);

    // 目标项应落在列表可视区域内（ensureVisible 校正后不再被裁切）
    final itemRect = tester.getRect(target);
    final viewport = _listViewportRect(tester);
    expect(itemRect.top, greaterThanOrEqualTo(viewport.top - 1));
    expect(itemRect.bottom, lessThanOrEqualTo(viewport.bottom + 1));
  });

  testWidgets('短合集（shrinkWrap）打开时同样定位到正在播放的剧集', (tester) async {
    const currentIndex = 7;
    await _pumpSheet(tester, _buildSeason(10), 'BV$currentIndex');

    final target = find.text('${currentIndex + 1}. Episode $currentIndex');
    expect(target, findsOneWidget);

    final itemRect = tester.getRect(target);
    final viewport = _listViewportRect(tester);
    expect(itemRect.top, greaterThanOrEqualTo(viewport.top - 1));
    expect(itemRect.bottom, lessThanOrEqualTo(viewport.bottom + 1));
  });

  testWidgets('未找到当前剧集时保持列表顶部不崩溃', (tester) async {
    await _pumpSheet(tester, _buildSeason(40), 'BV_NOT_EXIST');

    expect(find.text('1. Episode 0'), findsOneWidget);
  });
}
