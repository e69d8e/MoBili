import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/user_avatar.dart';
import '../dynamic/dynamic_screen.dart';
import 'cache_management_screen.dart';
import 'favorite_screen.dart';
import 'history_screen.dart';
import 'login_dialog.dart';
import 'relation_screen.dart';
import 'settings_screen.dart';
import 'video_cache_screen.dart';
import 'watch_later_screen.dart';
import '../../services/storage/video_cache_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const LoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    final user = auth.userInfo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        children: [
          if (auth.isCookieExpired) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 22),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('重新登录')
                  ),
                ],
              ),
            ),
          ],
          // User Card
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: user.isLogin ? null : () => _showLoginDialog(context),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
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
                                    Text(
                                      user.uname,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    if (user.vipLabel.isNotEmpty) ...[
                                      const SizedBox(width: 4.0),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: context.colors.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          user.vipLabel,
                                          style: TextStyle(
                                            color: context.colors.onPrimary,
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
                                const Text('点击登录哔哩哔哩'),
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
                    if (!user.isLogin)
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.primary),
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
              borderRadius: BorderRadius.circular(12),
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
                              builder: (ctx) => RelationScreen(mid: user.mid, initialIndex: 0),
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
                              builder: (ctx) => RelationScreen(mid: user.mid, initialIndex: 1),
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
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const DynamicScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12.0),
          ],

          // Quick Actions Group
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(Icons.history_rounded, color: context.colors.primary, size: 20),
                  title: const Text('历史记录'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const HistoryScreen()),
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
                  leading: Icon(Icons.watch_later_rounded, color: context.colors.primary, size: 20),
                  title: const Text('稍后观看'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const WatchLaterScreen()),
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
                  leading: Icon(Icons.star_rounded, color: context.colors.primary, size: 20),
                  title: const Text('我的收藏'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const FavoriteScreen()),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 48,
                  color: context.colors.divider,
                ),
                AnimatedBuilder(
                  animation: VideoCacheService(),
                  builder: (context, _) {
                    final activeCount = VideoCacheService().activeDownloadingCount;
                    final completedCount = VideoCacheService().totalCompletedCount;

                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.download_rounded, color: context.colors.primary, size: 20),
                      title: const Text('离线缓存'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (activeCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$activeCount 个下载中',
                                style: TextStyle(
                                  color: context.colors.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ] else if (completedCount > 0) ...[
                            Text(
                              '$completedCount 个视频',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textHint,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const VideoCacheScreen()),
                        );
                      },
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
                  leading: Icon(Icons.cleaning_services_rounded, color: context.colors.primary, size: 20),
                  title: const Text('缓存管理'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const CacheManagementScreen()),
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
                  leading: Icon(Icons.color_lens_outlined, color: context.colors.primary, size: 20),
                  title: const Text('外观与设置'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
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
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('退出', style: TextStyle(color: context.colors.danger)),
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
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

