import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update/update_check_service.dart';
import '../theme/app_colors.dart';
import 'app_toast.dart';

/// 「发现新版本」弹窗：展示版本号与更新日志，跳转 GitHub Release 页面下载
class AppUpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;

  const AppUpdateDialog({super.key, required this.info});

  static void show(BuildContext context, AppUpdateInfo info) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AppUpdateDialog(info: info),
    );
  }

  Future<void> _openReleasePage(BuildContext context) async {
    final uri = Uri.tryParse(info.htmlUrl);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('launchUrl returned false');
      }
    } catch (_) {
      // 打开浏览器失败时降级为复制链接
      await Clipboard.setData(ClipboardData(text: info.htmlUrl));
      if (context.mounted) {
        AppToast.show(context, '下载链接已复制，请在浏览器中打开', icon: Icons.copy_rounded);
      }
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, size: 22, color: primaryColor),
          const SizedBox(width: 8),
          const Text(
            '发现新版本',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  info.tagName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '当前 ${UpdateCheckService.installedVersionDisplay}',
                  style: TextStyle(fontSize: 12, color: context.colors.textHint),
                ),
              ],
            ),
            if (info.publishedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '发布于 ${_formatDate(info.publishedAt!)}',
                style: TextStyle(fontSize: 11, color: context.colors.textHint),
              ),
            ],
            if (info.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: Text(
                      info.changelog,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.55,
                        color: context.colors.textSub,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '以后再说',
            style: TextStyle(color: context.colors.textSub),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _openReleasePage(context),
          child: const Text('前往下载'),
        ),
      ],
    );
  }

  String _formatDate(DateTime utc) {
    final local = utc.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
