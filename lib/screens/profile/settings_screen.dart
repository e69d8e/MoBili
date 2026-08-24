import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('外观与设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        children: [
          // App Brand Header
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '墨哩 MoBili',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '极简水墨 · 沉浸哔哩',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section: Theme Presets
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '主题配色',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < AppThemePreset.values.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 52,
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                    ),
                  _buildPresetTile(
                    context: context,
                    preset: AppThemePreset.values[i],
                    isSelected: themeProvider.themePreset == AppThemePreset.values[i],
                    isDark: isDark,
                    onTap: () => themeProvider.setThemePreset(AppThemePreset.values[i]),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Theme Mode (Light / Dark / AMOLED)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '显示模式',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildThemeOption(
                  context: context,
                  title: '跟随系统',
                  isSelected: themeProvider.themeMode == ThemeMode.system,
                  primaryColor: primaryColor,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                _buildThemeOption(
                  context: context,
                  title: '浅色模式',
                  isSelected: themeProvider.themeMode == ThemeMode.light,
                  primaryColor: primaryColor,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                _buildThemeOption(
                  context: context,
                  title: '深色模式',
                  isSelected: themeProvider.themeMode == ThemeMode.dark,
                  primaryColor: primaryColor,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('AMOLED 纯黑模式', style: TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    '深色模式下使用极致纯黑背景，更沉浸省电',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                  value: themeProvider.isAmoled,
                  activeTrackColor: primaryColor,
                  onChanged: (val) => themeProvider.setAmoled(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: About
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '关于墨哩',
              style: TextStyle(
                color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: const Text('软件版本', style: TextStyle(fontSize: 13.5)),
                  trailing: Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
                ),
                ListTile(
                  dense: true,
                  title: const Text('技术栈', style: TextStyle(fontSize: 13.5)),
                  trailing: Text(
                    'Flutter + Bili WBI API',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetTile({
    required BuildContext context,
    required AppThemePreset preset,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activePrimary = isDark ? preset.darkPrimary : preset.lightPrimary;

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              preset.previewColors[0],
              preset.previewColors[1],
            ],
          ),
          border: Border.all(
            color: isSelected
                ? activePrimary
                : (isDark ? Colors.white24 : Colors.black12),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activePrimary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
      title: Row(
        children: [
          Text(
            preset.name,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppTheme.textMainDark : activePrimary)
                  : (isDark ? AppTheme.textMainDark : AppTheme.textMainLight),
            ),
          ),
          if (preset == AppThemePreset.ink) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '默认',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textSubDark : AppTheme.textSubLight,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        preset.description,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? AppTheme.textHintDark : AppTheme.textHintLight,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: activePrimary, size: 20)
          : null,
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: primaryColor, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
