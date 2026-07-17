---
title: 技术栈选择与规范
description: 项目使用最简单、最健壮的技术栈。实施过程中可引入更多技术，但所有文件必须落地到项目中，禁止在 /tmp 目录操作。
---

# 技术栈选择与规范

## 核心技术栈

| 层 | 技术 | 版本 | 说明 |
|---|---|---|---|
| 语言 | **Dart** | `>=3.6.0 <4.0.0` | 空安全，支持 records/patterns |
| 框架 | **Flutter** | `3.41.5`（FVM 锁定） | 跨平台 UI |
| 版本管理 | **FVM** | — | `fvm flutter` / `fvm dart` 前缀 |
| 状态管理 | **Provider** | `^6.0.3` | DI + ChangeNotifier |
| 响应式流 | **RxDart** | `^0.28.0` | BehaviorSubject / PublishSubject |
| 音频引擎 | **just_audio** | `^0.10.4` | 核心音频播放 |
| 后台播放 | **audio_service** | `^0.18.18` | Android Service / iOS 远程控制 |
| 本地数据库 | **sembast** | `^3.8.3` | NoSQL 文档数据库 |
| 键值存储 | **shared_preferences** | `^2.3.4` | 简单设置存储 |
| 播客搜索 | **podcast_search** | `^0.7.15` | iTunes + PodcastIndex |
| 通知 | **awesome_notifications** | `^0.10.0` | 本地通知 |
| 国际化 | **intl** + **intl_translation** | `intl: >=0.19.0 <0.21.0` | 10 种语言 |

## 构建与工具链

### FVM（Flutter Version Management）

项目通过 `.fvmrc` 和 `.fvm/fvm_config.json` 锁定 Flutter `3.41.5`。

```bash
# 所有 flutter/dart 命令加 fvm 前缀
fvm flutter pub get
fvm flutter run
fvm flutter test
fvm dart format --line-length 120 .
```

### 编译时变量（--dart-define）

在 `lib/core/environment.dart` 中定义，运行时不可变：

| 变量 | 用途 | 默认值 |
|---|---|---|
| `PINDEX_KEY` | PodcastIndex API 密钥 | `''` |
| `PINDEX_SECRET` | PodcastIndex API 密钥 | `''` |
| `USER_AGENT` | 自定义 UA | `''`（自动生成） |
| `FEEDBACK_URL` | 反馈表单链接 | `''`（不显示） |

使用方式：`flutter run --dart-define=PINDEX_KEY=xxx --dart-define=PINDEX_SECRET=xxx`

### CI/CD

- **Codemagic** — 构建发布（README badge）
- **GitHub Actions** — `.github/workflows/dart.yml`：`pub get` → `test` → `build apk --debug` → `build appbundle --debug`

## 代码规范

### 格式化

```bash
fvm dart format --line-length 120 .
```

项目使用 **120 字符**而非 Flutter 默认 80 字符。从 `analysis_options.yaml` 设置：
```yaml
formatter:
  page_width: 120
```

### 代码分析

```bash
fvm flutter analyze
```

规则：`package:flutter_lints/flutter.yaml`（v4，Flutter 推荐规则集）

排除分析（`analysis_options.yaml`）：
```yaml
analyzer:
  exclude: [ build/**, lib/**/*.g.dart, lib/l10n/** ]
```

### 代码风格约定

- 文件名：`snake_case.dart`
- 类名：`PascalCase`
- 变量/方法：`camelCase`
- 常量：`lowerCamelCase`（Dart 惯例）或 `UPPER_CASE`（枚举值）
- 抽象类前缀：无固定前缀（如 `AudioPlayerService`）
- 实现类前缀：`Mobile*`（如 `MobilePodcastApi`）
- 导入顺序：dart: → package: → 项目内

## 关键依赖详情

### 音频播放（`lib/services/audio/`）

```yaml
audio_service: ^0.18.18    # 平台级后台播放、锁屏控制
just_audio: ^0.10.4        # 实际音频引擎，支持流媒体、本地文件
audio_session: ^0.2.3      # 音频焦点管理（来电暂停等）
```

三个库的关系：
1. `just_audio` 提供底层播放能力（ConcatenatingAudioSource 支持队列）
2. `audio_service` 包装为平台 Service（Android 前台通知、iOS RemoteCommand）
3. `audio_session` 处理音频焦点冲突
4. `DefaultAudioPlayerService` 封装三层，对外暴露简单接口

### 数据持久化（`lib/repository/sembast/`）

```yaml
sembast: ^3.8.3            # NoSQL 数据库
path_provider: ^2.1.4      # 获取应用文档目录
```

- 数据模型实现 `Persistable` 接口（`toMap()` / `fromMap()`）
- `@Transient()` 注解标记不持久化的字段
- 上层 `SembastRepository` 维护 `Map<String, Podcast>` 等内存缓存

### 下载（`lib/services/download/`）

```yaml
flutter_downloader: ^1.12.0   # 原生下载管理
permission_handler: ^12.0.0+1  # 存储权限
```

- `MobileDownloadManager` 封装原生下载队列
- `MobileDownloadService` 管理下载任务生命周期

### 用户界面

```yaml
flutter_html: ^3.0.0         # 显示笔记 HTML 渲染
extended_image: ^9.1.0       # 图片缓存、缩放、圆角
auto_size_text: ^3.0.0       # 自动调整字号
flutter_spinkit: ^5.0.0      # 加载动画
percent_indicator: 4.2.5     # 进度指示器
scrollable_positioned_list: ^0.3.7  # 滚动到指定位置的列表
sliver_tools: ^0.2.12        # Sliver 布局工具
share_plus: ^11.0.0          # 分享功能
url_launcher: ^6.3.1         # 打开外部链接
```

### 设备 & 平台

```yaml
connectivity_plus: ^6.0.11   # 网络状态检测
device_info_plus: ^11.3.0    # 设备信息
wakelock_plus: ^1.4.0       # 防止屏幕休眠（播放时）
app_links: ^6.3.0           # 深链接（subscribe?url= 格式）
file_picker: ^10.0.0        # 文件选择（OPML 导入）
background_fetch: ^1.5.0    # 后台数据刷新
```

### 测试

```yaml
# dev_dependencies
flutter_test:                # Flutter SDK 内置
mockito: ^5.2.0             # 接口 mock
flutter_lints: ^4.0.0       # lint 规则
```

测试文件结构：
```
test/
├── unit/
│   ├── bloc/
│   │   └── timeline_bloc_test.dart   # 时间线 BLoC：分页、排序、日期筛选、错误处理
│   ├── core/environment_test.dart
│   ├── navigation/navigation_route_observer_test.dart
│   ├── persistence/sembast_test.dart
│   ├── opml/opml_service_test.dart
│   └── services/settings_test.dart
│   └── mocks/
│       ├── mock_notification_service.dart
│       ├── mock_path_provider.dart
│       ├── mock_podcast_api.dart
│       └── mock_settings_service.dart
test_resources/
├── opml_import_test1.opml  # OPML 测试用例
└── podcast1.rss            # RSS 测试用例
```

测试模式：使用 Mock 类注入替代真实 Service 和 API，验证 BLoC 和 Service 的逻辑。

### 国际化

```yaml
intl: '>=0.19.0 <0.21.0'
intl_translation: ^0.20.0
```

支持 10 种语言：
- 简体中文（zh_Hans） | 荷兰语（nl） | 英语（en） | 加利西亚语（gl） | 德语（de）
- 意大利语（it） | 俄语（ru） | 西班牙语（es） | 土耳其语（tr） | 越南语（vi）

翻译流程：
1. 在 `lib/l10n/L.dart` 中定义消息
2. `fvm dart run intl_translation:extract_to_arb --output-dir=lib/l10n lib/l10n/L.dart` 生成 ARB
3. 翻译 `.arb` 文件（Weblate 协作翻译平台可用）
4. `fvm dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/l10n/L.dart lib/l10n/intl_*.arb` 生成 Dart 绑定

## 平台兼容性

### Android

- 最低 SDK 版本：由 flutter_downloader 等插件决定
- 构建产物：APK（`flutter build apk`） + App Bundle（`flutter build appbundle`）
- 分发渠道：Google Play、Amazon Appstore、F-Droid
- 特殊处理：Android < 8.0 / < 10.0 需要额外 CA 证书（`lib/main.dart` 中加载）

### iOS

- 使用单独分支 `ios-release`（README 说明需 Flutter 3.27.4+）
- 分发渠道：Apple App Store

## 向后兼容与升级指南

### Flutter 版本升级

1. 修改 `.fvmrc` 中的 Flutter 版本
2. `fvm flutter pub get` 更新依赖
3. `fvm flutter analyze` 检查弃用警告
4. `fvm flutter test` 确保所有测试通过
5. `fvm dart format --line-length 120 .` 重格式化（如有格式化变化）

### 添加新依赖

1. `fvm flutter pub add <package_name>`
2. 如果依赖包含原生代码，运行 `fvm flutter run` 触发原生构建
3. 避免添加大而全的框架库——首选单一职责的轻量包

### 生成文件（不手工编辑）

- `lib/l10n/messages_*.dart` — 由 `generate_from_arb` 生成
- `*.g.dart` — 由各种生成器生成
- 以上文件在 `analysis_options.yaml` 中被排除分析
