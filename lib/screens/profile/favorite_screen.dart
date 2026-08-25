import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/video_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/user_api_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/video_card.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<FavFolder> _folders = [];
  FavFolder? _selectedFolder;
  List<VideoItem> _folderVideos = [];
  bool _isLoading = true;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    final mid = context.read<AuthProvider>().userInfo.mid;
    if (mid > 0) {
      final folders = await UserApiService().getUserFavFolders(mid);
      if (mounted) {
        setState(() {
          _folders = folders;
          _isLoading = false;
        });
        if (folders.isNotEmpty) {
          _selectFolder(folders.first);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectFolder(FavFolder folder) async {
    setState(() {
      _selectedFolder = folder;
      _isVideoLoading = true;
    });

    final videos = await UserApiService().getFavFolderVideos(folder.id);
    if (mounted) {
      setState(() {
        _folderVideos = videos;
        _isVideoLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: _isLoading
          ? const LoadingView(message: '正在加载收藏夹...')
          : _folders.isEmpty
              ? const EmptyView(message: '暂无收藏夹或未登录', icon: Icons.star_border_rounded)
              : Column(
                  children: [
                    // Folders Selector Bar
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: _folders.length,
                        separatorBuilder: (ctx, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final folder = _folders[idx];
                          final isSelected = _selectedFolder?.id == folder.id;
                          final primaryColor = Theme.of(context).colorScheme.primary;
                          final onPrimary = Theme.of(context).colorScheme.onPrimary;
                          return ChoiceChip(
                            label: Text('${folder.title} (${folder.mediaCount})'),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected ? onPrimary : (isDark ? Colors.white70 : Colors.black87),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: isDark ? const Color(0xFF222228) : const Color(0xFFF1F2F3),
                            side: BorderSide.none,
                            onSelected: (_) => _selectFolder(folder),
                          );
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? const Color(0xFF26262B) : const Color(0xFFEEEEEE),
                    ),
                    // Videos Grid
                    Expanded(
                      child: _isVideoLoading
                          ? const LoadingView(message: '加载收藏内容...')
                          : _folderVideos.isEmpty
                              ? const EmptyView(message: '该收藏夹暂无视频')
                              : GridView.builder(
                                  cacheExtent: 500.0,
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.95,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: _folderVideos.length,
                                  itemBuilder: (ctx, idx) => RepaintBoundary(
                                    child: VideoCard(
                                      video: _folderVideos[idx],
                                      showViewCount: false,
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
    );
  }
}
