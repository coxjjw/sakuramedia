# lib/features/actors/ — 演员域

演员列表、演员详情。是**样板的最简版**——套用 movies 分层但只保留必要子结构:无播放器、无跨页 mutation notifier、无合集/导入子域。域级通用范式看 `lib/features/CLAUDE.md`。

## 目录结构(样板最简版)

```
data/
  api/actors_api.dart              (1)
  dto/                             (3,平铺 < 5 不分子域)
    actor_list_item_dto.dart
    actor_movie_year_dto.dart
    actor_search_stream_update.dart
presentation/
  controllers/
    listing/                       (4) paged_actor_summary_controller +
                                        actor_filter_state + actor_filter_preset +
                                        actor_list_page_state
    detail/                        (1) actor_detail_controller
  pages/
    desktop/                       (2) actors_page + actor_detail_page
    mobile/                        (3) actors_page + actor_detail_page +
                                        actor_filter_drawer
    shared/                        (1) actor_detail_content
```

## 与 movies / videos 对比(差异全景)

| 概念 | movies | videos | actors |
|---|---|---|---|
| API 数量 | 1 | 3 | 1 |
| DTO 子域切分 | 5 组 | 平铺(4) | 平铺(3) |
| controllers 子域 | 5 组 | 4 组 | 2 组 |
| notifiers/ | ✓ | ✓ | ✗ 无跨页 mutation |
| player/ | ✓ | ✗ | ✗ |
| actions/ | ✓ (详情动作套件) | ✗ | ✗ |
| widgets/(feature 内) | ✓ 大量 | ✓ 大量 | ✗ 全部保留在 lib/widgets/actors/ |
| lib/widgets/{域}/ 迁移 | 部分迁移 | 全部迁入 | ✗ 全部保留(都是跨 feature 共享) |

**为何 actors 不做 widgets 迁移**:`widgets/actors/` 下 5 个组件全部或间接被外部使用(`actor_avatar` 被 movies detail + media_preview_dialog 用,`actor_summary_grid` 被 catalog_search 用,summary_card 是 grid 的内部依赖),挪进 feature 会让跨 feature import 反向,得不偿失。这是"少数留在 lib/widgets/ 下、不进 feature"的合理场景,与 movies 的 `widgets/movies/`(通用影片卡)同理。

## 域特有约定

- **筛选状态**:`ActorFilterState` + `ActorFilterPreset`(预置的常用组合)。**改预置要同步文案**,前端硬编码在 `actor_filter_preset.dart`。
- **搜索 SSE**:`ActorSearchStreamUpdate` 消费遵循通用 SSE 三重终止兜底范式(见 `lib/features/CLAUDE.md`)。
- **列表复用 movies 的部分组件**:`actor_detail_content` 里嵌了影片列表,直接用 `features/movies/presentation/pages/shared/movie_list_content.dart` + `movies/controllers/listing/*`。改 movies 列表相关会波及演员详情页。

## 与测试的关系

`test/features/actors/` 覆盖较全:data api、两个 controller、四个 page(desktop + mobile × actors_page + actor_detail_page) 都有 test。**无 actor_filter_drawer test、无 actor_detail_content test**(嵌套复用 movies 列表,依赖 movies test 间接覆盖)。
