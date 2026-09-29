import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/user_model.dart';
import '../../../services/api/user_api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/state_views.dart';

/// Bottom sheet for adding/removing video to/from user favorite folders.
class VideoFavoriteFolderSheet extends StatefulWidget {
  final int aid;
  final int mid;
  final bool isDark;
  final Color primaryColor;
  final void Function(bool isFav) onFavStatusChanged;

  const VideoFavoriteFolderSheet({
    super.key,
    required this.aid,
    required this.mid,
    required this.isDark,
    required this.primaryColor,
    required this.onFavStatusChanged,
  });

  static void show(
    BuildContext context, {
    required int aid,
    required int mid,
    required bool isDark,
    required Color primaryColor,
    required void Function(bool isFav) onFavStatusChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return VideoFavoriteFolderSheet(
          aid: aid,
          mid: mid,
          isDark: isDark,
          primaryColor: primaryColor,
          onFavStatusChanged: onFavStatusChanged,
        );
      },
    );
  }

  @override
  State<VideoFavoriteFolderSheet> createState() => _VideoFavoriteFolderSheetState();
}

class _VideoFavoriteFolderSheetState extends State<VideoFavoriteFolderSheet> {
  List<FavFolder> _folders = [];
  Set<int> _initialSelectedFolderIds = {};
  Set<int> _selectedFolderIds = {};
  bool _isLoading = true;
  bool _loadError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    List<FavFolder> folders;
    try {
      folders = await UserApiService().getUserFavFolders(widget.mid, rid: widget.aid);
      _loadError = false;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = true;
      });
      return;
    }
    if (mounted) {
      final selected = <int>{};
      for (final f in folders) {
        if (f.isFav) {
          selected.add(f.id);
        }
      }
      setState(() {
        _folders = folders;
        _initialSelectedFolderIds = Set.from(selected);
        _selectedFolderIds = Set.from(selected);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFavorites() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final addIds = _selectedFolderIds.difference(_initialSelectedFolderIds).toList();
    final delIds = _initialSelectedFolderIds.difference(_selectedFolderIds).toList();

    if (addIds.isEmpty && delIds.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final success = await UserApiService().dealVideoFavorite(
      aid: widget.aid,
      addMediaIds: addIds,
      delMediaIds: delIds,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        final isFav = _selectedFolderIds.isNotEmpty;
        widget.onFavStatusChanged(isFav);
        Navigator.of(context).pop();
        AppToast.show(
          context,
          isFav ? '已更新收藏' : '已取消收藏',
          icon: isFav ? Icons.star_rounded : Icons.info_outline_rounded,
        );
        HapticFeedback.lightImpact();
      } else {
        AppToast.show(context, '操作失败，请重试', icon: Icons.info_outline_rounded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = widget.primaryColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                const Text(
                  '添加到收藏夹',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!_isLoading)
                  TextButton(
                    onPressed: _isSubmitting ? null : _saveFavorites,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          )
                        : Text(
                            '完成',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),

          // Folder List
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: LoadingView(message: '正在获取收藏夹...'),
                  )
                : _folders.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: _loadError
                            ? ErrorView(message: '收藏夹获取失败', onRetry: _loadFolders)
                            : const EmptyView(message: '暂无收藏夹'),
                      )
                    : ListView.separated(
                        // 长列表懒加载；短列表保持 shrinkWrap 以免弹窗被撑满
                        shrinkWrap: _folders.length <= 12,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _folders.length,
                        separatorBuilder: (ctx, _) => Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 16,
                          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                        ),
                        itemBuilder: (ctx, idx) {
                          final folder = _folders[idx];
                          final isSelected = _selectedFolderIds.contains(folder.id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedFolderIds.remove(folder.id);
                                } else {
                                  _selectedFolderIds.add(folder.id);
                                }
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.folder_special_rounded : Icons.folder_outlined,
                                    size: 24,
                                    color: isSelected ? primaryColor : (isDark ? AppTheme.textHintDark : AppTheme.textHintLight),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folder.title,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isDark ? AppTheme.textMainDark : AppTheme.textMainLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${folder.mediaCount} 个内容',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedFolderIds.add(folder.id);
                                        } else {
                                          _selectedFolderIds.remove(folder.id);
                                        }
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
