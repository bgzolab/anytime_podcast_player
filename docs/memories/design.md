---
title: 项目设计
description: 给后续 LLM 提供「可执行、可验证、可迭代」的上下文。先做最小可用版本（MVP），不要过度设计；所有章节都要能直接映射为任务。
---

# 项目设计

## 设计哲学

1. **MVP 优先** — 每个功能先做最简可用版本，迭代优化
2. **可测试** — 抽象接口 + 具体实现分离，方便 mock
3. **平台惯例优先** — Android 用 Material Design，iOS 用平台控件
4. **离线优先** — 订阅数据本地持久化，网络只是刷新手段
5. **无障碍** — 支持 TalkBack 和 VoiceOver，所有 UI 变更需测试

## 当前架构决策记录

### 为什么用自定义 BLoC 而不是 flutter_bloc 包？

- 项目启动时 flutter_bloc 尚未成熟，团队选择了 RxDart 直接管理流
- 自定义 BLoC 基类只有 ~30 行，提供了 `resume`/`pause`/`detach` 生命周期
- 每个 BLoC 是一个 `ChangeNotifier`，直接通过 Provider 注入
- 决策影响：新 BLoC 需要手动管理 `BehaviorSubject` 的生命周期（`dispose` 时 close）

**任务1：** 如果团队对 `flutter_bloc` 或 `riverpod` 更熟悉，可以评估迁移成本。

### 为什么用 Provider 而不是 Riverpod / GetIt？

- 项目启动时 Provider 是 Flutter 官方推荐的 DI 方案
- `MultiProvider` 注入所有 BLoC，UI 通过 `Provider.of<T>()` 或 `context.watch<T>()` 获取
- 优点是简单、Flutter 内置支持；缺点是编译期无类型检查、难以与路由参数结合

### 为什么用 Sembast 而不是 SQLite / Hive？

- 不需要关系查询，文档型存储足以承载 Podcast/Episode 数据
- Sembast 支持 JSON 直接序列化，与 Dart 的 `toMap()`/`fromMap()` 模式自然契合
- 不需要 native 依赖（相比 sqflite），在 Flutter 生态中更便携
- 上层覆盖内存缓存，减少频繁的磁盘读取

### 为什么用 audio_service + just_audio？

- `just_audio` 是目前 Flutter 生态中最活跃的音频播放引擎
- `audio_service` 提供 Android 前台 Service / iOS 远程控制 / 锁屏控件等平台能力
- 但两者 API 都较底层，中间层 `DefaultAudioPlayerService` 做了封装，暴露简单的 `play`/`pause`/`seek`/`speed`

### Bookmark 功能设计决策

**耳机"上一曲"劫持**：通过 `AudioPlayerService.onSkipToPrevious` 回调实现。`_DefaultAudioPlayerHandler.skipToPrevious()` 优先调用回调，无回调时回退到 `rewind()`。受 `AppSettings.bookmarkOnSkipPrevious` 设置控制。

**Bookmark 按钮位置**：放在播放控制栏 Speed 旁边（右侧），始终可见可用。Rewind 按钮保持原位。设置只控制耳机行为，不影响 UI。

**Bookmark 数据模型**：独立 Entity（`Bookmark`），不嵌入 Episode。独立 Sembast store（`bookmark`）。BLoC 通过 `PublishSubject<BookmarkEvent>` + `BehaviorSubject<BlocState<List<Bookmark>>>` 管理状态。

**两个 Bookmark 视图**：
- `BookmarkView`（Now Playing 底部抽屉 tab）：只显示**当前播放单集**的书签，平铺列表
- `BookmarksPage`（底部导航栏 tab）：显示**所有单集**的书签，按播客→单集分组，使用 `SliverList` 实现（因为嵌入 `CustomScrollView`）

**书签创建音效**：`BookmarkSound.play()` 使用独立 `AudioPlayer` 实例播放 `assets/notification/water-drop.mp3`，不干扰播客播放。

**数据库结构**：Sembast `bookmark` store，自增 int key。字段：episodeGuid、episodeTitle、podcastName、podcastGuid、positionMs、note、createdAt。按 episodeGuid 查询时按 positionMs 排序，全部查询时按 createdAt 降序。

### 上下文感知搜索功能

**设计决策**：搜索按钮根据当前标签页执行不同的搜索逻辑，而非全局统一搜索。

**SearchMode 枚举**（`lib/ui/search/search_mode.dart`）：
- `timeline` — 搜索所有本地单集（按标题匹配）
- `library` — 搜索所有已订阅播客（按名称匹配）
- `discovery` — 在线搜索（iTunes/PodcastIndex API，保持原有行为）
- `downloads` — 搜索已下载单集（按标题匹配）
- `bookmarks` — 搜索书签（按单集标题、播客名称或备注匹配）

**实现方式**：
- `Search` widget 接收 `SearchMode` 和 `Repository` 参数
- Discovery 模式：使用 `SearchBloc` 执行在线搜索（原有逻辑不变）
- 其他模式：直接调用 `Repository.searchXxx(term)` 方法，内存过滤（case-insensitive）
- 搜索结果复用现有 `EpisodeTile`、`PodcastTile` 组件
- 书签搜索结果使用自定义 `_BookmarkSearchTile` 组件

**Repository 搜索方法**（`lib/repository/repository.dart`）：
- `searchEpisodes(String term)` — 按标题过滤单集
- `searchPodcasts(String term)` — 按标题过滤播客
- `searchDownloads(String term)` — 按标题过滤已下载单集
- `searchBookmarks(String term)` — 按 episodeTitle/podcastName/note 过滤书签

**国际化**：12 个新字符串（hint/tooltip/empty state），支持英文和简体中文。

**关键文件**：
- `lib/ui/search/search.dart` — 搜索页面（支持 5 种模式）
- `lib/ui/search/search_mode.dart` — SearchMode 枚举
- `lib/ui/anytime_podcast_app.dart` — 搜索按钮根据标签页传递 SearchMode
- `lib/repository/sembast/sembast_repository.dart` — 搜索方法实现

## 状态管理约定

所有 BLoC 遵循统一的状态模式：

```
BLoC ( receives Event ) → 处理 → BehaviorSubject.add(State)
                                            ↓
                                  UI 通过 StreamBuilder 渲染
```

**注意：** 多数 BLoC（如 `EpisodeBloc`）暴露的是 `switchMap` 返回的原始 `Stream`，不缓存状态。`TimelineBloc` 例外——它把 `switchMap` 输出管道到 `BehaviorSubject`，确保晚订阅的 Widget（如 Tab 切换后首次渲染）也能收到最新状态，避免 blank screen。

**事件约定：**
- BLoC 的 `eventSink` 接收事件对象（如 `PodcastEvent.refreshSubscriptions`）
- 事件使用 `freezed`-like 模式（手写 sealed class）
- 事件命名：`{领域}Event.{动作}`

**状态约定：**
- 状态继承 `BlocState` 基类（`lib/state/bloc_state.dart`）
- 常用子类：`BlocLoadingState` / `BlocPopulatedState<T>` / `BlocErrorState`
- 状态命名：`{领域}State`

**UI 监听模式：**
```dart
// 方式 1：Provider.of + 变量
final bloc = Provider.of<AudioBloc>(context);
final state = bloc.currentState;

// 方式 2：StreamBuilder
StreamBuilder<AudioState>(
  stream: bloc.stateStream,
  builder: (context, snapshot) { ... },
)
```

## 模块间通信

```
┌──────┐     Provider.of     ┌────────┐
│ UI   │ ──────────────────► │ BLoC   │
│      │ ◄══════════════════ │        │
└──────┘   stateStream (流)  └───┬────┘
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
              ┌─────────┐ ┌─────────┐ ┌──────────┐
              │ Service │ │  API    │ │Repository│
              └─────────┘ └─────────┘ └──────────┘
```

- **BLoC → Service**：方法调用（同步/异步），如 `audioService.play(url)`
- **Service → BLoC**：没有反向调用；BLoC 通过 `await` 获取 Service 结果后 emit 新状态
- **BLoC → API**：方法调用，如 `podcastApi.search(query)`
- **BLoC → Repository**：方法调用，如 `repository.save(episode)`

## UI 组件层级

```
AnytimePodcastApp (StatefulWidget)
  └── MaterialApp
       ├── ThemeData (light / dark)
       └── AnytimeHomePage (底部导航)
            ├── LibraryPage (Tab 0)
            │    ├── PodcastGridView / PodcastListView (可切换布局)
            │    ├── PodcastTile / PodcastGridTile
            │    └── RefreshIndicator (下拉刷新)
            ├── DiscoveryPage (Tab 1)
            │    └── 排行榜列表 → PodcastTile → PodcastPage
            ├── DownloadsPage (Tab 2)
            │    └── 已下载剧集列表
            ├── Timeline (Tab 3)
            │    ├── 按日期分组的剧集列表（Today / Yesterday / This Week / 完整日期）
            │    ├── 工具栏：刷新按钮 + 排序切换（最新/最早）
            │    ├── 无限滚动：滚到底自动加载更多
            │    ├── 日期筛选：点击日期头 → showDatePicker → 只显示当天剧集
            │    └── Empty/Loading/Error 状态
            ├── BookmarksPage (Tab 4)
            │    ├── SliverList 实现（嵌入父 CustomScrollView）
            │    ├── 按播客→单集分组（播客标题行 → 单集行 → 书签行）
            │    ├── 书签行：HH:MM:SS 时间点 + 备注 + 日期 + 播放按钮
            │    ├── 左滑删除书签
            │    └── Empty/Loading/Error 状态
            └── MiniPlayer (浮动底部条)
                 ├── 播客封面缩略图 + 标题
                 ├── 播放/暂停按钮
                 └── 进度条
```

播客详情和播放器的流转：
```
AnytimeHomePage
  ↓ 点击播客卡片
PodcastPage (播客详情)
  ├── 播客信息：封面、标题、作者、描述
  ├── EpisodeList (按季节/日期排序)
  │    └── EpisodeTile (播放/下载/队列)
  ├── ChapterSelector (如有章节)
  └── ShowNotes (HTML 渲染)
  ↓ 点击剧集或 MiniPlayer
NowPlayingPage (全屏播放器)
  ├── 大封面 + 标题/播客名
  ├── TransportControls (倒退/播放暂停/快进/书签/速度)
  ├── SeekBar (进度条 + 时间显示)
  ├── SpeedSelector (0.5x ~ 3.0x)
  ├── SleepSelector (定时关闭)
  ├── ChapterSelector
  ├── TranscriptView
  └── BookmarkView (当前单集书签列表)
```

## 音频播放状态机

```
IDLE
  │  play(url)
  ▼
LOADING
  │  缓冲完成
  ▼
PLAYING ────── pause ────► PAUSED
  │                          │
  │  seek/next/prev          │  play
  │  speed_change            ▼
  └─────────────────────── PLAYING
  │
  │  stop / 播放完成
  ▼
IDLE
```

`AudioBloc` 管理此状态机，同时跟踪：
- 当前播放的 Episode、Podcast
- 播放进度（position / duration）
- 播放速度
- 播放队列（Up Next）
- 缓冲状态

## 推荐开发任务清单

以下是可以直接映射为开发任务的方向：

### 短期（可独立完成）

| 任务 | 涉及文件 | 难度 |
|---|---|---|
| 添加新的设置选项 | `settings_bloc.dart`, `settings_page.dart`, `app_settings.dart` | 低 |
| 新增搜索提供商 | `podcast_api.dart`, `mobile_podcast_api.dart` | 中 |
| 添加播客分类筛选 | `podcast_bloc.dart` | 中 |
| ✅ 上下文感知搜索 | `search.dart`, `search_mode.dart`, `repository.dart` | 已完成 |
| 批量 OPML 导入优化 | `opml_service.dart` | 中 |
| 增加更多语言 | `lib/l10n/` 添加 `.arb` 文件 | 低 |

### 中期

| 任务 | 涉及文件 | 难度 |
|---|---|---|
| 播放列表管理 | `queue_bloc.dart`, `queue_page.dart` | 中 |
| 章节可视化跳转 | `chapter_selector.dart`, `audio_bloc.dart` | 中 |
| 定时下载新剧集 | `download_service.dart`, `background_fetch` | 中高 |
| CarPlay / Android Auto 支持 | `audio_player_service.dart` | 高 |
| 播客统计（收听时间等） | 新增 `StatsBloc` | 中 |

### 长期

| 任务 | 说明 |
|---|---|
| 状态管理迁移（Riverpod / flutter_bloc） | 影响所有 BLoC |
| 重构 `anytime_podcast_app.dart`（~30KB 拆分） | 提高可维护性 |
| 添加更多单元测试（当前约 9 个测试文件） | 提高覆盖率 |
| Widget 测试 / 集成测试 | 提高 UI 安全性 |
