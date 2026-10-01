import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/settings/player_settings_service.dart';
import '../../services/player/sleep_timer_service.dart';
import '../../services/storage/app_cache_service.dart';
import '../../services/storage/video_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/player/sleep_timer_bottom_sheet.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        children: [
          // App Brand Header
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
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
                  const SizedBox(height: 8.0),
                  const Text(
                    '墨哩 MoBili',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '极简水墨 · 沉浸哔哩',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section: Theme Presets
          _buildSectionHeader('主题配色'),
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < AppThemePreset.values.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 52,
                      color: context.colors.divider,
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

          const SizedBox(height: 20.0),

          // Section: Theme Mode (Light / Dark / AMOLED)
          _buildSectionHeader('显示模式'),
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
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
                  color: context.colors.divider,
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
                  color: context.colors.divider,
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
                  color: context.colors.divider,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('AMOLED 纯黑模式', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '深色模式下使用极致纯黑背景，更沉浸省电',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  value: themeProvider.isAmoled,
                  activeTrackColor: primaryColor,
                  onChanged: (val) => themeProvider.setAmoled(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20.0),

          // Section: Playback & Screen
          _buildSectionHeader('播放与屏幕'),
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: PlayerSettingsService.autoRotateListenable,
                  builder: (context, autoRotate, _) {
                    return SwitchListTile(
                      dense: true,
                      title: const Text('感应自动横屏', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '竖屏播放时，旋转手机自动进入横屏全屏播放',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textHint,
                        ),
                      ),
                      value: autoRotate,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        setState(() {
                          PlayerSettingsService.setAutoRotateFullScreen(val);
                        });
                      },
                    );
                  },
                ),
                 Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: PlayerSettingsService.subtitleEnabledListenable,
                  builder: (context, subtitleEnabled, _) {
                    return SwitchListTile(
                      dense: true,
                      title: const Text('默认开启字幕', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '视频含字幕时自动开启，并记忆播放器中的开关状态',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textHint,
                        ),
                      ),
                      value: subtitleEnabled,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        setState(() {
                          PlayerSettingsService.setSubtitleEnabled(val);
                        });
                      },
                    );
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                ValueListenableBuilder<int>(
                  valueListenable: PlayerSettingsService.qualityListenable,
                  builder: (context, currentQuality, _) {
                    return ListTile(
                      dense: true,
                      title: const Text('默认首选画质', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        _getQualityLabel(currentQuality),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textHint,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                      onTap: () => _showQualityPicker(context),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                ListTile(
                  dense: true,
                  title: const Text('默认播放倍速', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${PlayerSettingsService.defaultPlaybackSpeed}x',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: () => _showSpeedPicker(context),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                ListTile(
                  dense: true,
                  title: const Text('双击快进步长', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${PlayerSettingsService.doubleTapSeekSeconds} 秒',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: () => _showSeekSecondsPicker(context),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('自动连播下一分P', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '当前分P播放结束时，自动连播下一集',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  value: PlayerSettingsService.autoPlayNextEpisode,
                  activeTrackColor: primaryColor,
                  onChanged: (val) {
                    setState(() {
                      PlayerSettingsService.setAutoPlayNextEpisode(val);
                    });
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                AnimatedBuilder(
                  animation: SleepTimerService(),
                  builder: (context, _) {
                    final sleepService = SleepTimerService();
                    final statusText = sleepService.isActive
                        ? (sleepService.isEndOfVideoMode
                            ? '播完本视频后停止'
                            : '倒计时中: ${sleepService.formatRemaining()}')
                        : '已关闭';

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.bedtime_outlined,
                        size: 20,
                        color: sleepService.isActive ? primaryColor : (context.colors.textSub),
                      ),
                      title: const Text('睡眠定时器', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: sleepService.isActive ? primaryColor : (context.colors.textHint),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sleepService.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                sleepService.formatRemaining(),
                                style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        ],
                      ),
                      onTap: () => SleepTimerBottomSheet.show(context),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: PlayerSettingsService.incognitoListenable,
                  builder: (context, incognito, _) {
                    return SwitchListTile(
                      dense: true,
                      title: const Text('无痕浏览模式 (隐私)', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '开启后不上报播放进度至哔哩哔哩，本地亦不记录播放历史',
                        style: TextStyle(
                          fontSize: 11,
                          color: incognito ? context.colors.warning : (context.colors.textHint),
                        ),
                      ),
                      value: incognito,
                      activeTrackColor: context.colors.warning,
                      onChanged: (val) {
                        setState(() {
                          PlayerSettingsService.setIncognitoMode(val);
                        });
                        AppToast.show(
                          context,
                          val ? '已开启无痕浏览模式' : '已关闭无痕浏览模式',
                          icon: val ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20.0),

          // Section: Gestures & Interactions
          _buildSectionHeader('交互与手势'),
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  dense: true,
                  title: const Text('长按 2.0x 倍速播放', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '在播放器上长按手指即可触发 2.0x 高速播放，松手恢复',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  value: PlayerSettingsService.enableLongPressSpeed,
                  activeTrackColor: primaryColor,
                  onChanged: (val) {
                    setState(() {
                      PlayerSettingsService.setEnableLongPressSpeed(val);
                    });
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('屏幕两侧滑动调节 (亮度/音量)', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '左侧上下滑动调节屏幕亮度，右侧上下滑动调节音量',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  value: PlayerSettingsService.enableVerticalPanVolumeBrightness,
                  activeTrackColor: primaryColor,
                  onChanged: (val) {
                    setState(() {
                      PlayerSettingsService.setEnableVerticalPan(val);
                    });
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('水平滑动手势快进快退', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '在画面上左右平移拖动即可精确快进或快退',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  value: PlayerSettingsService.enableHorizontalPanSeek,
                  activeTrackColor: primaryColor,
                  onChanged: (val) {
                    setState(() {
                      PlayerSettingsService.setEnableHorizontalPan(val);
                    });
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('手势预返回 (Predictive Back)', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '侧滑返回时实时预览上一级页面（默认关闭，开启需系统与设备支持）',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textHint,
                    ),
                  ),
                  value: themeProvider.enablePredictiveBack,
                  activeTrackColor: primaryColor,
                  onChanged: (val) => themeProvider.setPredictiveBack(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20.0),

          // Section: Storage & Cache
          _buildSectionHeader('存储与缓存'),
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
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
                      title: const Text('缓存深度管理', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '可视化查看并清理网络图片、播放临时缓冲及记录',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textHint,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (info.cleanableBytes > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                cleanableStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
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
                      color: context.colors.divider,
                    ),
                    AnimatedBuilder(
                      animation: VideoCacheService(),
                      builder: (context, _) {
                        final sizeStr = VideoCacheService().getFormattedTotalCacheSize();
                        final count = VideoCacheService().totalCompletedCount;

                        return ListTile(
                          dense: true,
                          title: const Text('视频离线缓存', style: TextStyle(fontSize: 14)),
                          subtitle: Text(
                            count > 0 ? '已缓存 $count 个视频，占用 $sizeStr' : '暂无缓存视频',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textHint,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sizeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textHint,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
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
                      color: context.colors.divider,
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('快速清理图片缓存', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        info.imageCacheBytes > 0
                            ? '当前图片缓存占用 ${AppCacheService.formatBytes(info.imageCacheBytes)}'
                            : '释放封面与头像网络图片所占用的内存和磁盘缓存',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textHint,
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
                      color: context.colors.divider,
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('清空播放历史记录', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        info.historyCount > 0
                            ? '已记录 ${info.historyCount} 条本地视频播放进度'
                            : '清空本地保存的所有视频播放进度与历史记录',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textHint,
                        ),
                      ),
                      trailing: Icon(Icons.delete_outline_rounded, size: 18, color: context.colors.danger),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('清空播放历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            content: const Text('确定要清空本地保存的所有播放历史记录吗？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('清空', style: TextStyle(color: context.colors.danger)),
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

          const SizedBox(height: 20.0),

          // Section: About
          _buildSectionHeader('关于墨哩'),
          Material(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: const Text('软件版本', style: TextStyle(fontSize: 14)),
                  trailing: Text(
                    AppConstants.versionDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textHint,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: context.colors.divider,
                ),
                ListTile(
                  dense: true,
                  title: const Text('技术栈', style: TextStyle(fontSize: 14)),
                  trailing: Text(
                    AppConstants.techStack,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textHint,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.textSub,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
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
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppTheme.textMainDark : activePrimary)
                  : (context.colors.textMain),
            ),
          ),
          if (preset == AppThemePreset.ink) ...[
            const SizedBox(width: 4.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '默认',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSub,
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
          color: context.colors.textHint,
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
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: primaryColor, size: 18)
          : null,
      onTap: onTap,
    );
  }

  String _getQualityLabel(int quality) {
    switch (quality) {
      case 120:
        return '4K 超清';
      case 116:
        return '1080P 60帧';
      case 80:
        return '1080P 高清';
      case 64:
        return '720P 高清';
      case 32:
        return '480P 清晰';
      case 16:
        return '360P 流畅';
      default:
        return '${quality}P';
    }
  }

  void _showQualityPicker(BuildContext context) {
    final qualities = [
      {'val': 120, 'label': '4K 超清 (需大会员/设备支持)'},
      {'val': 116, 'label': '1080P 60帧 (流畅高帧率)'},
      {'val': 80, 'label': '1080P 高清 (推荐)'},
      {'val': 64, 'label': '720P 高清 (省流优先)'},
      {'val': 32, 'label': '480P 清晰'},
      {'val': 16, 'label': '360P 流畅'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryColor = Theme.of(ctx).colorScheme.primary;

        return Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              const Text('选择默认首选画质', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8.0),
              for (final q in qualities) ...[
                ListTile(
                  dense: true,
                  title: Text(q['label'] as String, style: const TextStyle(fontSize: 14)),
                  trailing: PlayerSettingsService.defaultQuality == q['val']
                      ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      PlayerSettingsService.setDefaultQuality(q['val'] as int);
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSpeedPicker(BuildContext context) {
    final speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryColor = Theme.of(ctx).colorScheme.primary;

        return Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              const Text('选择默认播放倍速', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8.0),
              for (final sp in speeds) ...[
                ListTile(
                  dense: true,
                  title: Text('${sp}x', style: const TextStyle(fontSize: 14)),
                  trailing: PlayerSettingsService.defaultPlaybackSpeed == sp
                      ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      PlayerSettingsService.setDefaultPlaybackSpeed(sp);
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSeekSecondsPicker(BuildContext context) {
    final secs = [5, 10, 15, 30];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryColor = Theme.of(ctx).colorScheme.primary;

        return Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              const Text('双击快进步长', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8.0),
              for (final s in secs) ...[
                ListTile(
                  dense: true,
                  title: Text('$s 秒', style: const TextStyle(fontSize: 14)),
                  trailing: PlayerSettingsService.doubleTapSeekSeconds == s
                      ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      PlayerSettingsService.setDoubleTapSeekSeconds(s);
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
