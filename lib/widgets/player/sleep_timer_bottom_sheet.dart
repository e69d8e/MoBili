import 'package:flutter/material.dart';
import '../../services/player/sleep_timer_service.dart';
import '../../theme/app_colors.dart';
import '../app_toast.dart';

class SleepTimerBottomSheet extends StatefulWidget {
  const SleepTimerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SleepTimerBottomSheet(),
    );
  }

  @override
  State<SleepTimerBottomSheet> createState() => _SleepTimerBottomSheetState();
}

class _SleepTimerBottomSheetState extends State<SleepTimerBottomSheet> {
  final SleepTimerService _service = SleepTimerService();

  final List<int> _presetMinutes = [15, 30, 45, 60, 90];

  void _showCustomMinutesDialog() {
    int customMins = 20;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Text('自定义定时分钟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$customMins 分钟后停止播放', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                Slider(
                  value: customMins.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  onChanged: (val) {
                    setDlgState(() {
                      customMins = val.round();
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _service.startTimer(Duration(minutes: customMins));
                  if (mounted) {
                    AppToast.show(context, '已设置 $customMins 分钟后定时停止');
                  }
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final isActive = _service.isActive;

        return Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle pill
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

              // Title bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bedtime_outlined, size: 20, color: primaryColor),
                      const SizedBox(width: 8.0),
                      const Text(
                        '睡眠定时器',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (isActive)
                    TextButton.icon(
                      onPressed: () {
                        _service.cancelTimer();
                        AppToast.show(context, '已关闭睡眠定时');
                      },
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                      label: const Text('关闭定时', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                ],
              ),

              // Active status card if running
              if (isActive) ...[
                const SizedBox(height: 12.0),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _service.isEndOfVideoMode ? Icons.stop_circle_outlined : Icons.timer_outlined,
                        color: primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _service.isEndOfVideoMode ? '当前模式：播完本视频后停止' : '定时倒计时中',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            if (_service.isDurationMode) ...[
                              const SizedBox(height: 2),
                              Text(
                                '剩余时间: ${_service.formatRemaining()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSub,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_service.isDurationMode)
                        Text(
                          _service.formatRemaining(),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16.0),
              Text(
                '选择定时模式',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8.0),

              // Presets wrap
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final mins in _presetMinutes) ...[
                    ActionChip(
                      label: Text('$mins 分钟'),
                      backgroundColor: context.colors.fill,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textMain,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onPressed: () {
                        _service.startTimer(Duration(minutes: mins));
                        AppToast.show(context, '已开启 $mins 分钟睡眠定时');
                        Navigator.pop(context);
                      },
                    ),
                  ],
                  ActionChip(
                    avatar: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('自定义'),
                    backgroundColor: context.colors.fill,
                    onPressed: () {
                      Navigator.pop(context);
                      _showCustomMinutesDialog();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12.0),
              // Stop after current video tile
              Material(
                color: context.colors.fill,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.skip_next_rounded,
                    color: _service.isEndOfVideoMode ? primaryColor : (context.colors.textSub),
                  ),
                  title: const Text('播完当前视频后停止', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('当前分P/视频播放结束时自动停止，不再连播下一集', style: TextStyle(fontSize: 11)),
                  trailing: _service.isEndOfVideoMode
                      ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
                      : null,
                  onTap: () {
                    _service.setEndOfVideoMode();
                    AppToast.show(context, '已设置为播完当前视频后自动停止');
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
