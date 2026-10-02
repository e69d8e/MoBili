/// Global application constants and version metadata
class AppConstants {
  static const String appName = '墨哩 MoBili';
  static const String appShortName = '墨哩';
  // 运行时真实版本号由 package_info_plus 读取（见 UpdateCheckService），
  // 此处仅作读取失败时的兜底，注意与 pubspec.yaml 的 version 保持一致
  static const String appVersion = 'v1.0.8';
  static const int appBuildNumber = 9;
  static const String appSlogan = '极简水墨 · 沉浸哔哩';
  static const String techStack = 'Flutter + Bili WBI API';

  static String get versionDisplay => '$appVersion (Build $appBuildNumber)';
}
