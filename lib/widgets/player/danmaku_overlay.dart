import 'package:flutter/material.dart';
import '../../models/danmaku_model.dart';
import '../../services/danmaku_settings_service.dart';

class DanmakuController extends ChangeNotifier {
  List<DanmakuItem> _sortedDanmakus = [];
  bool _enabled = DanmakuSettingsService.enabled;
  double _opacity = DanmakuSettingsService.opacity;
  double _fontSizeScale = DanmakuSettingsService.fontSizeScale;
  double _areaRatio = DanmakuSettingsService.areaRatio;
  double _playbackSpeed = 1.0;
  bool _isPlaying = false;

  // Real-time smooth time tracking
  double _lastSyncVideoPosition = 0.0;
  int _lastSyncWallTimeMs = 0;

  // Text layout cache: item hashCode + fontSizeScale -> TextPainter
  final Map<int, TextPainter> _textPainterCache = {};

  List<DanmakuItem> get danmakus => _sortedDanmakus;
  bool get enabled => _enabled;
  double get opacity => _opacity;
  double get fontSizeScale => _fontSizeScale;
  double get areaRatio => _areaRatio;
  double get playbackSpeed => _playbackSpeed;
  bool get isPlaying => _isPlaying;

  double get currentPositionSeconds {
    if (!_isPlaying || _lastSyncWallTimeMs == 0) {
      return _lastSyncVideoPosition;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = (nowMs - _lastSyncWallTimeMs) / 1000.0;
    return _lastSyncVideoPosition + (elapsedSec * _playbackSpeed);
  }

  void setDanmakus(List<DanmakuItem> list) {
    _sortedDanmakus = List.from(list)..sort((a, b) => a.timePoint.compareTo(b.timePoint));
    _clearLayoutCache();
    notifyListeners();
  }

  void syncPlayerState({
    required double positionSeconds,
    required bool isPlaying,
    required double playbackSpeed,
  }) {
    final bool playingChanged = _isPlaying != isPlaying;
    final bool speedChanged = _playbackSpeed != playbackSpeed;
    final bool jumped = (positionSeconds - _lastSyncVideoPosition).abs() > 1.5;

    _lastSyncVideoPosition = positionSeconds;
    _lastSyncWallTimeMs = DateTime.now().millisecondsSinceEpoch;
    _isPlaying = isPlaying;
    _playbackSpeed = playbackSpeed;

    // Only trigger widget rebuilds on state transitions or major seeks
    if (playingChanged || speedChanged || jumped) {
      notifyListeners();
    }
  }

  void updatePosition(double seconds) {
    _lastSyncVideoPosition = seconds;
    _lastSyncWallTimeMs = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    if (_isPlaying != playing) {
      _lastSyncVideoPosition = currentPositionSeconds;
      _lastSyncWallTimeMs = DateTime.now().millisecondsSinceEpoch;
      _isPlaying = playing;
      notifyListeners();
    }
  }

  void setPlaybackSpeed(double speed) {
    _lastSyncVideoPosition = currentPositionSeconds;
    _lastSyncWallTimeMs = DateTime.now().millisecondsSinceEpoch;
    _playbackSpeed = speed;
    notifyListeners();
  }

  TextPainter getOrCreatePainter(DanmakuItem item) {
    final key = item.hashCode ^ ((fontSizeScale * 100).toInt() << 8) ^ ((opacity * 100).toInt() << 16);
    var painter = _textPainterCache[key];
    if (painter == null) {
      final double fontSize = (item.fontSize * fontSizeScale).clamp(10.0, 26.0);
      final double alpha = opacity.clamp(0.1, 1.0);
      final Color textColor = item.color.withValues(alpha: (item.color.a * alpha).clamp(0.0, 1.0));
      final Color shadowColor = Color.fromRGBO(0, 0, 0, 0.85 * alpha);

      final textSpan = TextSpan(
        text: item.text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(offset: const Offset(1, 1), blurRadius: 0.0, color: shadowColor),
          ],
        ),
      );
      painter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Gracefully evict oldest entries and release Skia/Impeller native text paragraph memory
      if (_textPainterCache.length >= 800) {
        final keysToRemove = _textPainterCache.keys.take(200).toList();
        for (final k in keysToRemove) {
          final removed = _textPainterCache.remove(k);
          removed?.dispose();
        }
      }
      _textPainterCache[key] = painter;
    }
    return painter;
  }

  void _clearLayoutCache() {
    for (final p in _textPainterCache.values) {
      p.dispose();
    }
    _textPainterCache.clear();
  }

  @override
  void dispose() {
    _clearLayoutCache();
    super.dispose();
  }

  void setEnabled(bool val) {
    if (_enabled != val) {
      _enabled = val;
      DanmakuSettingsService.setEnabled(val);
      notifyListeners();
    }
  }

  void toggle() {
    _enabled = !_enabled;
    DanmakuSettingsService.setEnabled(_enabled);
    notifyListeners();
  }

  void setOpacity(double val) {
    _opacity = val.clamp(0.1, 1.0);
    DanmakuSettingsService.setOpacity(_opacity);
    _clearLayoutCache();
    notifyListeners();
  }

  void setFontSizeScale(double val) {
    _fontSizeScale = val.clamp(0.5, 2.0);
    DanmakuSettingsService.setFontSizeScale(_fontSizeScale);
    _clearLayoutCache();
    notifyListeners();
  }

  void setAreaRatio(double val) {
    _areaRatio = val.clamp(0.2, 1.0);
    DanmakuSettingsService.setAreaRatio(_areaRatio);
    notifyListeners();
  }
}

class DanmakuOverlay extends StatefulWidget {
  final DanmakuController controller;

  const DanmakuOverlay({
    super.key,
    required this.controller,
  });

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _tickerController;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    widget.controller.addListener(_handleControllerUpdate);
    _updateTickerState();
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleControllerUpdate);
      widget.controller.addListener(_handleControllerUpdate);
      _updateTickerState();
    }
  }

  void _handleControllerUpdate() {
    if (mounted) {
      _updateTickerState();
      setState(() {});
    }
  }

  void _updateTickerState() {
    if (widget.controller.enabled && widget.controller.isPlaying && widget.controller.danmakus.isNotEmpty) {
      if (!_tickerController.isAnimating) {
        _tickerController.repeat();
      }
    } else {
      if (_tickerController.isAnimating) {
        _tickerController.stop();
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.enabled || widget.controller.danmakus.isEmpty) {
      return const SizedBox.shrink();
    }

    // Direct single-pass canvas painting with RepaintBoundary without Opacity saveLayer overhead
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _tickerController,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _DanmakuPainter(
                controller: widget.controller,
                currentSeconds: widget.controller.currentPositionSeconds,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  final DanmakuController controller;
  final double currentSeconds;

  // Duration in seconds for a scrolling danmaku to cross the screen
  static const double scrollDuration = 6.0;
  static const int trackCount = 12;
  static const int maxOnScreenDanmakus = 40;

  _DanmakuPainter({
    required this.controller,
    required this.currentSeconds,
  });

  int _findStartIndex(List<DanmakuItem> list, double minTime) {
    int low = 0;
    int high = list.length - 1;
    int ans = list.length;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (list[mid].timePoint >= minTime) {
        ans = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return ans;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final danmakus = controller.danmakus;
    if (danmakus.isEmpty) return;

    final double maxDisplayHeight = size.height * controller.areaRatio;
    final double trackHeight = maxDisplayHeight / trackCount;
    final double minTime = currentSeconds - scrollDuration;

    // Fast binary search to find visible range
    final int startIndex = _findStartIndex(danmakus, minTime);

    int paintedCount = 0;
    for (int i = startIndex; i < danmakus.length; i++) {
      if (paintedCount >= maxOnScreenDanmakus) break;

      final item = danmakus[i];
      if (item.timePoint > currentSeconds) break; // Future items, stop scanning

      final double progress = (currentSeconds - item.timePoint) / scrollDuration;
      if (progress < 0.0 || progress > 1.0) continue;

      final tp = controller.getOrCreatePainter(item);

      double x;
      if (item.mode == DanmakuMode.top || item.mode == DanmakuMode.bottom) {
        // Center fixed
        x = (size.width - tp.width) / 2;
      } else {
        // Scroll right to left
        x = size.width - progress * (size.width + tp.width);
      }

      // Cull items that have already scrolled past the left edge or haven't appeared
      if (x + tp.width < -10 || x > size.width + 10) continue;

      final int trackIndex = (item.text.hashCode.abs() + item.timestamp) % trackCount;
      final double y = trackIndex * trackHeight + 4;

      tp.paint(canvas, Offset(x, y));
      paintedCount++;
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) {
    return oldDelegate.currentSeconds != currentSeconds || oldDelegate.controller != controller;
  }
}
