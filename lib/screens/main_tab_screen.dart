import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/audio/mini_audio_player.dart';
import 'dynamic/dynamic_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

class MainTabScreen extends StatefulWidget {
  final DateTime Function()? nowProvider;
  const MainTabScreen({super.key, this.nowProvider});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<DynamicScreenState> _dynamicKey =
      GlobalKey<DynamicScreenState>();

  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    DynamicScreen(key: _dynamicKey),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final now = widget.nowProvider?.call() ?? DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          AppToast.show(context, '再次返回退出应用');
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                width: 0.6,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniAudioPlayer(),
              NavigationBar(
                selectedIndex: _currentIndex,
                height: 58,
                backgroundColor: Colors.transparent,
                indicatorColor: primaryColor.withValues(alpha: 0.15),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                elevation: 0,
                onDestinationSelected: (index) {
                  HapticFeedback.selectionClick();
                  if (_currentIndex == index) {
                    if (index == 0) {
                      _homeKey.currentState?.refreshAndScrollToTop();
                    } else if (index == 1) {
                      _dynamicKey.currentState?.refreshAndScrollToTop();
                    }
                  } else {
                    setState(() {
                      _currentIndex = index;
                    });
                  }
                },
                destinations: [
                  NavigationDestination(
                    icon: Icon(
                      Icons.home_outlined,
                      size: 22,
                      color: isDark
                          ? AppTheme.textSubDark
                          : AppTheme.textSubLight,
                    ),
                    selectedIcon: Icon(
                      Icons.home_rounded,
                      size: 22,
                      color: primaryColor,
                    ),
                    label: '首页',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.dynamic_feed_outlined,
                      size: 22,
                      color: isDark
                          ? AppTheme.textSubDark
                          : AppTheme.textSubLight,
                    ),
                    selectedIcon: Icon(
                      Icons.dynamic_feed_rounded,
                      size: 22,
                      color: primaryColor,
                    ),
                    label: '动态',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.person_outline_rounded,
                      size: 22,
                      color: isDark
                          ? AppTheme.textSubDark
                          : AppTheme.textSubLight,
                    ),
                    selectedIcon: Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: primaryColor,
                    ),
                    label: '我的',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
