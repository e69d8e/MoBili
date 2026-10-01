import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NetworkImageView extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const NetworkImageView({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    String formattedUrl = url.trim();
    if (formattedUrl.startsWith('//')) {
      formattedUrl = 'https:$formattedUrl';
    } else if (formattedUrl.startsWith('http://')) {
      formattedUrl = formattedUrl.replaceFirst('http://', 'https://');
    }

    // Convert AVIF to WebP to ensure 100% decoding compatibility across all devices
    if (formattedUrl.contains('.avif')) {
      formattedUrl = formattedUrl.replaceAll('.avif', '.webp');
    }

    if (formattedUrl.isEmpty) {
      return _buildFallback(context);
    }

    // Intelligently compute memCache constraints based on device pixel ratio
    int? effectiveCacheWidth = memCacheWidth;
    int? effectiveCacheHeight = memCacheHeight;

    if (effectiveCacheWidth == null && effectiveCacheHeight == null) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
      if (width != null && width! > 0 && width!.isFinite) {
        effectiveCacheWidth = (width! * dpr).round().clamp(60, 1440);
      }
      if (height != null && height! > 0 && height!.isFinite) {
        effectiveCacheHeight = (height! * dpr).round().clamp(60, 1440);
      }
      // Safe default upper bound to prevent decoding unconstrained 4K images into GPU memory
      if (effectiveCacheWidth == null && effectiveCacheHeight == null) {
        effectiveCacheWidth = 1080;
      }
    }

    // Optimize download size at Bilibili CDN level with WebP & on-the-fly thumbnail resizing
    formattedUrl = formatBiliCdnUrl(
      formattedUrl,
      cacheWidth: effectiveCacheWidth,
      cacheHeight: effectiveCacheHeight,
    );

    Widget image = CachedNetworkImage(
      imageUrl: formattedUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: effectiveCacheWidth,
      memCacheHeight: effectiveCacheHeight,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: Duration.zero,
      httpHeaders: kIsWeb
          ? null
          : const {
              'Referer': 'https://www.bilibili.com',
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
            },
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: context.colors.fill,
          ),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildFallback(context),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }
    return image;
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: context.colors.fill,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).hintColor,
        size: 24,
      ),
    );
  }

  /// Transforms raw Bilibili CDN URLs to request compressed WebP thumbnails at target resolution,
  /// avoiding downloading 1080P/4K original images into disk cache and mobile data waste.
  static String formatBiliCdnUrl(String url, {int? cacheWidth, int? cacheHeight}) {
    if (url.isEmpty) return url;
    // Skip GIFs and URLs that already have CDN formatting/crop suffixes
    if (url.contains('@') || url.toLowerCase().contains('.gif')) {
      return url;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();
    if (!host.contains('hdslb.com') && !host.contains('biliimg.com')) {
      return url;
    }

    // Determine target dimensions
    final int? w = cacheWidth != null && cacheWidth > 0 ? cacheWidth.clamp(60, 1920) : null;
    final int? h = cacheHeight != null && cacheHeight > 0 ? cacheHeight.clamp(60, 1920) : null;

    String suffix;
    if (w != null && h != null) {
      suffix = '@${w}w_${h}h_1c.webp';
    } else if (w != null) {
      suffix = '@${w}w.webp';
    } else if (h != null) {
      suffix = '@${h}h.webp';
    } else {
      suffix = '@1080w.webp';
    }

    if (url.contains('?')) {
      final parts = url.split('?');
      return '${parts[0]}$suffix?${parts.sublist(1).join('?')}';
    }
    return '$url$suffix';
  }
}
