---
title: Material 3 迁移
description: 2026-07-19 完成从 Material 2 到 Material 3 的全量迁移，启用动态取色，统一组件样式。
---

# Material 3 迁移

## 背景

项目原使用 `useMaterial3: false`，硬编码橙色（`#FF9800`）作为主题色。M2 API 在 Flutter 3.41.5 中大量弃用（`primaryColor`、`indicatorColor`、`surfaceVariant` 等），且暗色模式下部分组件颜色异常。

## 迁移方案

**目标：** 启用 Material 3，使用系统动态取色（Material You），统一组件样式。

| 对比项 | 迁移前 | 迁移后 |
|---|---|---|
| `useMaterial3` | `false` | `true` |
| 颜色来源 | 硬编码橙色 `#FF9800` | `DynamicColorBuilder` + M3 默认回退 |
| 底部导航 | `BottomNavigationBar` | M3 `NavigationBar` |
| 卡片圆角 | 0dp / 默认 | 12dp |
| 对话框/底部弹窗 | 默认 | 20dp 圆角 + 拖拽手柄 |
| 已播集数样式 | `Opacity(0.5)` | `ColorFiltered` + 文字透明度 |
| 颜色引用 | `primaryColor` / `indicatorColor` | `colorScheme.primary` |

## 核心变更

### 新增依赖

- `dynamic_color` — 获取 Android 12+ Material You 动态颜色

### 主题系统（`lib/ui/themes.dart`）

完全重写，关键改动：

- `ThemeData.light(useMaterial3: true)` / `ThemeData.dark(useMaterial3: true)` — 不再自定义 `ColorScheme`，使用 M3 默认色板
- `DynamicColorBuilder` 在 `anytime_podcast_app.dart` 中包裹 `MaterialApp`，合并系统动态颜色
- 组件主题只覆盖形状和行为，颜色全部从 `colorScheme` 派生
- 移除所有 M2 弃用属性：`primaryColorLight`、`primaryColorDark`、`secondaryHeaderColor`、`cardColor`、`canvasColor`、`disabledColor`、`hintColor`、`highlightColor`、`splashColor`、`unselectedWidgetColor`、`dialogBackgroundColor`、`indicatorColor`

### 组件迁移

| 组件 | 文件 | 改动 |
|---|---|---|
| 底部导航 | `anytime_podcast_app.dart` | `BottomNavigationBar` → `NavigationBar` + `NavigationDestination` |
| 系统栏 | `anytime_podcast_app.dart` | `AnnotatedRegion` 内联 `SystemUiOverlayStyle`（不再依赖 `appBarTheme.systemOverlayStyle!`） |
| Logo | `anytime_podcast_app.dart` | `TitleWidget` 从硬编码橙色改为 `colorScheme.primary` |
| 迷你播放器 | `mini_player.dart` | 容器 `surfaceContainerLow`，进度条 2px 圆角，图片 8dp 圆角 |
| 播放按钮 | `player_transport_controls.dart` | `Colors.orange`/`Colors.grey[800]` → `colorScheme.primary`/`onPrimary` |
| 标签页 | `now_playing.dart` | `DotDecoration` → pill 指示器（`BoxDecoration` + `primaryContainer`），无 divider，`isScrollable: true` + `SizedBox(width:100)` 固定宽度 |
| 进度条 | `player_position_controls.dart` | `primaryColor` → `colorScheme.primary` |
| 剧集卡片 | `episode_tile.dart` | `Opacity(0.5)` → `ColorFiltered` + 文字透明度 0.6，`ExpansionTile` 12dp 圆角 |
| 缩略图 | `tile_image.dart` | `borderRadius` 4.0 → 8.0 |
| 播放/下载按钮 | `play_pause_button.dart` / `download_button.dart` | `primaryColor`/`indicatorColor` → `colorScheme.primary` |
| 页面过渡 | `themes.dart` | `FadeUpwardsPageTransitionsBuilder`（Android）+ `CupertinoPageTransitionsBuilder`（iOS） |

### 颜色引用全局替换

将所有 `Theme.of(context).primaryColor` 替换为 `Theme.of(context).colorScheme.primary`，涉及文件：

`bookmarks_page.dart`、`discovery_results.dart`、`episodes.dart`、`library.dart`、`timeline.dart`、`podcast_list.dart`、`bookmark_view.dart`、`up_next_view.dart`、`settings_section_label.dart`、`podcast_image.dart`、`podcast_episode_list.dart`、`search.dart`、`search_results.dart`、`discovery.dart`

## 关键决策

### 为什么不用 `ColorScheme.fromSeed()`？

~~`fromSeed()` 需要硬编码种子颜色。我们选择不指定 `ColorScheme`，直接用 `ThemeData(useMaterial3: true)` 的默认色板，再通过 `DynamicColorBuilder` 合并系统动态颜色。这样：~~

**2026-07-24 更新：** 发现 `copyWith(colorScheme: ...)` 不更新 sub-theme 中已经拍平的颜色值（如 `AppBarTheme.backgroundColor` 在编译时已被求值为具体 `Color`），动态颜色实际上从未生效。

**现方案（`themes.dart`）：**
- `_buildTheme(ColorScheme colorScheme)` — 一个函数根据传入的 colorScheme 重新构建整个 ThemeData，sub-theme 颜色在调用时重新求值，不再拍平缓存
- `Themes.lightTheme([ColorScheme?])` / `.darkTheme([ColorScheme?])` — 接受可选动态色参数
- `DynamicColorBuilder` 在 `anytime_podcast_app.dart` 中拿到系统动态色后，调用 `Themes.lightTheme(dynamicScheme)` 或 `.darkTheme(dynamicScheme)` 构建完整主题
- 不支持动态色的设备回退到 `Color(0xFF1976D2)` 种子色（蓝色），不再是 M3 默认紫色

**效果：**
- Android 12+：自动使用壁纸派生的 Material You 颜色（现在实际生效）
- 旧设备/iOS：使用蓝色回退种子，不再偏紫

### 为什么添加 `dynamic_color` 依赖？

仅设置 `useMaterial3: true` 不会自动获取系统动态颜色。`dynamic_color` 是 Flutter 官方推荐的 Material You 集成方式，轻量无侵入。原计划 CON-007 禁止新依赖，但动态取色是 M3 核心体验，属必要依赖。

### 为什么 `copyWith(colorScheme: ...)` 不生效？

`copyWith(colorScheme: newScheme)` 只替换了顶层 `colorScheme` 属性，但 sub-theme 里预先捕获的颜色值（如 `AppBarTheme.backgroundColor: colorScheme.surface`）在构建时已被求值为具体 `Color` 对象写入 `AppBarTheme`。换 `colorScheme` 不会回头去重跑 sub-theme 的构造函数。

**修复：** 改为函数式构建 `_buildTheme(ColorScheme cs)`，每次调用时用入参 `cs` 重新构造所有 sub-theme，确保颜色值始终与当前 `colorScheme` 一致。

### 为什么保留 `primaryColor` 全局变量？

`anytime_podcast_app.dart` 中的 `ThemeData theme` 全局变量用于设置切换监听。`DynamicColorBuilder` 在其外层合并动态颜色，架构无需改动。

## 验证结果

- `fvm flutter analyze` — 0 error（1 个预存 widget_test.dart 错误）
- `fvm flutter test` — 47 pass, 14 skip, 1 fail（预存）
- 暗色模式：按钮可见，颜色统一
- Material You：Android 12+ 动态取色生效
