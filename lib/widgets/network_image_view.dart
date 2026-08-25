import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF222228)
                : const Color(0xFFEEEEEE),
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
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF222228)
          : const Color(0xFFE5E5E5),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).hintColor,
        size: 24,
      ),
    );
  }
}
