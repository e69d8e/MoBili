import 'package:flutter/material.dart';
import '../../models/danmaku_model.dart';
import '../../services/settings/danmaku_settings_service.dart';

class DanmakuController extends ChangeNotifier {
  List<DanmakuItem> _sortedDanmakus = [];
  bool _enabled = DanmakuSettingsService.enabled;
  double _opacity = DanmakuSettingsService.opacity;
  double _fontSizeScale = DanmakuSettingsService.fontSizeScale;
  double _areaRatio = DanmakuSettingsService.areaRatio;
  double _playbackSpeed = 1.0;
  bool _isPlaying = false;

  // Real-time monotonic smooth time tracking
  double _baseVideoPosition = 0.0;
  final Stopwatch _stopwatch = Stopwatch();
  double _lastComputedSeconds = 0.0;

  // Text layout cache: item hashCode + fontSizeScale + opacity -> TextPainter (LRU via LinkedHashMap)
  final Map<int, TextPainter> _textPainterCache = {};
  static const int _maxCacheSize = 1500;

  List<DanmakuItem> get danmakus => _sortedDanmakus;
  bool get enabled => _enabled;
  double get opacity => _opacity;
  double get fontSizeScale => _fontSizeScale;
  double get areaRatio => _areaRatio;
  double get playbackSpeed => _playbackSpeed;
  bool get isPlaying => _isPlaying;

  double get currentPositionSeconds {
    if (!_isPlaying) {
      return _baseVideoPosition;
    }
    final elapsedSec = _stopwatch.elapsedMicroseconds / 1000000.0;
    final interpolated = _baseVideoPosition + (elapsedSec * _playbackSpeed);
    // Guarantee non-decreasing monotonicity during continuous playback to avoid backwards jitter
    if (interpolated >= _lastComputedSeconds) {
      _lastComputedSeconds = interpolated;
    }
    return _lastComputedSeconds;
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
    final bool speedChanged = (_playbackSpeed - playbackSpeed).abs() > 0.01;

    _isPlaying = isPlaying;
    _playbackSpeed = playbackSpeed;

    if (playingChanged || speedChanged) {
      _baseVideoPosition = positionSeconds;
      _lastComputedSeconds = positionSeconds;
      _stopwatch.reset();
      if (_isPlaying) {
        _stopwatch.start();
      }
      notifyListeners();
      return;
    }

    if (!_isPlaying) {
      _baseVideoPosition = positionSeconds;
      _lastComputedSeconds = positionSeconds;
      _stopwatch.reset();
      return;
    }

    // Video is playing smoothly and speed has not changed:
    final currentPred = _baseVideoPosition + (_stopwatch.elapsedMicroseconds / 1000000.0 * _playbackSpeed);
    final drift = positionSeconds - currentPred;

    // Noticeable seek or buffer stall (> 0.8s drift)
    if (drift.abs() > 0.8) {
      _baseVideoPosition = positionSeconds;
      _lastComputedSeconds = positionSeconds;
      _stopwatch.reset();
      _stopwatch.start();
      notifyListeners();
    } else if (drift.abs() > 0.05) {
      // Soft drift compensation: gently nudge base without hard resetting stopwatch
      // This completely eliminates micro-stutters and backwards snaps during high-speed playback
      _baseVideoPosition += drift * 0.15;
    }
  }

  void updatePosition(double seconds) {
    _baseVideoPosition = seconds;
    _lastComputedSeconds = seconds;
    _stopwatch.reset();
    if (_isPlaying) {
      _stopwatch.start();
    }
    notifyListeners();
  }

  void setPlaying(bool playing) {
    if (_isPlaying != playing) {
      final currentPos = currentPositionSeconds;
      _isPlaying = playing;
      _baseVideoPosition = currentPos;
      _lastComputedSeconds = currentPos;
      _stopwatch.reset();
      if (_isPlaying) {
        _stopwatch.start();
      }
      notifyListeners();
    }
  }

  void setPlaybackSpeed(double speed) {
    final currentPos = currentPositionSeconds;
    _playbackSpeed = speed;
    _baseVideoPosition = currentPos;
    _lastComputedSeconds = currentPos;
    _stopwatch.reset();
    if (_isPlaying) {
      _stopwatch.start();
    }
    notifyListeners();
  }

  TextPainter getOrCreatePainter(DanmakuItem item) {
    final key = item.hashCode ^ ((fontSizeScale * 100).toInt() << 8) ^ ((opacity * 100).toInt() << 16);
    // Fast path: check cache and refresh LRU position
    final existing = _textPainterCache.remove(key);
    if (existing != null) {
      _textPainterCache[key] = existing;
      return existing;
    }

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
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Evict oldest (first) entry when capacity exceeded
    if (_textPainterCache.length >= _maxCacheSize) {
      final firstKey = _textPainterCache.keys.first;
      final oldest = _textPainterCache.remove(firstKey);
      oldest?.dispose();
    }
    _textPainterCache[key] = painter;
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
    _stopwatch.stop();
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

  // Duration in seconds for a scrolling danmaku to cross the screen in video timeline
  static const double scrollDuration = 6.0;
  static const int maxOnScreenDanmakus = 60;

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

    final double baseTrackHeight = (19.0 * controller.fontSizeScale).clamp(18.0, 32.0);
    final double maxDisplayHeight = size.height * controller.areaRatio;
    final int availableTracks = (maxDisplayHeight / baseTrackHeight).floor().clamp(1, 24);
    final double trackHeight = maxDisplayHeight / availableTracks;
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

      final int trackIndex = (item.text.hashCode.abs() + item.timestamp) % availableTracks;
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
