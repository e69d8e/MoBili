import 'package:flutter/material.dart';
import '../../services/storage/app_cache_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_toast.dart';
import 'video_cache_screen.dart';

class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> {
  final AppCacheService _cacheService = AppCacheService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheService.calculateAllCacheSizes();
    });
  }

  Future<void> _handleClearAllCleanable() async {
    final info = _cacheService.cacheInfo;
    if (info.cleanableBytes <= 0) {
      AppToast.show(context, '当前暂无需要清理的缓存', icon: Icons.check_circle_outline_rounded);
      return;
    }

    final freedBytes = await _cacheService.clearAllCleanableCaches();
    if (!mounted) return;

    final freedStr = AppCacheService.formatBytes(freedBytes);
    AppToast.show(
      context,
      '已成功清理 $freedStr 缓存空间',
      icon: Icons.cleaning_services_rounded,
    );
  }

  Future<void> _handleClearImageCache() async {
    final freedBytes = await _cacheService.clearImageCache();
    if (!mounted) return;
    final freedStr = AppCacheService.formatBytes(freedBytes);
    AppToast.show(context, '已清理 $freedStr 图片缓存', icon: Icons.check_circle_outline_rounded);
  }

  Future<void> _handleClearTempFiles() async {
    final freedBytes = await _cacheService.clearTempFiles();
    if (!mounted) return;
    final freedStr = AppCacheService.formatBytes(freedBytes);
    AppToast.show(context, '已清理 $freedStr 临时缓冲文件', icon: Icons.check_circle_outline_rounded);
  }

  Future<void> _handleClearPlaybackHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空播放历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text('确定要清空本地保存的所有播放历史与进度记录吗？'),
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
      if (!mounted) return;
      AppToast.show(context, '已清空本地播放历史记录');
    }
  }

  Future<void> _handleClearSearchHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空搜索历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text('确定要清空所有搜索历史关键词吗？'),
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
      await _cacheService.clearSearchHistory();
      if (!mounted) return;
      AppToast.show(context, '已清空搜索历史记录');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _cacheService,
      builder: (context, _) {
        final info = _cacheService.cacheInfo;
        final isBusy = _cacheService.isCalculating || _cacheService.isCleaning;

        return Scaffold(
          appBar: AppBar(
            title: const Text('缓存管理'),
            actions: [
              IconButton(
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 22),
                tooltip: '重新扫描',
                onPressed: isBusy ? null : () => _cacheService.calculateAllCacheSizes(),
              ),
              const SizedBox(width: 8.0),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  children: [
                    // Overview Storage Card
                    _buildOverviewCard(context, info, primary, isDark),

                    const SizedBox(height: 16.0),

                    // Section 1: Temporary & Media Caches
                    _buildSectionHeader('临时与媒体缓存 (安全清理)', isDark),
                    Material(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildCacheItemTile(
                            context: context,
                            icon: Icons.image_outlined,
                            iconColor: primary,
                            title: '网络图片缓存',
                            subtitle: '封面、头像、动态插图及表情包',
                            sizeText: AppCacheService.formatBytes(info.imageCacheBytes),
                            actionText: '清理',
                            isDark: isDark,
                            onAction: info.imageCacheBytes > 0 ? _handleClearImageCache : null,
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 52,
                            color: context.colors.divider,
                          ),
                          _buildCacheItemTile(
                            context: context,
                            icon: Icons.folder_zip_outlined,
                            iconColor: context.colors.primary,
                            title: '系统临时与播放缓冲',
                            subtitle: '音视频播放缓冲分片、网络传输临时文件',
                            sizeText: AppCacheService.formatBytes(info.tempDirBytes),
                            actionText: '清理',
                            isDark: isDark,
                            onAction: info.tempDirBytes > 0 ? _handleClearTempFiles : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Section 2: Video Cache (Offline)
                    _buildSectionHeader('离线下载与离线视频', isDark),
                    Material(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildCacheItemTile(
                            context: context,
                            icon: Icons.video_library_outlined,
                            iconColor: Colors.deepPurpleAccent,
                            title: '离线视频与本地弹幕',
                            subtitle: info.videoCacheCount > 0
                                ? '已下载 ${info.videoCacheCount} 个分集视频及本地弹幕'
                                : '暂无已下载的离线视频',
                            sizeText: AppCacheService.formatBytes(info.videoCacheBytes),
                            actionText: '管理',
                            isDark: isDark,
                            onAction: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (ctx) => const VideoCacheScreen()),
                              );
                              _cacheService.calculateAllCacheSizes();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Section 3: History and records
                    _buildSectionHeader('本地记录与历史数据', isDark),
                    Material(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildCacheItemTile(
                            context: context,
                            icon: Icons.history_rounded,
                            iconColor: context.colors.primary,
                            title: '本地播放历史与进度',
                            subtitle: '记录视频精准播放秒数与断点续播位置',
                            sizeText: '${info.historyCount} 条记录',
                            actionText: '清空',
                            isDark: isDark,
                            isDestructive: true,
                            onAction: info.historyCount > 0 ? _handleClearPlaybackHistory : null,
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 52,
                            color: context.colors.divider,
                          ),
                          _buildCacheItemTile(
                            context: context,
                            icon: Icons.search_rounded,
                            iconColor: context.colors.warning,
                            title: '搜索关键词历史',
                            subtitle: '搜索框历史搜索关键词记录',
                            sizeText: '${info.searchHistoryCount} 条搜索词',
                            actionText: '清空',
                            isDark: isDark,
                            isDestructive: true,
                            onAction: info.searchHistoryCount > 0 ? _handleClearSearchHistory : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Section 4: Auto-Clean Strategy
                    _buildSectionHeader('自动清理策略', isDark),
                    _buildAutoCleanSection(context, primary, isDark),

                    const SizedBox(height: 24.0),
                  ],
                ),
              ),

              // Bottom Sticky Clean Bar
              _buildBottomBar(context, info, primary, isDark, isBusy),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAutoCleanSection(BuildContext context, Color primary, bool isDark) {
    final enabled = _cacheService.autoCleanEnabled;
    final interval = _cacheService.autoCleanInterval;
    final targets = _cacheService.autoCleanTargets;
    final lastTime = _cacheService.lastAutoCleanTimestamp;

    return Material(
      color: context.colors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            title: const Text('定时自动清理缓存', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '到达预设周期后在后台自动清理选定的缓存类型',
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textHint,
              ),
            ),
            value: enabled,
            activeTrackColor: primary,
            onChanged: (val) => _cacheService.setAutoCleanEnabled(val),
          ),
          if (enabled) ...[
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              color: context.colors.divider,
            ),
            ListTile(
              dense: true,
              title: const Text('清理周期', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                '当前频率：${interval.label}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textHint,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    interval.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.colors.textHint),
                ],
              ),
              onTap: () => _showIntervalPickerBottomSheet(context, primary, isDark),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              color: context.colors.divider,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4),
              child: Text(
                '自动清理项目选择：',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSub,
                ),
              ),
            ),
            for (final target in AutoCleanTarget.values) ...[
              CheckboxListTile(
                dense: true,
                value: targets.contains(target.key),
                activeColor: primary,
                title: Text(target.label, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  target.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textHint,
                  ),
                ),
                onChanged: (checked) {
                  _cacheService.toggleAutoCleanTarget(target.key, checked ?? false);
                },
              ),
            ],
            if (lastTime > 0) ...[
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                color: context.colors.divider,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  '上次自动清理：${Formatters.formatTime(lastTime ~/ 1000)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textHint,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showIntervalPickerBottomSheet(BuildContext context, Color primary, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: Row(
                  children: [
                    const Text(
                      '选择自动清理周期',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: context.colors.divider,
              ),
              for (final interval in AutoCleanInterval.values) ...[
                ListTile(
                  dense: true,
                  title: Text(
                    interval.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _cacheService.autoCleanInterval == interval ? FontWeight.w600 : FontWeight.normal,
                      color: _cacheService.autoCleanInterval == interval ? primary : null,
                    ),
                  ),
                  trailing: _cacheService.autoCleanInterval == interval
                      ? Icon(Icons.check_rounded, color: primary, size: 18)
                      : null,
                  onTap: () {
                    _cacheService.setAutoCleanInterval(interval);
                    Navigator.pop(ctx);
                  },
                ),
              ],
              const SizedBox(height: 8.0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8.0),
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

  Widget _buildOverviewCard(
    BuildContext context,
    CacheSizeInfo info,
    Color primary,
    bool isDark,
  ) {
    final cleanableStr = AppCacheService.formatBytes(info.cleanableBytes);
    final totalAppStr = AppCacheService.formatBytes(info.totalAppStorageBytes);

    final totalBytes = info.totalAppStorageBytes > 0 ? info.totalAppStorageBytes : 1;
    final imageRatio = (info.imageCacheBytes / totalBytes).clamp(0.0, 1.0);
    final tempRatio = (info.tempDirBytes / totalBytes).clamp(0.0, 1.0);
    final videoRatio = (info.videoCacheBytes / totalBytes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '可深度释放空间',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '总占用 $totalAppStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            cleanableStr,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: info.cleanableBytes > 0 ? primary : (context.colors.textHint),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12.0),

          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: info.totalAppStorageBytes <= 0
                  ? Container(color: isDark ? Colors.white10 : Colors.black12)
                  : Row(
                      children: [
                        if (imageRatio > 0)
                          Expanded(
                            flex: (imageRatio * 1000).toInt().clamp(1, 1000),
                            child: Container(color: primary),
                          ),
                        if (tempRatio > 0)
                          Expanded(
                            flex: (tempRatio * 1000).toInt().clamp(1, 1000),
                            child: Container(color: Colors.teal),
                          ),
                        if (videoRatio > 0)
                          Expanded(
                            flex: (videoRatio * 1000).toInt().clamp(1, 1000),
                            child: Container(color: Colors.deepPurpleAccent),
                          ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12.0),

          // Legend
          Row(
            children: [
              _buildLegendDot(primary, '图片缓存 (${AppCacheService.formatBytes(info.imageCacheBytes)})', isDark),
              const SizedBox(width: 12.0),
              _buildLegendDot(Colors.teal, '临时文件 (${AppCacheService.formatBytes(info.tempDirBytes)})', isDark),
              if (info.videoCacheBytes > 0) ...[
                const SizedBox(width: 12.0),
                _buildLegendDot(Colors.deepPurpleAccent, '离线视频 (${AppCacheService.formatBytes(info.videoCacheBytes)})', isDark),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.colors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildCacheItemTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String sizeText,
    required String actionText,
    required bool isDark,
    bool isDestructive = false,
    VoidCallback? onAction,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      sizeText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDestructive ? context.colors.danger : primary,
                side: BorderSide(
                  color: isDestructive
                      ? context.colors.danger.withValues(alpha: 0.4)
                      : (onAction == null
                          ? (isDark ? Colors.white12 : Colors.black12)
                          : primary.withValues(alpha: 0.4)),
                  width: 0.8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onAction,
              child: Text(actionText, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    CacheSizeInfo info,
    Color primary,
    bool isDark,
    bool isBusy,
  ) {
    final cleanableStr = AppCacheService.formatBytes(info.cleanableBytes);
    final canClean = info.cleanableBytes > 0 && !isBusy;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(
          top: BorderSide(
            color: context.colors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '可释放约 $cleanableStr 空间',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '清理不会影响登录态与离线视频',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: _cacheService.isCleaning
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.cleaning_services_rounded, size: 18),
            label: Text(
              _cacheService.isCleaning ? '正在清理...' : '一键深度清理',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: canClean ? _handleClearAllCleanable : null,
          ),
        ],
      ),
    );
  }
}
