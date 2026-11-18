import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/user_model.dart';
import '../../../services/api/user_api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/state_views.dart';

/// 一键收藏的提交计划：把「目标收藏状态」翻译成接口的增删收藏夹列表。
///
/// 抽成纯数据结构是为了让这段决策可以脱离网络单独测试，
/// 也让单击收藏与长按面板共用同一套收藏夹判定规则。
class QuickFavoritePlan {
  const QuickFavoritePlan({
    required this.addIds,
    required this.delIds,
    required this.alreadySatisfied,
  });

  final List<int> addIds;
  final List<int> delIds;

  /// 目标状态已由现有收藏夹满足，无需再向接口发请求。
  final bool alreadySatisfied;

  bool get hasChange => addIds.isNotEmpty || delIds.isNotEmpty;
}

/// Bottom sheet for adding/removing video to/from user favorite folders.
class VideoFavoriteFolderSheet extends StatefulWidget {
  final int aid;
  final int mid;
  final Color primaryColor;
  final void Function(bool isFav) onFavStatusChanged;

  const VideoFavoriteFolderSheet({
    super.key,
    required this.aid,
    required this.mid,
    required this.primaryColor,
    required this.onFavStatusChanged,
  });

  /// 计算一键收藏（单击）需要提交的收藏夹增量。
  ///
  /// 默认收藏夹取列表首个：B 站按创建时间返回，账号最早的「默认收藏夹」排第一。
  /// 取消收藏时把视频从所有已收藏的收藏夹中移除，避免只清掉一个仍显示已收藏。
  /// 返回 hasChange=false 时表示无收藏夹可用，调用方应回退到收藏夹面板。
  static QuickFavoritePlan planQuickToggle(
    List<FavFolder> folders, {
    required bool targetFav,
  }) {
    if (folders.isEmpty) {
      return const QuickFavoritePlan(
        addIds: [],
        delIds: [],
        alreadySatisfied: false,
      );
    }
    final alreadyIn =
        folders.where((f) => f.isFav).map((f) => f.id).toList();
    if (targetFav) {
      // 关系接口可能落后于收藏夹列表，已在任意收藏夹中就不再重复添加
      return QuickFavoritePlan(
        addIds: alreadyIn.isEmpty ? [folders.first.id] : <int>[],
        delIds: const [],
        alreadySatisfied: alreadyIn.isNotEmpty,
      );
    }
    return QuickFavoritePlan(
      addIds: const [],
      delIds: alreadyIn,
      alreadySatisfied: alreadyIn.isEmpty,
    );
  }

  static void show(
    BuildContext context, {
    required int aid,
    required int mid,
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
    final primaryColor = widget.primaryColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 12.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '添加到收藏夹',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '单击收藏按钮可一键收藏到默认收藏夹',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading)
                  TextButton(
                    onPressed: _isSubmitting ? null : _saveFavorites,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                              fontWeight: FontWeight.w600,
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
            color: context.colors.divider,
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
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: _folders.length,
                        separatorBuilder: (ctx, _) => Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 16,
                          color: context.colors.divider,
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
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.folder_special_rounded : Icons.folder_outlined,
                                    size: 24,
                                    color: isSelected ? primaryColor : (context.colors.textHint),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folder.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: context.colors.textMain,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${folder.mediaCount} 个内容',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.colors.textHint,
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
