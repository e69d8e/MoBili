import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/responsive_util.dart';

/// Lightweight 60fps shimmer effect for skeleton loading placeholders
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations != _reduceMotion) {
      _reduceMotion = disableAnimations;
    }
    if (_reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      // 尊重系统减弱动态效果：停用扫光帧动画，保留静态占位骨架
      return widget.child;
    }

    final baseColor = context.colors.fill;
    final highlightColor = context.colors.fillHighlight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.45, 0.8],
              transform: _SlidingGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          // 复用 AnimatedBuilder 传入的缓存子树，避免 60fps 每帧重建整棵骨架网格
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

/// Skeleton placeholder for a single VideoCard
class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cardBg = context.colors.card;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppRadius.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cover placeholder（与新版卡片统一 16 / 10）
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: context.colors.fill,
            ),
          ),
          // Metadata lines placeholder
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.colors.fill,
                    borderRadius: AppRadius.of(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 5.0),
                Container(
                  height: 12,
                  width: 110,
                  decoration: BoxDecoration(
                    color: context.colors.fill,
                    borderRadius: AppRadius.of(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.colors.fill,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      height: 10,
                      width: 60,
                      decoration: BoxDecoration(
                        color: context.colors.fill,
                        borderRadius: AppRadius.of(AppRadius.xs),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton grid displayed while loading video feeds
class VideoGridSkeleton extends StatelessWidget {
  final int? itemCount;
  final EdgeInsetsGeometry padding;

  const VideoGridSkeleton({
    super.key,
    this.itemCount,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final crossAxisCount =
            ResponsiveGridConfig.calculateCrossAxisCountForWidth(availWidth);
        final mainAxisExtent = ResponsiveGridConfig.calculateMainAxisExtent(
          context,
          availableWidth: availWidth,
          crossAxisCount: crossAxisCount,
        );
        final effectiveCount = itemCount ?? (crossAxisCount * 3);

        return ShimmerLoading(
          child: GridView.builder(
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: mainAxisExtent,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: effectiveCount,
            itemBuilder: (ctx, idx) => const VideoCardSkeleton(),
          ),
        );
      },
    );
  }
}

/// Skeleton list displayed while loading single-column video lists (history / watch later)
class VideoListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const VideoListSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    final placeholderColor = context.colors.fill;

    return ShimmerLoading(
      child: ListView.separated(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12.0),
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover placeholder（与历史/稍后再看列表项的 124 宽封面一致）
              SizedBox(
                width: 124,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 13,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: 160,
                      height: 13,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: 90,
                      height: 11,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Skeleton placeholder for comments list
class CommentSkeleton extends StatelessWidget {
  final int itemCount;
  const CommentSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    final placeholderColor = context.colors.fill;

    return ShimmerLoading(
      child: ListView.separated(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 16.0),
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      height: 12,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Skeleton placeholder for Dynamic feed cards
class DynamicCardSkeleton extends StatelessWidget {
  final int itemCount;
  const DynamicCardSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    final placeholderColor = context.colors.fill;

    return ShimmerLoading(
      child: ListView.separated(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10.0),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: AppRadius.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 96,
                          height: 13,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: AppRadius.of(AppRadius.xs),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 64,
                          height: 10,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: AppRadius.of(AppRadius.xs),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: AppRadius.of(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 210,
                  height: 12,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: AppRadius.of(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: AppRadius.of(AppRadius.sm),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton placeholder for UP user list (search / relation lists)
class UserListSkeleton extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;
  const UserListSkeleton({
    super.key,
    this.itemCount = 6,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final placeholderColor = context.colors.fill;

    return ShimmerLoading(
      child: ListView.separated(
        primary: false,
        shrinkWrap: shrinkWrap,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 14.0),
        itemBuilder: (context, index) {
          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 13,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: AppRadius.of(AppRadius.xs),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 170,
                      height: 11,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: AppRadius.of(AppRadius.xs),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
