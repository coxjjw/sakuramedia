# lib/features/movies/ — 影片核心域(最复杂)

仓库最大最复杂的 feature:影片列表/筛选、系列、详情(演员/标签/媒体源/相似)、应用内播放器(缩略图圈选切片 + 字幕 + 进度上报)、订阅/合集、磁力搜索/下载、评论、缩略图(本地切片帧 + MissAV 在线流式)、系列在线导入。先读 `lib/features/CLAUDE.md` 的通用范式,本文件只讲本域特有约定。

## 目录结构

```
data/
  api/                   # MoviesApi(唯一 API 类)
  dto/                   # 按业务子域分组
    listing/             # movie_list_item / parsed_movie_number
    detail/              # movie_detail / movie_review / movie_collection_type
    player/              # movie_subtitle
    thumbnails/          # movie_media_thumbnail + MissAV 结果 + MissAV SSE 流
    series_import/       # movie_search_stream_update(catalog 搜索共用)
presentation/
  controllers/           # 按业务子域分组(镜像 dto/)
    detail/              # 7 个:detail_controller / magnet / missav_thumbnail /
                         #       review / thumbnail / clips_controller / clip_section_mixin
    listing/             # 4 个:filter_state / list_page_state /
                         #       list_filterable_page_state / paged_movie_summary_controller
    player/              # 2 个:player_controller / player_subtitle_state
    notifiers/           # 3 个跨页 mutation 广播(collection_type / playability / subscription)
    series_import/       # 1 个:series_import_controller
  pages/
    desktop/             # 4 个桌面页(文件名无 desktop_ 前缀)
    mobile/              # 5 个移动页(文件名无 mobile_ 前缀)
    shared/              # 3 个跨平台内容片段(movie_list_content 等)
  actions/               # 6 个详情动作/菜单/播放启动器
  widgets/
    detail/              # 18 个 detail 页专用组件(从原 lib/widgets/movie_detail/ 迁入)
    series_import/       # 1 个:series_import_dialog
```

**在其它 feature 内 import 时**:DTO 从 `features/movies/data/dto/<子域>/` 拿,`MoviesApi` 从 `features/movies/data/api/` 拿,控制器从 `presentation/controllers/<子域>/` 拿(常见:全局 mutation notifier 走 `controllers/notifiers/`)。不要从 `pages/` 拿(那是页面私域)。

## 样板判定规则(什么时候扁平、什么时候分子域)

`data/api/` + `data/dto/` + `presentation/{controllers,pages,widgets,...}/` 这套骨架是仓库样板,但**子域分组的深度按规模变**:

| 目录 | 扁平(在自身根) | 分子域 |
|---|---|---|
| `data/dto/` | **默认扁平**(< 5 DTOs 且无自然分组时) | 5 个及以上 DTOs **且**有清晰业务分组 |
| `presentation/controllers/` | **默认扁平**(2 个及以下,或无自然分组) | 3 个及以上且能分出 **listing / detail / ...** 中至少两个子域 |
| `presentation/pages/` | **总是分** `{desktop,mobile,shared}/` (三平台差异是硬约束) | 同上,不再细分 |
| `presentation/widgets/` | **默认扁平**(< 5 个组件时) | 5+ 组件且能分子域 |

**推荐子域名(避免自造)**:`listing / detail / collections / player / imports / thumbnails / notifiers / series_import`(视具体域取用)。`notifiers/` 专门放跨页 mutation 广播的 `ChangeNotifier`,这类物种独立成组即使只有 1 个也可以分出来(它跟其它 controller 语义差异大)。

**已落地的样板案例**(按复杂度):
- **movies**:最完整版(5 类 controllers 子域、5 类 dto 子域、`actions/`、`widgets/detail/`)
- **videos**:多 API 版(3 个 API 平级、4 类 controllers 子域、`widgets/{listing,collections,player,imports}/`)
- **actors**:最简版(1 API、3 DTO 扁平、2 类 controllers)
- **clip_collections / playlists / clips**:小域(2 controllers 扁平、widgets 扁平)

新 feature 照抄时**先对齐规模最接近的样板**,再按上表调整分组深度。

## 列表:筛选状态驱动(易踩第一名)

- 筛选状态 `MovieFilterState`(`const` 值对象)**存在 page state 的可写字段 `filterState`**,fetcher 闭包惰性读它拼参数。
- **UI 改完 `filterState` 必须 `controller.reload()`** 才生效——控制器本身对筛选无感知。
- `MovieFilterState.copyWith` 的 **`year` 用 sentinel**:传 `null`=清空,不传=保持(其它字段是普通 `??`)。
- **新增"可筛选影片列表页"**:实现 `MovieListFilterablePageState` 抽象 + 混入 `MovieListSubscriptionSyncMixin`,套共享 `MovieListContent`,用 `obtainCachedPageState` 缓存。`tags` 域就是这样复用本域列表的。
- **无筛选的系列列表**参考 `SeriesMoviesContent`:不走 page-state-cache,State 里直接建 `PagedMovieSummaryController` + 手动 bind 订阅 notifier。

## 列表分页控制器

`PagedMovieSummaryController`(继承 `PagedLoadController`)加订阅:`toggleSubscription` 乐观更新 + 失败回滚 + 区分 `blockedByMedia`(错误码 `movie_subscription_has_media`),返回 `MovieSubscriptionToggleResult` 由 `showMovieSubscriptionFeedback` 统一 toast。订阅/合集变更**必须** report 到全局 `MovieSubscriptionChangeNotifier` / `MovieCollectionTypeChangeNotifier`,其它列表/详情监听后 `applySubscriptionChange` 同步。

## 详情页:两端高度重复 + override 模式

- `DesktopMovieDetailPage` / `MobileMovieDetailPage` 都是 StatefulWidget,**逻辑逐行重复**(订阅/合集/删媒体/标记点/相似图搜索),差异仅呈现层(桌面 dialog/popup-menu,移动 `AppBottomDrawer`)。**改这些逻辑要同时改两个文件**(只抽了渲染体 `MovieDetailPageContent` 和远程动作 `action_support`)。
- 页面持大量本地 override 态(`_isSubscribedOverride`/`_isCollectionOverride`/`_pointOverrides`/`_activeMovieAction`),`_isMovieActionLocked` 串行化所有动作。
- 远程动作走三件套:`movie_detail_action_menu.dart`(`MovieDetailActionType` 枚举 + 桌面/移动两种呈现 + descriptors)、`movie_detail_action_support.dart`(`executeMovieDetailRemoteAction` 自动执行/回写 controller/toast)、`movie_detail_action_copy.dart`(文案)。**新增详情远程动作**:加枚举值 + 在 `movieDetailRemoteActionSpecFor` 加 spec + 在 descriptors 加项,`executeMovieDetailRemoteAction` 自动接管。

## 检查器子控制器**不在本目录页面**

详情页底部信息栏点击打开的"检查器"(评论/磁力/缩略图/MissAV 四 Tab)由 **`lib/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart`** 在 `initState` new 出并持有这四个控制器:`MovieDetailReviewController`(自写分页)、`MovieDetailMagnetController`、`MovieDetailThumbnailController`、`MovieDetailMissavThumbnailController`(SSE 流式)。本目录有这些控制器文件,但**实例化方在 widgets 层**。改检查器行为两边都要看。

## 播放器

- `MoviePlayerController` 最重:`resolvedPlayUrl` 经 `resolveMediaUrl(baseUrl)`;**字幕 `fetchMovieSubtitles` 可为 null**(非 JAV 源短路 `unsupported`,别假设总有字幕);进度上报 `Timer.periodic`(默认 5s)仅 position 变化才 PUT,**失败把 `_lastReported` 置 null 以便重试**(非 bug);startup 位置优先级 `initialPositionSeconds > 媒体 stored progress > 0`;dispose 时 `flushPlaybackProgress()`。
- **`MobileMoviePlayerPage` 直接复用 `DesktopMoviePlayerPage`**(仅传 `useTouchOptimizedControls:true` + 横屏 system UI)——**改桌面播放器页同时影响移动**。
- 播放器 UI 组件在 `lib/widgets/media_player/`,有 url 切换竞态保护(`MoviePlayerSurfaceOpenCoordinator` + requestId)、大量需成对 dispose 的订阅/Timer——见该目录约定。

## SSE 缩略图与系列导入

在线搜索流与系列导入流**共用 `MovieSearchStreamUpdate`**,但事件名映射不同(由 `MoviesApi` 内不同 mapper 处理);MissAV 缩略图用 `MissavThumbnailStreamUpdate`。消费遵循通用 SSE 三重兜底范式(见 `lib/features/CLAUDE.md`)。流式 stats 的 `createdCount > 0` 决定列表是否 refresh。

## 跨模块契约

依赖 core(`ApiClient` 全动词 / `resolveMediaUrl` / `PaginatedResponseDto` / `ApiException.code`);跨 feature 协作 search/downloads/media/playlists/external_player(`launchMoviePlayback` 拉外部播放器降级应用内)/image_search/clips/configuration/subscriptions;复用 `widgets/movies`(通用影片卡片/网格)、`widgets/media_player`(通用播放器套件,已从 `movie_player` 更名)、`widgets/media`。detail 页专用组件已内聚到本 feature 的 `presentation/widgets/detail/`,少数被 `image_search` / `media_preview_dialog` 借用。被 rankings/actors/tags/overview/discovery/playlists 等多域复用其 DTO 与控制器。

## 与测试的关系

`test/features/movies/` 覆盖齐全:`movies_api_test`、各 `*controller_test`、各 page/content test。改 API→`movies_api_test`;改分页/订阅→`paged_movie_summary_controller_test`;改详情动作→`movie_detail_action_support_test` + 两个 detail page test;改播放器(含移动)→`movie_player_controller_test` + 两个 player page test;改 SSE 缩略图→`movie_detail_missav_thumbnail_controller_test`。**`MovieDetailMagnetController`、`series_import_*`、`series_movies_content` 无直接单测**,手动验证。
