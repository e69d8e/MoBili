import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = auth.userInfo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          // User Card
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: user.isLogin ? null : () => _showLoginDialog(context),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    UserAvatar(
                      url: user.face,
                      size: 56,
                      level: user.level,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: user.isLogin
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.uname,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    if (user.vipLabel.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          user.vipLabel,
                                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'UID: ${user.mid} · 硬币: ${user.money.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '点击登录哔哩哔哩',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '扫码登录后同步历史、收藏与动态',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (!user.isLogin)
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primaryColor),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // User Stats Row
          if (user.isLogin) ...[
            Material(
              color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        '关注',
                        Formatters.formatCount(user.following),
                        isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => RelationScreen(mid: user.mid, initialIndex: 0),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _buildStatItem(
                        '粉丝',
                        Formatters.formatCount(user.follower),
                        isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => RelationScreen(mid: user.mid, initialIndex: 1),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _buildStatItem(
                        '动态',
                        Formatters.formatCount(user.dynamicCount),
                        isDark,
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
            const SizedBox(height: 12),
          ],

          // Quick Actions Group
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.history_rounded, color: AppTheme.biliBlue, size: 20),
                  title: const Text('历史记录', style: TextStyle(fontSize: 13.5)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
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
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.watch_later_rounded, color: primaryColor, size: 20),
                  title: const Text('稍后观看', style: TextStyle(fontSize: 13.5)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
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
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.star_rounded, color: AppTheme.biliYellow, size: 20),
                  title: const Text('我的收藏', style: TextStyle(fontSize: 13.5)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
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
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                AnimatedBuilder(
                  animation: VideoCacheService(),
                  builder: (context, _) {
                    final activeCount = VideoCacheService().activeDownloadingCount;
                    final completedCount = VideoCacheService().totalCompletedCount;

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.download_rounded, color: Colors.teal, size: 20),
                      title: const Text('离线缓存', style: TextStyle(fontSize: 13.5)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (activeCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$activeCount 个下载中',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ] else if (completedCount > 0) ...[
                            Text(
                              '$completedCount 个视频',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
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
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.cleaning_services_rounded, color: Colors.blueGrey, size: 20),
                  title: const Text('缓存管理', style: TextStyle(fontSize: 13.5)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
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
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.color_lens_outlined, color: primaryColor, size: 20),
                  title: const Text('外观与设置', style: TextStyle(fontSize: 13.5)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
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
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    content: const Text('确定要退出当前账号吗？', style: TextStyle(fontSize: 13)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('退出', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  auth.logout();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('退出登录', style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 20,
      color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
    );
  }
}

