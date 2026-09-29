import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/listen_video_provider.dart';
import 'providers/search_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_tab_screen.dart';
import 'services/danmaku_settings_service.dart';
import 'services/deep_link_service.dart';
import 'services/player_settings_service.dart';
import 'services/storage/app_cache_service.dart';
import 'services/storage/history_storage_service.dart';
import 'services/storage/video_cache_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure balanced image cache (120MB) to prevent OOM on mid-low tier devices
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 120 << 20; // 120MB

  final authProvider = AuthProvider();
  final homeProvider = HomeProvider();
  final searchProvider = SearchProvider();
  final themeProvider = ThemeProvider();
  final listenVideoProvider = ListenVideoProvider();

  // Load only local persistent caches & settings before initial UI frame.
  // 单个初始化失败不阻断启动（runApp 必须执行），记录告警后继续。
  await Future.wait([
    _initSafely('authLocal', authProvider.initLocal()),
    _initSafely('theme', themeProvider.init()),
    _initSafely('danmakuSettings', DanmakuSettingsService.init()),
    _initSafely('playerSettings', PlayerSettingsService.init()),
    _initSafely('history', HistoryStorageService().init()),
    _initSafely('videoCache', VideoCacheService().init()),
    _initSafely('appCache', AppCacheService().init()),
  ]);

  runApp(
    MoBiliRoot(
      authProvider: authProvider,
      homeProvider: homeProvider,
      searchProvider: searchProvider,
      themeProvider: themeProvider,
      listenVideoProvider: listenVideoProvider,
    ),
  );

  // Defer remote credentials check and network sync to run in background
  unawaited(authProvider.initNetwork());

  // 深度链接（B 站视频/UP 主/搜索链接唤起 App）
  unawaited(DeepLinkService.instance.start(appNavigatorKey));
}

/// 全局 NavigatorKey，供深度链接等服务路由使用
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 包一层启动期初始化：失败只记日志，不阻断 runApp
Future<void> _initSafely(String name, Future<void> init) async {
  try {
    await init;
  } catch (e, s) {
    debugPrint('MoBili: $name init failed (ignored): $e\n$s');
  }
}

class MoBiliRoot extends StatelessWidget {
  final AuthProvider authProvider;
  final HomeProvider homeProvider;
  final SearchProvider searchProvider;
  final ThemeProvider themeProvider;
  final ListenVideoProvider? listenVideoProvider;

  const MoBiliRoot({
    super.key,
    required this.authProvider,
    required this.homeProvider,
    required this.searchProvider,
    required this.themeProvider,
    this.listenVideoProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: homeProvider),
        ChangeNotifierProvider.value(value: searchProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: listenVideoProvider ?? ListenVideoProvider()),
      ],
      child: const MoBiliApp(),
    );
  }
}

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MoBiliApp extends StatelessWidget {
  const MoBiliApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: '墨哩',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      // 允许系统字体放大但设上限，避免大字体下布局裁切
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: AppTheme.lightTheme(
        preset: themeProvider.themePreset,
        enablePredictiveBack: themeProvider.enablePredictiveBack,
      ),
      darkTheme: AppTheme.darkTheme(
        preset: themeProvider.themePreset,
        isAmoled: themeProvider.isAmoled,
        enablePredictiveBack: themeProvider.enablePredictiveBack,
      ),
      themeMode: themeProvider.themeMode,
      home: const MainTabScreen(),
      navigatorObservers: [routeObserver],
    );
  }
}
