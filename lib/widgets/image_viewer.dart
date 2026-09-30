import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dynamic_model.dart';
import 'app_toast.dart';

class ImageViewer extends StatefulWidget {
  final List<DynamicPicture> pictures;
  final int initialIndex;
  final String? heroPrefix;

  const ImageViewer({
    super.key,
    required this.pictures,
    this.initialIndex = 0,
    this.heroPrefix,
  });

  /// Opens the image viewer in full screen
  static void show(
    BuildContext context, {
    required List<DynamicPicture> pictures,
    int initialIndex = 0,
    String? heroPrefix,
  }) {
    if (pictures.isEmpty) return;

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ImageViewer(
              pictures: pictures,
              initialIndex: initialIndex,
              heroPrefix: heroPrefix,
            ),
          );
        },
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showUi = true;
  bool _isZoomed = false;

  // Drag-to-dismiss state
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  double _bgOpacity = 1.0;

  late final AnimationController _resetController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.pictures.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() {
          _dragOffset = _offsetAnimation.value;
          _bgOpacity = _opacityAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isZoomed = false;
    });
  }

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    _resetController.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _dragOffset += details.delta;
      final dragDistance = _dragOffset.dy.abs();
      _bgOpacity = (1.0 - (dragDistance / 350)).clamp(0.15, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    final dragDist = _dragOffset.dy.abs();

    if (dragDist > 90 || velocity.abs() > 500) {
      // Dismiss
      Navigator.of(context).pop();
    } else {
      // Animate back to original position
      _offsetAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));

      _opacityAnimation = Tween<double>(
        begin: _bgOpacity,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));

      _resetController.forward(from: 0.0).then((_) {
        setState(() {
          _isDragging = false;
          _dragOffset = Offset.zero;
          _bgOpacity = 1.0;
        });
      });
    }
  }

  void _showActionSheet() {
    final curPic = widget.pictures[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222228),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white),
                title: const Text('复制图片链接', style: TextStyle(color: Colors.white, fontSize: 14.5)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: curPic.url));
                  Navigator.of(ctx).pop();
                  AppToast.show(context, '已复制图片链接', icon: Icons.check);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.white),
                title: const Text('保存图片', style: TextStyle(color: Colors.white, fontSize: 14.5)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: curPic.url));
                  Navigator.of(ctx).pop();
                  AppToast.show(context, '图片链接已复制', icon: Icons.download_done_rounded);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pictures.length;
    final curPic = widget.pictures[_currentIndex];
    final dragScale = (1.0 - (_dragOffset.dy.abs() / 1200)).clamp(0.8, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Black Backdrop
          Container(
            color: Colors.black.withValues(alpha: _bgOpacity),
          ),

          // Images PageView with Gestures
          GestureDetector(
            onVerticalDragStart: _handleDragStart,
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: Transform.translate(
              offset: _dragOffset,
              child: Transform.scale(
                scale: dragScale,
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: total,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (ctx, idx) {
                    final pic = widget.pictures[idx];
                    final heroTag = widget.heroPrefix != null
                        ? '${widget.heroPrefix}_$idx'
                        : null;

                    return _ZoomableImage(
                      picture: pic,
                      heroTag: heroTag,
                      onTap: _toggleUi,
                      onZoomChanged: (zoomed) {
                        if (_isZoomed != zoomed) {
                          setState(() => _isZoomed = zoomed);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // Top Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showUi && !_isDragging ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close Button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),

                      // Index Indicator
                      if (total > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / $total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                      // Action Button
                      GestureDetector(
                        onTap: _showActionSheet,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Bar Overlay (Long image tip)
          if (curPic.isLongImage)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showUi && !_isDragging ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 0.6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.unfold_more_rounded, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          '长图，可双指缩放或滑动查看',
                          style: TextStyle(color: Colors.white, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final DynamicPicture picture;
  final String? heroTag;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImage({
    required this.picture,
    this.heroTag,
    required this.onTap,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnimation;

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

    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    widget.onZoomChanged(isZoomed);
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final Matrix4 targetMatrix;

    if (currentScale > 1.1) {
      // Zoom out to normal
      targetMatrix = Matrix4.identity();
    } else {
      // Zoom in to 2.5x centered at tap position
      final position = details.localPosition;
      final x = -position.dx * (2.5 - 1.0);
      final y = -position.dy * (2.5 - 1.0);
      targetMatrix = Matrix4.diagonal3Values(2.5, 2.5, 1.0)
        ..setTranslationRaw(x, y, 0.0);
    }

    _matrixAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward(from: 0.0);
  }

  String _formatUrl(String url) {
    String formatted = url.trim();
    if (formatted.startsWith('//')) {
      formatted = 'https:$formatted';
    } else if (formatted.startsWith('http://')) {
      formatted = formatted.replaceFirst('http://', 'https://');
    }
    if (formatted.contains('.avif')) {
      formatted = formatted.replaceAll('.avif', '.webp');
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final formattedUrl = _formatUrl(widget.picture.url);

    // 解码预算：按 contain 后的显示尺寸 × DPR × 1.25 缩放余量解码，
    // 总像素不超过原 2048² 的预算。方形大图 ~16.7MB → ~8MB，长图不再被
    // 2048 长边压到低于屏幕清晰度；无宽高比时维持 2048 兜底。
    final ratio = widget.picture.aspectRatio;
    int memCacheWidth = 2048;
    int memCacheHeight = 2048;
    if (ratio != null && ratio > 0) {
      final size = MediaQuery.sizeOf(context);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final sw = size.width;
      final sh = size.height;
      double dispW;
      double dispH;
      if (ratio >= sw / sh) {
        dispW = sw;
        dispH = sw / ratio;
      } else {
        dispH = sh;
        dispW = sh * ratio;
      }
      const headroom = 1.25;
      int w = (dispW * dpr * headroom).round();
      int h = (dispH * dpr * headroom).round();
      const maxPixels = 2048 * 2048;
      if (w * h > maxPixels) {
        final scale = math.sqrt(maxPixels / (w * h));
        w = (w * scale).round();
        h = (h * scale).round();
      }
      memCacheWidth = w.clamp(32, maxPixels);
      memCacheHeight = h.clamp(32, maxPixels);
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: formattedUrl,
      fit: BoxFit.contain,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: Duration.zero,
      httpHeaders: kIsWeb
          ? null
          : const {
              'Referer': 'https://www.bilibili.com',
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
            },
      placeholder: (context, url) => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white54,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
            const SizedBox(height: 8),
            Text(
              '图片加载失败',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {},
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.5,
          clipBehavior: Clip.none,
          child: imageWidget,
        ),
      ),
    );
  }
}
