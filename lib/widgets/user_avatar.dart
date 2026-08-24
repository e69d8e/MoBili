import 'package:flutter/material.dart';
import 'network_image_view.dart';

class UserAvatar extends StatelessWidget {
  final String url;
  final double size;
  final int? level;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.url,
    this.size = 36.0,
    this.level,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int avatarCacheSize = (size * 2.5).round().clamp(60, 200);
    Widget avatar = ClipOval(
      child: NetworkImageView(
        url: url,
        width: size,
        height: size,
        memCacheWidth: avatarCacheSize,
        memCacheHeight: avatarCacheSize,
        fit: BoxFit.cover,
        errorWidget: Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: Icon(Icons.person, size: size * 0.6, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );

    if (level != null && level! > 0) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: _getLevelColor(level!),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 1,
                ),
              ),
              child: Text(
                'Lv$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }
    return avatar;
  }

  Color _getLevelColor(int lvl) {
    switch (lvl) {
      case 1:
        return const Color(0xFFBFBFBF);
      case 2:
        return const Color(0xFF95DDB2);
      case 3:
        return const Color(0xFF92D1E5);
      case 4:
        return const Color(0xFFFFB37C);
      case 5:
        return const Color(0xFFFF6C00);
      case 6:
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFFFF6699);
    }
  }
}
