---
title: 项目架构
description: 架构需要对项目的整体结构进行说明，明确每个文件夹和文件的作用，以及它们之间的关系。
---

# 项目架构

Anytime 是一个移动端播客播放器（Android & iOS），使用 **Dart/Flutter** 构建，采用**分层架构**设计：**UI → BLoC → Services → API + Repository**。

## 层级总览

```
用户交互 (手势/点击)
     ↓
┌──────────────────────────┐
│  UI 层 (lib/ui/)         │  ← StatelessWidget / StatefulWidget
│  通过 StreamBuilder 监听  │     没有业务逻辑
│  Provider.of 获取 BLoC    │
└──────────┬───────────────┘
           ↓ 事件 (Event)
┌──────────────────────────┐
│  BLoC 层 (lib/bloc/)     │  ← 自定义 BLoC (非 flutter_bloc)
│  接收 Event → 处理逻辑    │     使用 RxDart BehaviorSubject
│  发射 State              │     管理加载/成功/错误状态
└──────────┬───────────────┘
           ↓ 调用
┌──────────────────────────┐
│  Services 层 (lib/services/) │ ← 抽象接口 + Mobile* 实现
│  音频播放 / 下载 / 通知    │     可 mock 便于测试
│  OPML 导入导出            │
└──────┬──────────┬────────┘
       ↓          ↓
┌──────────┐ ┌──────────────┐
│ API 层   │ │ Repository   │  ← Sembast NoSQL
│ 播客搜索  │ │ 持久化存储    │     内存缓存 + 数据库
│ iTunes / │ │ Podcast,     │
│ Podcast  │ │ Episode,     │
│ Index    │ │ Queue, 等    │
└──────────┘ └──────────────┘
```

## 各目录详细说明

### `lib/main.dart` — 应用入口

启动流程：
1. `WidgetsFlutterBinding.ensureInitialized()` — 初始化 Flutter 引擎
2. 设置日志（level FINE，输出到控制台）
3. 初始化 `MobileSettingsService`
4. 加载 CA 证书（兼容 Android < 8.0 和 < 10.0 的老设备）
5. 调用 `runApp(AnytimePodcastApp(...))`

### `lib/ui/` — UI 层

不包含业务逻辑，只负责渲染和分发事件。

**`anytime_podcast_app.dart`** — 根组件（约 30KB，全项目最大文件）：
- 创建所有 Service 实例
- 用 `MultiProvider` 注入所有 BLoC
- 设置 `MaterialApp`：主题、本地化、路由、深链接
- 主页 `AnytimeHomePage`：底部导航栏三标签（Library / Discovery / Downloads）+ MiniPlayer + 搜索/队列/菜单

```
lib/ui/
├── anytime_podcast_app.dart   # 根组件：Provider 注入、主题、导航
├── themes.dart                # 浅色/深色主题（橙色强调色）
├── library/                   # 三个主标签页
│   ├── library_page.dart      #   订阅库
│   ├── discovery_page.dart    #   发现/排行榜
│   └── downloads_page.dart    #   下载管理
│   └── opml_import_page.dart  # OPML 导入
│   └── opml_export_page.dart  # OPML 导出
├── podcast/                   # 播客详情 & 播放器
│   ├── podcast_page.dart      #   播客详情（显示剧集列表）
│   ├── now_playing_page.dart  #   全屏正在播放
│   ├── mini_player.dart       #   底部迷你播放条
│   ├── show_notes.dart        #   显示笔记
│   ├── episode_list.dart      #   剧集列表
│   ├── chapter_selector.dart  #   章节选择
│   ├── transport_controls.dart #   播放控制按钮
│   ├── seekbar.dart           #   进度条
│   ├── queue_page.dart        #   "Up Next" 队列
│   └── transcript_view.dart   #   转录文本视图
├── search/                    # 搜索
│   └── search_page.dart       #   搜索栏 + 结果列表
├── settings/                  # 设置
│   ├── settings_page.dart     #   设置主页面
│   └── ...                    #   主题/搜索源/刷新周期等子页面
└── widgets/                   # 25+ 可复用组件
    ├── episode_tile.dart      #   剧集卡片
    ├── podcast_tile.dart      #   播客卡片
    ├── podcast_image.dart     #   播客封面图
    ├── position_slider.dart   #   播放进度滑块
    ├── speed_selector.dart    #   播放速度选择
    ├── sleep_selector.dart    #   定时关闭
    ├── download_button.dart   #   下载按钮
    ├── draggable_episode_tile.dart # 可拖拽剧集（队列排序）
    └── ...
```

### `lib/bloc/` — BLoC 业务逻辑层

**自定义 BLoC 模式**（不是 flutter_bloc 包）。核心基类 `bloc.dart` 提供生命周期管理（`resume` / `pause` / `detach`）。

```
lib/bloc/
├── bloc.dart                  # 抽象 Bloc 基类（BehaviorSubject 生命周期）
├── podcast/
│   ├── audio_bloc.dart        # 音频播放状态：播放/暂停/进度/速度
│   ├── episode_bloc.dart      # 剧集列表：过滤/排序/更新/删除
│   ├── podcast_bloc.dart      # 订阅管理：刷新/取消订阅
│   ├── queue_bloc.dart        # "Up Next" 播放队列
│   └── opml_bloc.dart         # OPML 导入/导出状态
├── discovery/
│   └── discovery_bloc.dart    # 排行榜/发现频道
├── search/
│   └── search_bloc.dart       # 播客搜索
├── settings/
│   └── settings_bloc.dart     # 应用设置
└── ui/
    └── pager_bloc.dart        # 底部导航标签页切换
```

**数据流模式：**

```
  Widget (build)
     │  stream.listen / StreamBuilder
     ▼
  BehaviorSubject<T>  ──emit──►  BlocState
     ▲
     │  sink.add(Event)
     │
  UI 调用 bloc.eventSink.add(SomeEvent())
```

状态类型（`lib/state/bloc_state.dart`）：
| 状态 | 含义 |
|---|---|
| `BlocDefaultState` | 初始默认 |
| `BlocLoadingState` | 加载中（首次） |
| `BlocBackgroundLoadingState` | 后台刷新 |
| `BlocEmptyState` | 无数据 |
| `BlocPopulatedState<T>` | 有数据（携带泛型数据） |
| `BlocErrorState` | 发生错误 |

### `lib/services/` — 服务层

每个服务有 **抽象接口** 和 **Mobile* 实现**，便于测试时 mock。

```
lib/services/
├── audio/
│   ├── audio_player_service.dart      # 抽象：play/pause/seek/speed
│   └── default_audio_player_service.dart # 实现：audio_service + just_audio
├── download/
│   ├── download_manager.dart          # 抽象：管理下载任务
│   ├── download_service.dart          # 抽象：下载队列
│   ├── mobile_download_manager.dart   # 实现：flutter_downloader
│   └── mobile_download_service.dart   # 实现
├── notifications/
│   ├── notification_service.dart      # 抽象：显示通知
│   └── mobile_notification_service.dart # 实现：awesome_notifications
├── podcast/
│   ├── podcast_service.dart           # 抽象：播客订阅/刷新/剧集管理
│   ├── mobile_podcast_service.dart    # 实现
│   ├── opml_service.dart              # 抽象：OPML 导入/导出
│   └── mobile_opml_service.dart       # 实现
└── settings/
    ├── settings_service.dart          # 抽象：键值对存储
    └── mobile_settings_service.dart   # 实现：shared_preferences
```

### `lib/api/` — 外部 API 层

```
lib/api/podcast/
├── podcast_api.dart           # 抽象接口：search, charts, loadFeed, chapters, transcripts
└── mobile_podcast_api.dart    # 实现：podcast_search 包（支持 iTunes + PodcastIndex）
```

关键方法：
- `search()` — 搜索播客
- `charts()` — 获取排行榜
- `loadFeed()` — 解析 RSS 获取剧集
- `loadChapters()` — 加载播客章节（Podcast 2.0）
- `loadTranscripts()` — 加载转录文本

### `lib/repository/` — 持久化存储层

```
lib/repository/
├── repository.dart            # 抽象 Repository 接口
│   CRUD: save/find/findAll/delete 按类型（Podcast, Episode 等）
└── sembast/
    ├── sembast_repository.dart      # Sembast (NoSQL) 实现
    │   ├── 上层覆盖了内存播客缓存 → 先查缓存再查 DB
    │   └── 按 Podcast / Episode / Queue 分类存储
    └── sembast_database_service.dart # 数据库辅助：版本管理、数据迁移
```

**数据库结构（Sembast Store 映射）：**

| Store | 存储内容 | Key |
|---|---|---|
| `podcasts` | `Podcast` 对象，JSON 序列化 | `podcast.feedUrl` |
| `episodes` | `Episode` 对象，JSON 序列化 | `episode.link` |
| `queue` | `Queue` 对象（剧集顺序列表） | 固定 key |
| `transcripts` | `Transcript` 对象 | `transcript.url` |

**内存缓存策略：** 所有 `Podcast` / `Episode` 读取先走内存 `Map`，miss 再查 Sembast，查到的写入缓存。

### `lib/entities/` — 数据模型

| 文件 | 说明 |
|---|---|
| `podcast.dart` | 播客：标题、作者、封面、Feed URL、分类等 |
| `episode.dart` | 剧集：标题、描述、时长、发布时间、音频 URL、下载状态 |
| `chapter.dart` | 章节（Podcast 2.0）：标题、开始时间、图片 |
| `transcript.dart` | 转录文本（Podcast 2.0）：URL、类型（json/srt/vtt） |
| `queue.dart` | 播放队列：有序 Episode URL 列表 |
| `person.dart` | 人员（Podcast 2.0）：角色、姓名 |
| `funding.dart` | 赞助信息（Podcast 2.0）：URL、文案 |
| `feed.dart` | RSS Feed 元数据 |
| `downloadable.dart` | 可下载对象抽象 |
| `persistable.dart` | 持久化接口（toMap / fromMap）、`@Transient()` 注解 |
| `app_settings.dart` | 应用设置对象 |
| `sleep.dart` | 定时关闭设置 |
| `search_providers.dart` | 搜索提供商枚举（iTunes / PodcastIndex） |

### `lib/state/` — 共享状态类型

各 BLoC 共用的状态类：
- `bloc_state.dart` — 泛型状态基类
- `episode_state.dart` — 剧集更新/删除事件
- `library_state.dart` — 库刷新/就绪/更新事件
- `opml_state.dart` — OPML 导入状态
- `persistent_state.dart` — 持久化操作状态
- `queue_event_state.dart` — 队列操作事件
- `transcript_state_event.dart` — 转录加载状态

### `lib/core/` — 核心工具

| 文件 | 说明 |
|---|---|
| `environment.dart` | 编译时常量：PINDEX_KEY、SECRET、USER_AGENT、FEEDBACK_URL |
| | `Environment.userAgent()` 生成 UA 字符串 |
| `utils.dart` | 文件路径解析、存储目录、SD 卡检测、URL 解析、分享、语言检测 |
| `extensions.dart` | Dart 扩展方法 |
| `annotations.dart` | 自定义注解：`@Transient()` |

### `lib/l10n/` — 国际化

支持 10 种语言。使用 `intl` + `intl_translation` 包。
- `L.dart` — 消息定义类
- `intl_en.arb` / `messages_*.dart` — 翻译文件
- 流程：`L.dart` 定义 → `extract_to_arb` → 翻译 `.arb` 文件 → `generate_from_arb` → `.dart`

## 依赖注入

使用 **Provider** 包，在 `AnytimePodcastApp` 中通过 `MultiProvider` 注入所有 BLoC：

```
MultiProvider(
  providers: [
    ChangeNotifierProvider(SearchBloc),
    ChangeNotifierProvider(DiscoveryBloc),
    ChangeNotifierProvider(EpisodeBloc),
    ChangeNotifierProvider(PodcastBloc),
    ChangeNotifierProvider(PagerBloc),
    ChangeNotifierProvider(AudioBloc),
    ChangeNotifierProvider(SettingsBloc),
    ChangeNotifierProvider(OpmlBloc),
    ChangeNotifierProvider(QueueBloc),
  ],
  child: MaterialApp(...),
)
```

BLoC 内部使用 RxDart `BehaviorSubject` 作为输出流，UI 通过 `Provider.of<BlocType>(context).stateStream` 或 `StreamBuilder` 获取状态。

## 音频播放架构

```
UI → AudioBloc ──控制──→ DefaultAudioPlayerService
                              ↓
                    audio_service (后台播放)
                              ↓
                    just_audio (实际音频引擎)
```

- `AudioBloc` 管理播放状态（播放/暂停/进度/速度/队列）和 UI 状态
- `DefaultAudioPlayerService` 封装 `audio_service`（处理 Android 前台 Service 通知、iOS 远程控制）
- `just_audio` 引擎处理实际音频解码和输出
- `audio_session` 管理音频焦点（来电时暂停等）

## 导航结构

```
MaterialApp
  └── AnytimeHomePage (底部导航)
        ├── Tab 0: LibraryPage (订阅库)
        ├── Tab 1: DiscoveryPage (发现)
        └── Tab 2: DownloadsPage (下载)
        └── MiniPlayer (浮动底部)
  ├── PodcastPage (播客详情) ← 从订阅/搜索/发现进入
  ├── NowPlayingPage (全屏播放) ← 点击 MiniPlayer 进入
  ├── SearchPage (搜索) ← 点击搜索图标
  ├── SettingsPage (设置)
  ├── QueuePage (播放队列)
  └── OPMLImport/ExportPage
```

`NavigationRouteObserver` 跟踪当前路由，用于调整 MiniPlayer 可见性等场景。
