import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/responsive_util.dart';
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

class _MainTabScreenState extends State<MainTabScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  final Set<int> _activatedTabs = {0};
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<DynamicScreenState> _dynamicKey =
      GlobalKey<DynamicScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildTab(int index) {
    if (!_activatedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return HomeScreen(key: _homeKey);
      case 1:
        return DynamicScreen(key: _dynamicKey);
      case 2:
        return ProfileScreen(key: _profileKey);
      default:
        return const SizedBox.shrink();
    }
  }

  void _onSelectTab(int index) {
    HapticFeedback.selectionClick();
    if (_currentIndex == index) {
      if (index == 0) {
        _homeKey.currentState?.refreshAndScrollToTop();
      } else if (index == 1) {
        _dynamicKey.currentState?.refreshAndScrollToTop();
      } else if (index == 2) {
        _profileKey.currentState?.scrollToTop();
      }
      return;
    }

    setState(() {
      _activatedTabs.add(index);
      _currentIndex = index;
    });
    _fadeController.forward(from: 0.35);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useRail = screenWidth >= 600;
    final extendRail = screenWidth >= 960;

    final bodyContent = FadeTransition(
      opacity: _fadeAnimation,
      child: IndexedStack(
        index: _currentIndex,
        children: [
          _buildTab(0),
          _buildTab(1),
          _buildTab(2),
        ],
      ),
    );

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
        body: useRail
            ? Row(
                children: [
                  SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: _currentIndex,
                      extended: extendRail,
                      labelType: extendRail
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      indicatorColor: primaryColor.withValues(alpha: 0.15),
                      selectedIconTheme: IconThemeData(color: primaryColor),
                      unselectedIconTheme: IconThemeData(
                        color: context.colors.textSub,
                      ),
                      selectedLabelTextStyle: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelTextStyle: TextStyle(
                        color: context.colors.textSub,
                        fontSize: 12,
                      ),
                      onDestinationSelected: _onSelectTab,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: Text('首页'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.dynamic_feed_outlined),
                          selectedIcon: Icon(Icons.dynamic_feed_rounded),
                          label: Text('动态'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: Text('我的'),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 0.6,
                    color: context.colors.divider,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: bodyContent),
                        const ResponsiveMaxConstraint(
                          maxWidth: 680,
                          child: MiniAudioPlayer(),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : bodyContent,
        bottomNavigationBar: useRail
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: context.colors.divider,
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
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      elevation: 0,
                      onDestinationSelected: _onSelectTab,
                      destinations: [
                        NavigationDestination(
                          icon: Icon(
                            Icons.home_outlined,
                            size: 22,
                            color: context.colors.textSub,
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
                            color: context.colors.textSub,
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
                            color: context.colors.textSub,
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
