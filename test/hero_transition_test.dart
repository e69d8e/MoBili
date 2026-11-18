import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证详情页「常驻但不可见」的 Hero 目标结构：Hero 被包在
/// Positioned.fill + IgnorePointer + Opacity(0.0) 里时仍能被 HeroController
/// 识别（尺寸非零），且 push/pop 转场不会抛异常或吞掉手势。
void main() {
  const tag = 'home_rcmd_BV1_0';

  testWidgets('不可见 Hero 目标承接 push/pop 共享元素转场', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: GestureDetector(
                key: const ValueKey('open'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _DetailPage(tag: tag),
                    ),
                  );
                },
                child: Hero(
                  tag: tag,
                  child: Container(width: 120, height: 80, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('详情页'), findsOneWidget);
    final targetHero = find.descendant(
      of: find.byType(_DetailPage),
      matching: find.byType(Hero),
    );
    expect(targetHero, findsOneWidget);
    final size = tester.getSize(targetHero);
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));

    // 反向飞回：详情页里的 Hero 仍在树里，pop 时应能匹配首页的 Hero
    await tester.tap(find.byKey(const ValueKey('back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (ctx) => GestureDetector(
          key: const ValueKey('back'),
          onTap: () => Navigator.of(ctx).pop(),
          child: Stack(
            children: [
              const Center(child: Text('详情页')),
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.0,
                    child: Hero(
                      tag: tag,
                      child: Container(color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
