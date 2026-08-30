import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/player_settings_service.dart';
import '../../services/storage/app_cache_service.dart';
import '../../services/storage/video_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import 'cache_management_screen.dart';
import 'video_cache_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppCacheService _cacheService = AppCacheService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheService.calculateAllCacheSizes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('外观与设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        children: [
          // App Brand Header
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '墨哩 MoBili',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '极简水墨 · 沉浸哔哩',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section: Theme Presets
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '主题配色',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < AppThemePreset.values.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 52,
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                    ),
                  _buildPresetTile(
                    context: context,
                    preset: AppThemePreset.values[i],
                    isSelected: themeProvider.themePreset == AppThemePreset.values[i],
                    isDark: isDark,
                    onTap: () => themeProvider.setThemePreset(AppThemePreset.values[i]),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Theme Mode (Light / Dark / AMOLED)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '显示模式',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildThemeOption(
                  context: context,
                  title: '跟随系统',
                  isSelected: themeProvider.themeMode == ThemeMode.system,
                  primaryColor: primaryColor,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                _buildThemeOption(
                  context: context,
                  title: '浅色模式',
                  isSelected: themeProvider.themeMode == ThemeMode.light,
                  primaryColor: primaryColor,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                _buildThemeOption(
                  context: context,
                  title: '深色模式',
                  isSelected: themeProvider.themeMode == ThemeMode.dark,
                  primaryColor: primaryColor,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('AMOLED 纯黑模式', style: TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    '深色模式下使用极致纯黑背景，更沉浸省电',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                  value: themeProvider.isAmoled,
                  activeTrackColor: primaryColor,
                  onChanged: (val) => themeProvider.setAmoled(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Playback & Screen
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '播放与屏幕',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: PlayerSettingsService.autoRotateListenable,
                  builder: (context, autoRotate, _) {
                    return SwitchListTile(
                      dense: true,
                      title: const Text('感应自动横屏', style: TextStyle(fontSize: 13.5)),
                      subtitle: Text(
                        '竖屏播放时，旋转手机自动进入横屏全屏播放',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                      value: autoRotate,
                      activeTrackColor: primaryColor,
                      onChanged: (val) => PlayerSettingsService.setAutoRotateFullScreen(val),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Gestures & Interactions
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '交互与手势',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  dense: true,
                  title: const Text('手势预返回 (Predictive Back)', style: TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    '侧滑返回时实时预览上一级页面（默认关闭，开启需系统与设备支持）',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                  value: themeProvider.enablePredictiveBack,
                  activeTrackColor: primaryColor,
                  onChanged: (val) => themeProvider.setPredictiveBack(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Storage & Cache
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '存储与缓存',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: _cacheService,
              builder: (context, _) {
                final info = _cacheService.cacheInfo;
                final cleanableStr = AppCacheService.formatBytes(info.cleanableBytes);

                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: const Text('缓存深度管理', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '可视化查看并清理网络图片、播放临时缓冲及记录',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (info.cleanableBytes > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                cleanableStr,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const CacheManagementScreen()),
                        );
                        _cacheService.calculateAllCacheSizes();
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                    ),
                    AnimatedBuilder(
                      animation: VideoCacheService(),
                      builder: (context, _) {
                        final sizeStr = VideoCacheService().getFormattedTotalCacheSize();
                        final count = VideoCacheService().totalCompletedCount;

                        return ListTile(
                          dense: true,
                          title: const Text('视频离线缓存', style: TextStyle(fontSize: 13.5)),
                          subtitle: Text(
                            count > 0 ? '已缓存 $count 个视频，占用 $sizeStr' : '暂无缓存视频',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sizeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (ctx) => const VideoCacheScreen()),
                            );
                            _cacheService.calculateAllCacheSizes();
                          },
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('快速清理图片缓存', style: TextStyle(fontSize: 13.5)),
                      subtitle: Text(
                        info.imageCacheBytes > 0
                            ? '当前图片缓存占用 ${AppCacheService.formatBytes(info.imageCacheBytes)}'
                            : '释放封面与头像网络图片所占用的内存和磁盘缓存',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                      trailing: const Icon(Icons.cleaning_services_rounded, size: 18),
                      onTap: () async {
                        final freed = await _cacheService.clearImageCache();
                        if (context.mounted) {
                          AppToast.show(
                            context,
                            '已清理 ${AppCacheService.formatBytes(freed)} 网络图片缓存',
                            icon: Icons.check_circle_outline_rounded,
                          );
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('清空播放历史记录', style: TextStyle(fontSize: 13.5)),
                      subtitle: Text(
                        info.historyCount > 0
                            ? '已记录 ${info.historyCount} 条本地视频播放进度'
                            : '清空本地保存的所有视频播放进度与历史记录',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                        ),
                      ),
                      trailing: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('清空播放历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            content: const Text('确定要清空本地保存的所有播放历史记录吗？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('清空', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _cacheService.clearPlaybackHistory();
                          if (context.mounted) {
                            AppToast.show(context, '已清空本地播放历史');
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Section: About
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '关于墨哩',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: const Text('软件版本', style: TextStyle(fontSize: 13.5)),
                  trailing: Text(
                    'v1.0.1',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                ListTile(
                  dense: true,
                  title: const Text('技术栈', style: TextStyle(fontSize: 13.5)),
                  trailing: Text(
                    'Flutter + Bili WBI API',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetTile({
    required BuildContext context,
    required AppThemePreset preset,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activePrimary = isDark ? preset.darkPrimary : preset.lightPrimary;

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              preset.previewColors[0],
              preset.previewColors[1],
            ],
          ),
          border: Border.all(
            color: isSelected
                ? activePrimary
                : (isDark ? Colors.white24 : Colors.black12),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activePrimary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
      title: Row(
        children: [
          Text(
            preset.name,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppTheme.textMainDark : activePrimary)
                  : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
            ),
          ),
          if (preset == AppThemePreset.ink) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '默认',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        preset.description,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: activePrimary, size: 20)
          : null,
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: primaryColor, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
