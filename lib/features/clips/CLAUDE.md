# lib/features/clips/ — 切片(短片段)域

从影片/媒体裁出短片段、切片自身列表/操作、切片播放。域级通用范式看 `lib/features/CLAUDE.md`(尤其"短视频/切片域"一节),此处只列本域特有约定。

## 目录结构

```
data/
  api/clips_api.dart                (1)
  dto/                              (2 平铺)
    media_clip_dto.dart
    media_clip_thumbnail_dto.dart
presentation/
  controllers/                      (2 扁平)
    clips_overview_controller.dart
    clip_mutation_change_notifier.dart(跨页 mutation 广播)
  pages/
    desktop/                        (1) clips_page
    mobile/                         (4) clip_player_page + clip_actions_sheet +
                                          clip_confirm_drawer + overview_clips_tab
  widgets/                          (2 扁平)
    create_clip_dialog.dart
    rename_clip_dialog.dart
```

**在其它 feature 内 import 时**:DTO 从 `data/dto/`,`ClipsApi` 从 `data/api/`,跨页 mutation 广播用 `presentation/controllers/clip_mutation_change_notifier.dart`。

## 关键决策:lib/widgets/clips/ 保留不动

`lib/widgets/clips/` 下 6 个组件里**至少 5 个被外部 feature 借用**:

| 组件 | 借用者 |
|---|---|
| clip_grid_card | movies detail(`movie_clip_strip`) |
| clip_cover_card | clip_collections mobile 详情页 |
| clip_cover_overlays | videos mobile actions sheet |
| clip_player_dialog | clip_collections + movies |
| clip_selection_status_bar | movies detail inspector + widgets/media_player |
| clip_card | (内部辅助) |

跟 `widgets/movies/`(通用影片卡片被多域用)同理,**整个 lib/widgets/clips/ 保留在原位**,不迁入 feature 内部。同样 `widgets/media_player/`(通用播放器)也保留在 lib/widgets/。

## 域特有约定

- **`createClip` 同步切片**,前端超时 130s(后端 ffmpeg 120s);**超时≠失败**,关对话框让用户去"我的切片"页查看是否已生成。
- **`clip_mutation_change_notifier`**:切片增删/合集变化都要 `report*`,监听方读 `lastChange` 精准补丁而非整页刷新。
- **overview_clips_tab**:是 `overview` 移动骨架页里嵌的"切片"标签,归到 `clips/pages/mobile/`(在 clips 域里渲染,只是被 overview 页组合)。

## 与测试的关系

`test/features/clips/`:
- `data/api/clips_api_test`、`data/dto/media_clip_dto_test`
- `presentation/controllers/*`(两个 controller 都有 test)

**无 page/dialog test、无 `media_clip_thumbnail_dto` 单测**;改这些需手动验证。
