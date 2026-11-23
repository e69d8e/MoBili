import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/models/user_model.dart';
import 'package:mobili/providers/theme_provider.dart';
import 'package:mobili/screens/video/widgets/video_watch_later_panel.dart';
import 'package:mobili/services/update/update_check_service.dart';
import 'package:mobili/theme/app_colors.dart';
import 'package:mobili/theme/app_theme.dart';
import 'package:mobili/widgets/app_update_dialog.dart';
import 'package:mobili/widgets/state_views.dart';
import 'package:mobili/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemePreset Tests', () {
    test('Default preset should be ink (黑白水墨)', () {
      expect(AppThemePreset.ink.name, '黑白水墨');
      expect(AppThemePreset.ink.key, 'ink');
      expect(AppThemePreset.fromKey('unknown'), AppThemePreset.ink);
      expect(AppThemePreset.fromKey('ink'), AppThemePreset.ink);
    });

    test('All presets are properly resolved from key', () {
      expect(AppThemePreset.fromKey('pink'), AppThemePreset.biliPink);
      expect(AppThemePreset.fromKey('bamboo'), AppThemePreset.bamboo);
      expect(AppThemePreset.fromKey('porcelain'), AppThemePreset.porcelain);
      expect(AppThemePreset.fromKey('cinnabar'), AppThemePreset.cinnabar);
      expect(AppThemePreset.fromKey('wisteria'), AppThemePreset.wisteria);
    });

    test('lightTheme and darkTheme generate valid ThemeData for each preset', () {
      for (final preset in AppThemePreset.values) {
        final light = AppTheme.lightTheme(preset: preset);
        final dark = AppTheme.darkTheme(preset: preset, isAmoled: false);
        final amoled = AppTheme.darkTheme(preset: preset, isAmoled: true);

        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);
        expect(amoled.brightness, Brightness.dark);
        expect(amoled.scaffoldBackgroundColor, Colors.black);
        expect(light.colorScheme.primary, preset.lightPrimary);
        expect(dark.colorScheme.primary, preset.darkPrimary);
      }
    });

    test('All presets in dark and AMOLED modes meet WCAG AA contrast requirements', () {
      const selected = {WidgetState.selected};
      const unselected = <WidgetState>{};

      for (final preset in AppThemePreset.values) {
        for (final isAmoled in [false, true]) {
          final theme = AppTheme.darkTheme(preset: preset, isAmoled: isAmoled);
          final cs = theme.colorScheme;
          final reason = '${preset.key} (amoled=$isAmoled)';

          expect(cs.secondary, preset.darkSecondary, reason: reason);

          // 主色 / 辅色与其前景文字满足 >= 4.5:1
          expect(_contrastRatio(cs.primary, cs.onPrimary), greaterThanOrEqualTo(4.5), reason: '$reason onPrimary');
          expect(_contrastRatio(cs.secondary, cs.onSecondary), greaterThanOrEqualTo(4.5), reason: '$reason onSecondary');
          expect(_contrastRatio(cs.error, cs.onError), greaterThanOrEqualTo(4.5), reason: '$reason onError');

          // 容器角色（含 70% 透明度叠在卡片底上，如 AI 字幕角标）满足 >= 4.5:1
          expect(_contrastRatio(cs.primaryContainer, cs.onPrimaryContainer), greaterThanOrEqualTo(4.5), reason: '$reason primaryContainer');
          final blendedContainer = Color.alphaBlend(cs.primaryContainer.withValues(alpha: 0.7), cs.surface);
          expect(_contrastRatio(blendedContainer, cs.onPrimaryContainer), greaterThanOrEqualTo(4.5), reason: '$reason blended primaryContainer');
          expect(_contrastRatio(cs.secondaryContainer, cs.onSecondaryContainer), greaterThanOrEqualTo(4.5), reason: '$reason secondaryContainer');

          // 主色 / 辅色 / 提示字在页面底、卡片底、填充底上均可读（>= 4.5:1）
          for (final bg in [theme.scaffoldBackgroundColor, cs.surface, cs.surfaceContainer]) {
            expect(_contrastRatio(cs.primary, bg), greaterThanOrEqualTo(4.5), reason: '$reason primary vs bg');
            expect(_contrastRatio(cs.secondary, bg), greaterThanOrEqualTo(4.5), reason: '$reason secondary vs bg');
            expect(_contrastRatio(cs.onSurface, bg), greaterThanOrEqualTo(4.5), reason: '$reason onSurface vs bg');
            expect(_contrastRatio(theme.hintColor, bg), greaterThanOrEqualTo(4.5), reason: '$reason hintColor vs bg');
          }

          // 分割线在卡片与 fill 上始终保持可见且不倒挂（亮度高于底色）
          final divider = theme.dividerTheme.color!;
          expect(divider.computeLuminance(), greaterThan(cs.surface.computeLuminance()), reason: '$reason divider > surface');
          expect(divider.computeLuminance(), greaterThan(cs.surfaceContainer.computeLuminance()), reason: '$reason divider > fill');

          // Switch 选中态滑块与轨道对比充足，未选中轮廓非纯白且满足非文本边界 >= 3:1
          final thumbOn = theme.switchTheme.thumbColor!.resolve(selected)!;
          final trackOn = theme.switchTheme.trackColor!.resolve(selected)!;
          expect(_contrastRatio(thumbOn, trackOn), greaterThanOrEqualTo(4.5), reason: '$reason switch thumb vs track');
          final outlineOff = theme.switchTheme.trackOutlineColor!.resolve(unselected)!;
          expect(outlineOff, isNot(Colors.white), reason: '$reason switch outline not pure white');
          expect(_contrastRatio(cs.outline, cs.surfaceContainer), greaterThanOrEqualTo(3.0), reason: '$reason outline vs fill >= 3:1');
        }
      }
    });

    test('All presets in light mode meet WCAG AA contrast requirements', () {
      for (final preset in AppThemePreset.values) {
        final theme = AppTheme.lightTheme(preset: preset);
        final cs = theme.colorScheme;
        final reason = '${preset.key} light';

        expect(cs.primary, preset.lightPrimary, reason: reason);
        expect(cs.secondary, preset.secondary, reason: reason);

        expect(_contrastRatio(cs.primary, cs.onPrimary), greaterThanOrEqualTo(4.5), reason: '$reason onPrimary');
        expect(_contrastRatio(cs.secondary, cs.onSecondary), greaterThanOrEqualTo(4.5), reason: '$reason onSecondary');
        expect(_contrastRatio(cs.error, cs.onError), greaterThanOrEqualTo(4.5), reason: '$reason onError');

        for (final bg in [theme.scaffoldBackgroundColor, cs.surface, cs.surfaceContainer]) {
          expect(_contrastRatio(cs.primary, bg), greaterThanOrEqualTo(4.5), reason: '$reason primary vs bg');
          expect(_contrastRatio(cs.secondary, bg), greaterThanOrEqualTo(4.5), reason: '$reason secondary vs bg');
          expect(_contrastRatio(cs.onSurface, bg), greaterThanOrEqualTo(4.5), reason: '$reason onSurface vs bg');
          expect(_contrastRatio(cs.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5), reason: '$reason textSub vs bg');
          expect(_contrastRatio(theme.hintColor, bg), greaterThanOrEqualTo(4.5), reason: '$reason hintColor vs bg');
          expect(_contrastRatio(cs.error, bg), greaterThanOrEqualTo(4.5), reason: '$reason error vs bg');
          expect(_contrastRatio(AppTheme.successLight, bg), greaterThanOrEqualTo(4.5), reason: '$reason successLight vs bg');
          expect(_contrastRatio(AppTheme.warningLight, bg), greaterThanOrEqualTo(4.5), reason: '$reason warningLight vs bg');
        }

        // 浅色轮廓在填充底与卡片底上均满足非文本边界 >= 3.0:1
        expect(_contrastRatio(cs.outline, cs.surfaceContainer), greaterThanOrEqualTo(3.0), reason: '$reason outline vs fill');
        expect(_contrastRatio(cs.outline, cs.surface), greaterThanOrEqualTo(3.0), reason: '$reason outline vs surface');
      }
    });
  });

  group('Dark Mode Widget & Token Tests', () {
    testWidgets('AppColors resolves AMOLED fill, highlight and divider cleanly', (tester) async {
      late AppColors darkColors;
      late AppColors amoledColors;

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('dark'),
          theme: AppTheme.darkTheme(preset: AppThemePreset.ink, isAmoled: false),
          home: Builder(
            builder: (ctx) {
              darkColors = ctx.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('amoled'),
          theme: AppTheme.darkTheme(preset: AppThemePreset.ink, isAmoled: true),
          home: Builder(
            builder: (ctx) {
              amoledColors = ctx.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(darkColors.bg, AppTheme.inkBg);
      expect(darkColors.fill, AppTheme.surfaceDark);
      expect(amoledColors.bg, Colors.black);
      expect(amoledColors.fill, AppTheme.surfaceDarkAmoled);
      expect(amoledColors.fillHighlight, AppTheme.fillHighlightDarkAmoled);
      expect(amoledColors.divider, AppTheme.dividerDarkAmoled);
      expect(
        amoledColors.divider.computeLuminance(),
        greaterThan(amoledColors.fill.computeLuminance()),
      );
    });

    testWidgets('Dark mode FilledButton.tonal uses tonal secondaryContainer instead of primary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(preset: AppThemePreset.bamboo),
          home: Scaffold(
            body: EmptyView(
              message: '空空如也',
              onRetry: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.style?.backgroundColor?.resolve(const {}), isNull);
    });

    testWidgets('Dark mode AppUpdateDialog and WatchLater badge use onPrimary instead of hardcoded white', (tester) async {
      final info = AppUpdateInfo(
        tagName: 'v1.2.3',
        version: '1.2.3',
        title: 'v1.2.3',
        changelog: '修复暗色主题配色',
        htmlUrl: 'https://example.com',
      );
      final items = [
        WatchLaterItem(
          aid: 1,
          bvid: 'BV1test',
          cid: 1,
          title: '测试视频',
          pic: '',
          ownerName: 'UP主',
          ownerFace: '',
          ownerMid: 1,
          duration: 60,
          pubdate: 0,
          addAt: 0,
          progress: 10,
        ),
      ];

      for (final preset in AppThemePreset.values) {
        final theme = AppTheme.darkTheme(preset: preset);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('dlg_${preset.key}'),
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(child: AppUpdateDialog(info: info)),
                  VideoWatchLaterSection(
                    items: items,
                    currentIndex: 0,
                    currentBvid: 'BV1test',
                    onSelectItem: (_, _) {},
                    onTapMore: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        final playingText = tester.widget<Text>(find.text('播放中'));
        expect(playingText.style?.color, theme.colorScheme.onPrimary);
        expect(
          _contrastRatio(playingText.style!.color!, theme.colorScheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.key} playing badge contrast',
        );

        final downloadBtn = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('前往下载'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(downloadBtn.style?.foregroundColor?.resolve(const {}), isNull);
      }
    });

    testWidgets('UserAvatar level badges maintain readable contrast across all levels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(preset: AppThemePreset.ink),
          home: const Scaffold(
            body: Row(
              children: [
                UserAvatar(url: '', level: 1),
                UserAvatar(url: '', level: 2),
                UserAvatar(url: '', level: 3),
                UserAvatar(url: '', level: 4),
                UserAvatar(url: '', level: 5),
                UserAvatar(url: '', level: 6),
              ],
            ),
          ),
        ),
      );

      for (var lvl = 1; lvl <= 6; lvl++) {
        final text = tester.widget<Text>(find.text('Lv$lvl'));
        final container = tester.widget<Container>(
          find.ancestor(of: find.text('Lv$lvl'), matching: find.byType(Container)).first,
        );
        final bg = (container.decoration as BoxDecoration).color!;
        expect(
          _contrastRatio(text.style!.color!, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'Lv$lvl contrast',
        );
      }
    });
  });

  group('ThemeProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ThemeProvider initializes with ink preset by default and predictive back disabled', () async {
      final provider = ThemeProvider();
      await provider.init();

      expect(provider.themePreset, AppThemePreset.ink);
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isAmoled, isFalse);
      expect(provider.enablePredictiveBack, isFalse);
    });

    test('ThemeProvider switches and persists predictive back setting', () async {
      final provider = ThemeProvider();
      await provider.init();

      expect(provider.enablePredictiveBack, isFalse);
      await provider.setPredictiveBack(true);
      expect(provider.enablePredictiveBack, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('enable_predictive_back'), isTrue);

      final newProvider = ThemeProvider();
      await newProvider.init();
      expect(newProvider.enablePredictiveBack, isTrue);
    });

    test('ThemeProvider switches and persists preset', () async {
      final provider = ThemeProvider();
      await provider.init();

      await provider.setThemePreset(AppThemePreset.bamboo);
      expect(provider.themePreset, AppThemePreset.bamboo);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preset'), 'bamboo');

      // Verify new instance loads persisted preset
      final newProvider = ThemeProvider();
      await newProvider.init();
      expect(newProvider.themePreset, AppThemePreset.bamboo);
    });
  });
}
