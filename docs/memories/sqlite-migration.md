---
title: Sembast → SQLite 迁移
description: 2026-07-19 完成持久化层从 Sembast 到 SQLite 的全量迁移，解决数据库打开耗时 8 秒的根本问题。
---

# Sembast → SQLite 迁移

## 背景

Sembast 是 append-only JSON 日志数据库，打开时需要全量读取文件到内存。当数据库文件增长到 190MB（约 37000+ 剧集、100 订阅）时，打开耗时 8 秒，导致 App 启动后每个页面都需要 10 秒左右的 loading 才能显示内容。

## 迁移方案

**目标数据库：SQLite（sqflite 包）**

| 对比项 | Sembast | SQLite |
|---|---|---|
| 打开方式 | 全量读取 JSON 日志到内存 | 仅读取文件头（B-tree 索引） |
| 打开耗时（190MB） | ~8 秒 | <200ms |
| 查询方式 | 全表扫描 + 内存过滤 | SQL 索引查询 |
| 存储效率 | append-only，文件只增不减 | 复用已释放页面 |

## 实施详情

### 新增文件

- `lib/repository/sqlite/sqlite_database_service.dart` — SQLite 数据库服务（5 张表、8 个索引）
- `lib/repository/sqlite/sqlite_repository.dart` — Repository 接口的 SQLite 实现（30+ 方法）
- `lib/repository/sqlite/migration_service.dart` — 一次性数据迁移（已完成使命，已删除）
- `test/unit/persistence/sqlite_test.dart` — SQLite 单元测试

### 删除文件

- `lib/repository/sembast/sembast_repository.dart`
- `lib/repository/sembast/sembast_database_service.dart`
- `test/unit/persistence/sembast_test.dart`

### 修改文件

- `pubspec.yaml` — 移除 `sembast` 依赖，添加 `sqflite: ^2.4.2`
- `lib/ui/anytime_podcast_app.dart` — Provider 注入从 `SembastRepository` 改为 `SqliteRepository`
- `lib/repository/sqlite/sqlite_repository.dart` — 移除迁移检查代码
- `test/unit/persistence/search_test.dart` — 改用 SqliteRepository
- `test/unit/opml/opml_service_test.dart` — 改用 SqliteRepository

## SQLite 表结构

```sql
-- podcast（播客订阅）
CREATE TABLE podcast (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT UNIQUE, url TEXT, link TEXT, title TEXT, description TEXT,
  imageUrl TEXT, thumbImageUrl TEXT, copyright TEXT, etag TEXT,
  subscribedDate INTEGER, lastUpdated INTEGER,
  rssFeedLastUpdated INTEGER, latestEpisodeDate INTEGER,
  filter INTEGER DEFAULT 0, sort INTEGER DEFAULT 0,
  newEpisodes INTEGER DEFAULT 0, funding TEXT, person TEXT
);

-- episode（剧集）
CREATE TABLE episode (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT, pguid TEXT, downloadTaskId TEXT, filepath TEXT, filename TEXT,
  downloadState INTEGER DEFAULT 0, podcast TEXT, title TEXT, description TEXT,
  content TEXT, link TEXT, imageUrl TEXT, thumbImageUrl TEXT,
  publicationDate INTEGER, contentUrl TEXT, length INTEGER DEFAULT 0,
  mimeType TEXT, author TEXT, season INTEGER DEFAULT 0, episode INTEGER DEFAULT 0,
  duration INTEGER DEFAULT 0, position INTEGER DEFAULT 0,
  downloadPercentage INTEGER DEFAULT 0, played INTEGER DEFAULT 0,
  chaptersUrl TEXT, chapters TEXT, ne INTEGER DEFAULT 0, tid INTEGER,
  transcriptUrls TEXT, persons TEXT, lastUpdated INTEGER
);

-- transcript（转录文本）
CREATE TABLE transcript (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT, subtitles TEXT, lastUpdated INTEGER
);

-- bookmark（书签）
CREATE TABLE bookmark (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  episodeGuid TEXT, episodeTitle TEXT, podcastName TEXT, podcastGuid TEXT,
  positionMs INTEGER, note TEXT, createdAt INTEGER
);

-- queue（播放队列）
CREATE TABLE queue (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  guids TEXT
);
```

### 索引

```sql
CREATE INDEX idx_episode_pubdate ON episode(publicationDate);
CREATE INDEX idx_episode_pguid ON episode(pguid);
CREATE INDEX idx_episode_guid ON episode(guid);
CREATE INDEX idx_episode_download ON episode(downloadState, downloadPercentage);
CREATE INDEX idx_episode_task ON episode(downloadTaskId);
CREATE INDEX idx_bookmark_episode ON bookmark(episodeGuid);
CREATE INDEX idx_bookmark_created ON bookmark(createdAt);
CREATE INDEX idx_podcast_guid ON podcast(guid);
```

## 类型转换要点

SQLite 使用原生类型（INTEGER/TEXT），但 Entity 的 `fromMap()` 方法期望 Sembast 格式（String 日期、'true'/'false' 布尔值）。`SqliteRepository._rowFromSqlite()` 处理转换：

| 字段类型 | SQLite 存储 | fromMap() 期望 | 转换方式 |
|---|---|---|---|
| 日期时间戳 | INTEGER | String | `_intToStringFields` 集合控制 |
| 布尔值 played | INTEGER 0/1 | String 'true'/'false' | `_intToBoolStringFields` 集合控制 |
| 列表/Map | TEXT (JSON) | List/Map | `jsonDecode` |
| `lastUpdated` | INTEGER | Podcast:int, Episode:String | Episode 查询时单独转换 |

**注意：** `lastUpdated` 在 Podcast 和 Episode 中的类型期望不同：
- `Podcast.fromMap` 期望 `int?`
- `Episode.fromMap` 期望 `String`

`_intToStringFields` 不包含 `lastUpdated`，`_episodeFromRow()` 方法单独处理 Episode 的 `lastUpdated` 转换。

## 数据迁移策略

首次使用 SQLite 版本时，`MigrationService` 自动执行一次性迁移：

1. 检测 Sembast 数据库文件是否存在
2. 读取所有 Store（podcast、episode、transcript、bookmark、queue）
3. 类型转换后批量写入 SQLite（episode 分批 500 条）
4. 迁移完成后删除 Sembast 文件（`.bak`）

## 验证结果

- 数据库打开：~100ms（vs Sembast 8 秒）
- 37654 条剧集迁移：~15 秒
- `fvm flutter analyze`：无新增错误
- `fvm flutter test`：47 pass, 14 skip（SQLite 需要真机）, 1 fail（预存 widget_test.dart）
