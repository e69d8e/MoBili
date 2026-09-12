import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_toast.dart';

/// Modal dialog for tipping coins to UP author.
class VideoCoinDialog {
  static void show(
    BuildContext context, {
    required int coinCount,
    required void Function(int selectedCoins, bool selectLike) onConfirm,
  }) {
    if (coinCount >= 2) {
      AppToast.show(context, '上限2枚硬币，您已投过2枚硬币啦', icon: Icons.monetization_on_rounded);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    int selectedCoins = 1;
    final maxAvailable = 2 - coinCount;
    bool selectLike = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text('给UP主投币', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coinCount > 0 ? '已投 $coinCount 枚硬币，还能投 $maxAvailable 枚' : '选择投币数量：',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('1 硬币'),
                        selected: selectedCoins == 1,
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: selectedCoins == 1
                              ? Theme.of(context).colorScheme.onPrimary
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: selectedCoins == 1 ? FontWeight.bold : FontWeight.normal,
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setDialogState(() => selectedCoins = 1),
                      ),
                      if (maxAvailable >= 2) ...[
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('2 硬币'),
                          selected: selectedCoins == 2,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: selectedCoins == 2
                                ? Theme.of(context).colorScheme.onPrimary
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: selectedCoins == 2 ? FontWeight.bold : FontWeight.normal,
                          ),
                          showCheckmark: false,
                          onSelected: (_) => setDialogState(() => selectedCoins = 2),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => setDialogState(() => selectLike = !selectLike),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selectLike,
                            activeColor: primaryColor,
                            onChanged: (val) => setDialogState(() => selectLike = val ?? true),
                          ),
                          const Text('同时点赞视频', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('取消', style: TextStyle(color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight)),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onConfirm(selectedCoins, selectLike);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('确定投币'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
