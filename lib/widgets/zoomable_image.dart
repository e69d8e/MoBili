import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 可双指缩放 / 双击缩放 / 放大后平移的图片容器。
///
/// 与 [InteractiveViewer] 的区别在于手势仲裁：
/// - 未放大时，单指横向拖动会把 arena 让给外层 PageView 完成翻页；
/// - 未放大时，单指纵向拖动通过 [onDismissUpdate] 系列回调实现下滑关闭；
/// - 双指（或触控板捏合）随时可缩放，已放大后单指可平移图片。
///
/// InteractiveViewer 无法实现这组手势：它内部的 scale 识别器对单指平移也会
/// accept（focalPointDelta 超过 pan slop 即接受），会把 PageView 的翻页手势
/// 整个吃掉，所以这里基于事件转发门控的 [ScaleGestureRecognizer] 自行实现。
class ZoomableImage extends StatefulWidget {
  final Widget child;

  /// 缩放比例跨越该阈值时回调 [onZoomChanged]（外层据此切换 PageView 翻页）。
  final ValueChanged<bool>? onZoomChanged;

  /// 单击（工具栏切换等）。
  final VoidCallback? onTap;

  // 下滑关闭手势回调：位移与关闭决策由外层实现，这里只上报原始手势。
  final VoidCallback? onDismissStart;
  final ValueChanged<Offset>? onDismissUpdate;
  final ValueChanged<double>? onDismissEnd;
  final VoidCallback? onDismissCancel;

  const ZoomableImage({
    super.key,
    required this.child,
    this.onZoomChanged,
    this.onTap,
    this.onDismissStart,
    this.onDismissUpdate,
    this.onDismissEnd,
    this.onDismissCancel,
  });

  @override
  State<ZoomableImage> createState() => ZoomableImageState();
}

/// 基于事件转发门控的缩放识别器。
///
/// 沿用 [ScaleGestureRecognizer] 的多指/触控板状态机，只在 arena 关闭前按
/// 手势意图转发事件：
/// - 双指（或触控板捏合）→ 始终转发，由缩放状态机处理；
/// - 已放大时的单指 → 转发，用于平移图片；
/// - 未放大时的单指 → 仅转发纵向主导的移动（下滑关闭），
///   横向主导的移动不转发，把 arena 让给 PageView 的横向拖动识别器翻页。
class _ZoomGestureRecognizer extends ScaleGestureRecognizer {
  /// 是否允许单指平移（已放大时为 true），由 [ZoomableImageState] 按帧刷新。
  bool singleFingerPanEnabled = false;

  bool _accepted = false;
  final Set<int> _livePointers = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _livePointers.add(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _livePointers.remove(event.pointer);
      super.handleEvent(event);
      return;
    }

    if (!_accepted) {
      if (event is PointerMoveEvent && _livePointers.length < 2) {
        final d = event.delta;
        if (!singleFingerPanEnabled && d.dy.abs() <= d.dx.abs()) return;
      } else if (event is PointerPanZoomUpdateEvent) {
        final d = event.panDelta;
        if (!singleFingerPanEnabled &&
            event.scale == 1.0 &&
            d.dy.abs() <= d.dx.abs()) {
          return;
        }
      }
    }

    super.handleEvent(event);
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _livePointers.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _accepted = false;
    super.didStopTrackingLastPointer(pointer);
  }
}

enum _ZoomMode { pinch, pan, dismiss }

class ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnimation;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.5;
  static const double _zoomedThreshold = 1.05;
  static const double _doubleTapScale = 2.5;

  // 手势状态：模式在首次 onUpdate 时判定，之后保持稳定；
  // 手指中途加入/抬起会重置 scale 基准，需重新锚定。
  _ZoomMode? _mode;
  bool _zoomed = false;
  bool _dismissStarted = false;
  double _gestureStartScale = _minScale;
  Offset _referenceScene = Offset.zero;
  int _lastPointerCount = 0;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_matrixAnimation != null) {
          _transformationController.value = _matrixAnimation!.value;
        }
      });

    _transformationController.addListener(_notifyZoomChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_notifyZoomChanged);
    _transformationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _notifyZoomChanged() {
    final zoomed =
        _transformationController.value.getMaxScaleOnAxis() > _zoomedThreshold;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged?.call(zoomed);
    }
  }

  // —— 矩阵工具（无旋转，屏幕坐标 = scale * 内容坐标 + 平移） ——

  Offset _toScene(Offset point) {
    final m = _transformationController.value;
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    return Offset((point.dx - t.x) / scale, (point.dy - t.y) / scale);
  }

  /// 构造"内容坐标 scenePoint 在屏幕坐标 screenPoint 处、缩放为 scale"的矩阵，
  /// 并把平移钳制在内容始终覆盖视口的范围内（贴合边界时焦点驻留）。
  Matrix4 _matrixForAnchor({
    required double scale,
    required Offset scenePoint,
    required Offset screenPoint,
  }) {
    if (scale <= _minScale) return Matrix4.identity();
    final m = Matrix4.identity()
      ..translateByDouble(screenPoint.dx, screenPoint.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0, 1);
    return _clampTranslation(m, scale);
  }

  Matrix4 _clampTranslation(Matrix4 m, double scale) {
    final minX = _viewport.width * (1 - scale);
    final minY = _viewport.height * (1 - scale);
    final t = m.getTranslation();
    final tx = math.min(math.max(t.x, minX), 0.0);
    final ty = math.min(math.max(t.y, minY), 0.0);
    return m.clone()..setTranslationRaw(tx, ty, 0.0);
  }

  void _animateMatrixTo(Matrix4 target) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward(from: 0.0);
  }

  // —— 缩放 / 平移 / 下滑关闭手势 ——

  void _onScaleStart(ScaleStartDetails details) {
    _animController.stop();
    _mode = null;
    _dismissStarted = false;
    _lastPointerCount = 0;
  }

  _ZoomMode _decideMode(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2 || details.scale != 1.0) {
      return _ZoomMode.pinch;
    }
    // 单指：已放大 → 平移；未放大 → 下滑关闭
    return _transformationController.value.getMaxScaleOnAxis() > _zoomedThreshold
        ? _ZoomMode.pan
        : _ZoomMode.dismiss;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _mode ??= _decideMode(details);

    // 下滑关闭途中加了手指 → 取消关闭，转为双指缩放
    if (_mode == _ZoomMode.dismiss && details.pointerCount >= 2) {
      widget.onDismissCancel?.call();
      _mode = _ZoomMode.pinch;
    }

    // 下滑关闭开始：通知外层（停止回弹动画、记录拖动状态等）
    if (_mode == _ZoomMode.dismiss && !_dismissStarted) {
      _dismissStarted = true;
      widget.onDismissStart?.call();
    }

    // 缩放过程中指针数量变化（加指/抬指）时 scale 会重新归一，
    // 以当前矩阵与焦点位置重新锚定基准，避免缩放跳变。
    if (_mode == _ZoomMode.pinch && details.pointerCount != _lastPointerCount) {
      _gestureStartScale = _transformationController.value.getMaxScaleOnAxis();
      _referenceScene = _toScene(details.localFocalPoint);
    }
    _lastPointerCount = details.pointerCount;

    switch (_mode!) {
      case _ZoomMode.pinch:
        // 单指残指时 scale 为 0，退化为按焦点平移
        final effectiveScale = details.scale > 0 ? details.scale : 1.0;
        final targetScale = math.min(
          math.max(_gestureStartScale * effectiveScale, _minScale),
          _maxScale,
        );
        _transformationController.value = _matrixForAnchor(
          scale: targetScale,
          scenePoint: _referenceScene,
          screenPoint: details.localFocalPoint,
        );

      case _ZoomMode.pan:
        final m = _transformationController.value.clone();
        final t = m.getTranslation();
        m.setTranslationRaw(
          t.x + details.focalPointDelta.dx,
          t.y + details.focalPointDelta.dy,
          0.0,
        );
        _transformationController.value =
            _clampTranslation(m, m.getMaxScaleOnAxis());

      case _ZoomMode.dismiss:
        widget.onDismissUpdate?.call(details.focalPointDelta);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final mode = _mode;
    _mode = null;
    _dismissStarted = false;
    _lastPointerCount = 0;

    if (mode == _ZoomMode.dismiss) {
      widget.onDismissEnd?.call(details.velocity.pixelsPerSecond.dy);
      return;
    }

    // 缩放回弹：没放大到阈值以上时回到原尺寸
    final m = _transformationController.value;
    final scale = m.getMaxScaleOnAxis();
    if (scale < _zoomedThreshold && !m.isIdentity()) {
      _animateMatrixTo(Matrix4.identity());
    }
  }

  // —— 双击缩放 ——

  void _handleDoubleTap(TapDownDetails details) {
    _animController.stop();
    final current = _transformationController.value;
    final Matrix4 target;
    if (current.getMaxScaleOnAxis() > 1.1) {
      target = Matrix4.identity();
    } else {
      final position = details.localPosition;
      target = _matrixForAnchor(
        scale: _doubleTapScale,
        scenePoint: _toScene(position),
        screenPoint: position,
      );
    }
    _animateMatrixTo(target);
  }

  @override
  Widget build(BuildContext context) {
    // 子级铺满整页：手势区覆盖到黑边，且 Transform 的内容坐标空间
    // 与手势回调的坐标空间一致（双击定位、边界钳制都依赖这一点）。
    final content = SizedBox.expand(child: widget.child);

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;

        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _ZoomGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_ZoomGestureRecognizer>(
              () => _ZoomGestureRecognizer(),
              (instance) {
                instance
                  ..singleFingerPanEnabled = _zoomed
                  ..onStart = _onScaleStart
                  ..onUpdate = _onScaleUpdate
                  ..onEnd = _onScaleEnd;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onDoubleTapDown: _handleDoubleTap,
            onDoubleTap: () {},
            child: AnimatedBuilder(
              animation: _transformationController,
              builder: (context, child) => Transform(
                transform: _transformationController.value,
                child: child,
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
