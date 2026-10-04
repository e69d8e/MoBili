//
// 手势回归测试：ZoomableImage（图片查看器的缩放层）
//
// 直接测试 lib/widgets/zoomable_image.dart，外层用与
// lib/widgets/image_viewer.dart 相同的 PageView + 下滑关闭接线。
// 覆盖：双指缩放、双击缩放、放大后平移、未放大翻页、未放大下滑关闭、
// 下滑途中转为双指缩放。
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/widgets/zoomable_image.dart';

class TestViewerPage extends StatefulWidget {
  const TestViewerPage({super.key});

  @override
  State<TestViewerPage> createState() => _TestViewerPageState();
}

class _TestViewerPageState extends State<TestViewerPage> {
  final PageController _pageController = PageController();
  bool _isZoomed = false;
  Offset _dragOffset = Offset.zero;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDismissStart() {}

  void _onDismissUpdate(Offset delta) {
    if (_isZoomed) return;
    setState(() => _dragOffset += delta);
  }

  void _onDismissEnd(double verticalVelocity) {
    if (_isZoomed) return;
    if (_dragOffset.dy.abs() > 90 || verticalVelocity.abs() > 500) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragOffset = Offset.zero);
    }
  }

  void _onDismissCancel() {
    setState(() => _dragOffset = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Transform.translate(
        offset: _dragOffset,
        child: PageView.builder(
          controller: _pageController,
          physics: _isZoomed
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: 2,
          itemBuilder: (ctx, idx) => ZoomableImage(
            onTap: () {},
            onZoomChanged: (zoomed) {
              if (_isZoomed != zoomed) setState(() => _isZoomed = zoomed);
            },
            onDismissStart: _onDismissStart,
            onDismissUpdate: _onDismissUpdate,
            onDismissEnd: _onDismissEnd,
            onDismissCancel: _onDismissCancel,
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

Matrix4 _zoomMatrix(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byType(ZoomableImage), matching: find.byType(Transform)),
  );
  return transform.transform;
}

double _zoomScale(WidgetTester tester) => _zoomMatrix(tester).getMaxScaleOnAxis();

double _pageDragTx(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.byType(PageView), matching: find.byType(Transform)).first,
  );
  return transform.transform.getTranslation().x;
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const TestViewerPage()),
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
}

void main() {
  testWidgets('双指捏合可以缩放', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byType(ZoomableImage));

    final g1 = await tester.startGesture(c - const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 60));
    final g2 = await tester.startGesture(c + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await g1.moveBy(const Offset(-60, 0));
    await g2.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 60));

    // ignore: avoid_print
    print('pinch scale = ${_zoomScale(tester)}');
    expect(_zoomScale(tester), greaterThan(1.1), reason: '双指捏合后应放大');

    await g1.up();
    await g2.up();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('手指先后落下的不对称捏合仍可缩放（不会误触发下滑/翻页）', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byType(ZoomableImage));

    // 指一先纵向小幅移动（纵向主导会先被识别为下滑关闭）
    final g1 = await tester.startGesture(c - const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await g1.moveBy(const Offset(0, 25));
    await tester.pump(const Duration(milliseconds: 16));
    // 指二落下后向两侧张开
    final g2 = await tester.startGesture(c + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 6; i++) {
      await g1.moveBy(const Offset(-10, 0));
      await g2.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // ignore: avoid_print
    print('asymmetric pinch scale = ${_zoomScale(tester)}');
    expect(_zoomScale(tester), greaterThan(1.1), reason: '加指后应转为缩放');
    expect(_pageDragTx(tester), 0.0, reason: '关闭位移应回弹归零');
    expect(find.byType(TestViewerPage), findsOneWidget, reason: '不应被关闭');

    await g1.up();
    await g2.up();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('双击放大到 2.5x（以点击位置为中心），再双击复位', (tester) async {
    await _open(tester);
    const tapPos = Offset(350, 270);

    await tester.tapAt(tapPos);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(tapPos);
    // 第一个 pump 锚定动画时钟，第二个 pump 推进并完成动画
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final m = _zoomMatrix(tester);
    final t = m.getTranslation();
    // ignore: avoid_print
    print('double tap scale=${m.getMaxScaleOnAxis()} t=(${t.x}, ${t.y})');
    expect(m.getMaxScaleOnAxis(), closeTo(2.5, 0.05), reason: '双击应放大到 2.5x');
    expect(t.x, closeTo(-tapPos.dx * 1.5, 1.0), reason: '应围绕点击位置放大');
    expect(t.y, closeTo(-tapPos.dy * 1.5, 1.0), reason: '应围绕点击位置放大');

    await tester.tapAt(tapPos);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(tapPos);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_zoomMatrix(tester).isIdentity(), isTrue, reason: '再次双击应复位');
  });

  testWidgets('放大后单指拖动平移图片（不误触发下滑关闭）', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byType(ZoomableImage));

    await tester.tapAt(c);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(c);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_zoomScale(tester), closeTo(2.5, 0.05));

    final txBefore = _zoomMatrix(tester).getTranslation().x;
    final g = await tester.startGesture(c);
    await tester.pump(const Duration(milliseconds: 60));
    await g.moveBy(const Offset(-50, -5));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(-50, -5));
    await tester.pump(const Duration(milliseconds: 60));
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _zoomMatrix(tester).getTranslation().x,
      lessThan(txBefore - 40),
      reason: '放大后单指拖动应平移图片',
    );
    expect(find.byType(TestViewerPage), findsOneWidget, reason: '平移不应触发关闭');
  });

  testWidgets('未放大时左右滑动切换图片（不被缩放识别抢占）', (tester) async {
    await _open(tester);

    final pageView = find.byType(PageView);
    await tester.fling(pageView, const Offset(-500, 0), 3000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.widget<PageView>(pageView).controller!.page,
      closeTo(1.0, 0.1),
      reason: '未放大时左滑应翻到第二页',
    );
  });

  testWidgets('未放大时下滑关闭查看器', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byType(ZoomableImage));

    final g = await tester.startGesture(c);
    await tester.pump(const Duration(milliseconds: 60));
    await g.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 16));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TestViewerPage), findsNothing, reason: '下滑应关闭查看器');
  });

  testWidgets('放大后下滑只平移图片，不关闭查看器', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byType(ZoomableImage));

    await tester.tapAt(c);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(c);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final tyBefore = _zoomMatrix(tester).getTranslation().y;
    final g = await tester.startGesture(c);
    await tester.pump(const Duration(milliseconds: 60));
    await g.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 60));
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _zoomMatrix(tester).getTranslation().y,
      greaterThan(tyBefore + 40),
      reason: '放大后下滑应平移图片',
    );
    expect(find.byType(TestViewerPage), findsOneWidget, reason: '放大后下滑不应关闭');
  });
}
