<div align="center">

<img src="assets/icons/app_icon.png" alt="MoBili Logo" width="128" height="128" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);" />

# 墨哩 (MoBili) 🎬

**水墨禅意 · 现代化哔哩哔哩第三方客户端**

*An elegant, lightweight, and modern cross-platform Bilibili client crafted with Zen ink aesthetics.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-blue?style=for-the-badge)](https://github.com/e69d8e/MoBili)
[![CI](https://img.shields.io/github/actions/workflow/status/e69d8e/MoBili/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/e69d8e/MoBili/actions)
[![Release](https://img.shields.io/github/v/release/e69d8e/MoBili?style=for-the-badge&color=success)](https://github.com/e69d8e/MoBili/releases)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 📖 简介 / Overview

**墨哩 (MoBili)** 是一款基于 Flutter 构建的现代化、跨平台哔哩哔哩（Bilibili）第三方客户端。

秉承**“水墨禅意、极简克制、纯粹沉浸”**的设计哲学，去除繁杂冗余的广告与商业信息，还原最纯粹的视频与弹幕视听体验。支持移动端与桌面端自适应布局、高清视频播放、高性能弹幕渲染、听视频后台音频播放、UP主动态流与个人中心等多项核心功能。

---

## ✨ 核心特性 / Features

### 🎨 1. 水墨禅意与东方美学主题
- **多套雅致传统色系预设**：
  - 🖤 **黑白水墨 (Ink)**：经典宣纸水墨黑白，克制典雅。
  - 🎍 **竹青 (Bamboo)**：清新淡雅的自然竹韵。
  - 🌊 **黛蓝 (Indigo)**：深邃静谧的古韵黛色。
  - 🌸 **胭脂 (Rouge)**：温婉内敛的中式古典红。
  - 🍂 **藤黄 (Gamboge)**：温润明快的东方暖色调。
- **暗黑与深邃模式**：支持系统自适应跟随、深色模式及 **AMOLED 纯黑模式**（全黑省电体验）。
- **自适应响应式布局**：完美适配 Android 手机/平板、macOS、Windows 和 Linux 桌面宽屏交互。

### 🎬 2. 沉浸式高清视频播放系统
- **高清流媒体播放**：支持多种清晰度自适应播放与分P分集列表无缝切换。
- **手势交互体验**：左侧上下滑动调亮度、右侧上下滑动调音量、左右拖拽毫秒级精准快进快退。
- **多倍速播放**：0.5x ~ 2.0x 无级变速播放。
- **智能屏幕常亮**：结合 Wakelock 保持播放过程屏幕常亮不熄灭。

### 💬 3. 高性能丝滑弹幕系统
- **全类型弹幕解析**：原生解析 Bilibili 弹幕协议，支持滚动弹幕、顶部固定与底部固定弹幕。
- **弹幕视觉自由定制**：
  - 弹幕透明度调节 (0% ~ 100%)
  - 弹幕字号缩放比例 (0.7x ~ 1.5x)
  - 弹幕同屏显示区域限制 (1/4屏、半屏、3/4屏、全屏)
  - 一键快速开启/隐藏弹幕，配置全量本地持久化保存。

### 🎧 4. 听视频与后台音频模式 (Listen Mode)
- **熄屏/后台听视频**：纯音频抽取流播放，节省流量与电量，适合听播客、相声、音乐或演讲。
- **全局常驻 Mini 音频条与播放列表**：支持随时折叠与展开全屏听视频播放器，无缝进度控制、稍后再看队列连续自动播放与播放模式切换（顺序/单曲/随机）。

### 💾 5. 离线缓存与存储深度管理 (Storage & Cache)
- **视频分清晰度离线下载**：支持后台多任务断点续传与下载进度实时监控。
- **全方位缓存可视化管理**：一键智能计算与清理图片缓存、临时音频缓存、离线视频与本地播放历史，支持自定义自动清理阈值。
- **本地无网沉浸播放**：离线视频播放器独立支持手势调光调音、倍速调节与断点续播。

### 📱 6. 动态社区与全景互动
- **UP 主动态流**：综合动态、视频投稿与图文动态瀑布流实时拉取。
- **互动体验**：转发、评论与点赞信息展示，支持查看高清多图画廊与手势缩放浏览。
- **热门评论区**：支持主评论与二级楼中楼展开回复浏览。

### 🔍 7. 综合检索与热点探索
- **多类型搜索聚合**：支持综合、视频、番剧、UP主、动态等多维度筛选。
- **实时热搜榜**：官方热搜排行榜实时更新与搜索历史便捷管理。

### 👤 8. 个人中心与快捷登录
- **安全扫码登录**：通过官方二维码安全扫码登录，无需手动输入账号密码。
- **完备个人数据流**：支持查看个人历史播放记录、稍后再看列表、收藏夹分类及关注/粉丝列表。
- **UP 主空间主页**：查看 UP 主投稿视频、个人资料与统计数据。

### 🛡️ 9. 官方 WBI 鉴权加密
- 内置 **Bilibili WBI API** 最新安全加密签名机制与 Mixin Key 混淆算法，保障 API 稳定可靠请求与数据保真。

---

## 🛠️ 技术栈 / Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Networking**: [Dio](https://pub.dev/packages/dio) + Custom Interceptors
- **Video Engine**: [video_player](https://pub.dev/packages/video_player)
- **Audio Engine**: [just_audio](https://pub.dev/packages/just_audio) + [audio_session](https://pub.dev/packages/audio_session)
- **Image & Caching**: [cached_network_image](https://pub.dev/packages/cached_network_image)
- **Persistence**: [shared_preferences](https://pub.dev/packages/shared_preferences)
- **CI/CD**: GitHub Actions (全平台多架构自动化矩阵打包与发布)

---

## 📦 下载与安装 / Download

访问 [GitHub Releases](https://github.com/e69d8e/MoBili/releases) 获取各平台最新版本安装包：

| 平台 | 安装包格式 | 说明 |
| :--- | :--- | :--- |
| **Android** | `.apk` / `.aab` | 支持 arm64-v8a、armeabi-v7a、x86_64 及 Universal 通用包 |
| **macOS** | `.dmg` / `.zip` | 支持 Apple Silicon / Intel 架构 |
| **Windows** | `.exe` / `.zip` | 提供 Inno Setup 安装向导与免安装绿色便携版 |
| **Linux** | `.deb` / `.tar.gz` | 提供 Debian/Ubuntu 安装包及通用独立运行包 |

---

## 🚀 本地开发与构建 / Development

### 1. 环境准备
- 安装 [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.13.0`)
- 安装对应平台的构建工具链（Xcode / Android Studio / Visual Studio / GCC & CMake）

### 2. 克隆项目与安装依赖
```bash
git clone https://github.com/e69d8e/MoBili.git
cd MoBili
flutter pub get
```

### 3. 运行单元测试
```bash
flutter test
```

### 4. 本地启动运行
```bash
# 启动桌面端 / 模拟器
flutter run
```

---

## 🤝 免责声明 / Disclaimer

1. **墨哩 (MoBili)** 是一个开源、非营利的第三方哔哩哔哩学习与交流项目，与上海宽娱数码科技有限公司（Bilibili）无任何隶属或商业合作关系。
2. 项目中涉及的所有媒体、视频、动态及接口数据版权均归哔哩哔哩及其原作者所有。
3. 请勿将本项目用于任何商业盈利或侵犯他人合法权益的用途。

---

## 📄 开源许可 / License

本项目采用 [MIT License](LICENSE) 许可协议。
