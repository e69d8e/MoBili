import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'app_toast.dart';

/// 视频分享面板：对齐官方客户端「分享」底部弹层。
///
/// 不引入 share_plus：用系统剪贴板 + url_launcher 覆盖复制链接、复制标题和链接、
/// 复制 BV 号、浏览器打开四类真实可用的动作，避免摆出点了没反应的假分享入口。
class VideoShareSheet {
  static String videoUrl(String bvid) => 'https://www.bilibili.com/video/$bvid';

  static void show(
    BuildContext context, {
    required String bvid,
    required String title,
  }) {
    final url = videoUrl(bvid);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VideoShareSheetBody(bvid: bvid, title: title, url: url),
    );
  }
}

class _VideoShareSheetBody extends StatelessWidget {
  final String bvid;
  final String title;
  final String url;

  const _VideoShareSheetBody({
    required this.bvid,
    required this.title,
    required this.url,
  });

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppToast.show(context, message, icon: Icons.copy_rounded);
    Navigator.of(context).pop();
  }

  Future<void> _openInBrowser(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('launchUrl returned false');
      }
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      // 没有可用浏览器时降级为复制链接（与 AppUpdateDialog 保持一致）
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      AppToast.show(context, '链接已复制，请在浏览器中打开', icon: Icons.copy_rounded);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final entries = <_ShareEntry>[
      _ShareEntry(
        Icons.copy_all_rounded,
        '复制链接',
        () => _copy(context, url, '视频链接已复制'),
      ),
      _ShareEntry(
        Icons.article_outlined,
        '复制标题和链接',
        () => _copy(context, '$title\n$url', '标题和链接已复制'),
      ),
      _ShareEntry(
        Icons.qr_code_2_rounded,
        '复制 BV 号',
        () => _copy(context, bvid, 'BV 号已复制'),
      ),
      _ShareEntry(
        Icons.open_in_browser_rounded,
        '浏览器打开',
        () => _openInBrowser(context),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部把手，提示这是一个可下滑关闭的浮层
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '分享视频',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.textSub),
            ),
            const SizedBox(height: 20),
            Row(
              children: entries
                  .map(
                    (entry) => Expanded(
                      child: _ShareTile(entry: entry, colors: colors),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            // 链接预览，整行可点即复制
            Material(
              color: colors.fill,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _copy(context, url, '视频链接已复制'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 18, color: colors.textSub),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.textSub),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.copy_rounded, size: 16, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('取消', style: TextStyle(color: colors.textSub)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareEntry(this.icon, this.label, this.onTap);
}

class _ShareTile extends StatelessWidget {
  final _ShareEntry entry;
  final AppColors colors;

  const _ShareTile({required this.entry, required this.colors});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.fill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(entry.icon, size: 22, color: colors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textSub),
            ),
          ],
        ),
      ),
    );
  }
}
