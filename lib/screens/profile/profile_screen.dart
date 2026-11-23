import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/storage/video_cache_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive_util.dart';
import '../../widgets/user_avatar.dart';
import '../up/up_space_screen.dart';
import 'cache_management_screen.dart';
import 'favorite_screen.dart';
import 'history_screen.dart';
import 'login_dialog.dart';
import 'relation_screen.dart';
import 'settings_screen.dart';
import 'video_cache_screen.dart';
import 'watch_later_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const LoginDialog(),
    );
  }

  void _openOwnSpace(BuildContext context, int mid) {
    if (mid <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => UpSpaceScreen(mid: mid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.userInfo;
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isCurrentlyDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system && platformDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: isCurrentlyDark ? '切换为浅色模式' : '切换为深色模式',
            icon: Icon(
              isCurrentlyDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              themeProvider.setThemeMode(
                isCurrentlyDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          IconButton(
            tooltip: '外观与设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4.0),
        ],
      ),
      body: ResponsiveMaxConstraint(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            if (auth.isLogin) {
              await auth.refreshUserInfo();
            }
          },
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              if (auth.isCookieExpired) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.12),
                    borderRadius: AppRadius.card,
                    border: Border.all(
                      color: context.colors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: context.colors.warning,
                        size: 22,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '登录凭证已过期',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.colors.warning,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '无法同步最新历史记录与收藏，请重新登录',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showLoginDialog(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('重新登录'),
                      ),
                    ],
                  ),
                ),
              ],

              // User Profile Card (点击进入个人空间 / 未登录则打开登录弹窗)
              Material(
                color: context.colors.card,
                borderRadius: AppRadius.card,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: user.isLogin
                      ? () => _openOwnSpace(context, user.mid)
                      : () => _showLoginDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        UserAvatar(
                          url: user.face,
                          size: 56,
                          level: user.level,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: user.isLogin
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.uname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (user.vipLabel.isNotEmpty) ...[
                                          const SizedBox(width: 6.0),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5.0,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.colors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              user.vipLabel,
                                              style: TextStyle(
                                                color:
                                                    context.colors.onPrimary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'UID: ${user.mid} · 硬币: ${user.money.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colors.textSub,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '点击登录哔哩哔哩',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '扫码登录后同步历史、收藏与动态',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 8),
                        if (user.isLogin)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '空间',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textHint,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: context.colors.textHint,
                              ),
                            ],
                          )
                        else
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: context.colors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12.0),

              // User Stats Row
              if (user.isLogin) ...[
                Material(
                  color: context.colors.card,
                  borderRadius: AppRadius.card,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context,
                            '关注',
                            Formatters.formatCount(user.following),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => RelationScreen(
                                    mid: user.mid,
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        _buildDivider(context),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            '粉丝',
                            Formatters.formatCount(user.follower),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => RelationScreen(
                                    mid: user.mid,
                                    initialIndex: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        _buildDivider(context),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            '动态',
                            Formatters.formatCount(user.dynamicCount),
                            onTap: () => _openOwnSpace(context, user.mid),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),
              ],

              // 4 宫格常用媒体库（历史记录 / 稍后观看 / 我的收藏 / 离线缓存）
              Material(
                color: context.colors.card,
                borderRadius: AppRadius.card,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickLibraryItem(
                          context,
                          icon: Icons.history_rounded,
                          label: '历史记录',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const HistoryScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildQuickLibraryItem(
                          context,
                          icon: Icons.watch_later_rounded,
                          label: '稍后观看',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const WatchLaterScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildQuickLibraryItem(
                          context,
                          icon: Icons.star_rounded,
                          label: '我的收藏',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const FavoriteScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: VideoCacheService(),
                          builder: (context, _) {
                            final activeCount =
                                VideoCacheService().activeDownloadingCount;
                            final completedCount =
                                VideoCacheService().totalCompletedCount;
                            final badge = activeCount > 0
                                ? '$activeCount'
                                : (completedCount > 0
                                    ? '$completedCount'
                                    : null);
                            return _buildQuickLibraryItem(
                              context,
                              icon: Icons.download_rounded,
                              label: '离线缓存',
                              badgeText: badge,
                              isBadgeHighlighted: activeCount > 0,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => const VideoCacheScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12.0),

              // Secondary Tools & Settings Group
              Material(
                color: context.colors.card,
                borderRadius: AppRadius.card,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.cleaning_services_rounded,
                        color: context.colors.primary,
                        size: 20,
                      ),
                      title: const Text('缓存管理'),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: context.colors.textHint,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const CacheManagementScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 48,
                      color: context.colors.divider,
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.color_lens_outlined,
                        color: context.colors.primary,
                        size: 20,
                      ),
                      title: const Text('外观与设置'),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: context.colors.textHint,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              if (user.isLogin) ...[
                const SizedBox(height: 20.0),
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('退出登录'),
                        content: const Text('确定要退出当前账号吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              '退出',
                              style: TextStyle(color: context.colors.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      auth.logout();
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  child: const Text('退出登录'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLibraryItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? badgeText,
    bool isBadgeHighlighted = false,
    required VoidCallback onTap,
  }) {
    final primary = context.colors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primary, size: 20),
                ),
                if (badgeText != null)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isBadgeHighlighted
                            ? primary
                            : context.colors.fill,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: AppTypography.tiny,
                          fontWeight: FontWeight.w600,
                          color: isBadgeHighlighted
                              ? context.colors.onPrimary
                              : context.colors.textSub,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: context.colors.textMain,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: context.colors.divider,
    );
  }
}

