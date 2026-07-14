import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_controller.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/media_rapid_upload_history_controller.dart';
import 'package:sakuramedia/features/media/presentation/widgets/media_browse_filter_toolbar.dart';
import 'package:sakuramedia/features/media/presentation/widgets/rapid_upload_target_library_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 「媒体管理」桌面页：
/// - 顶部 `AppTabBar` 两栏：媒体列表 / 秒传批次；
/// - 媒体列表 tab：`AppFilterPopover` 归属 / 媒体库 / 排序 + 总数 + 刷新 + 列表（多选 + 秒传到 115）；
/// - 秒传批次 tab：批次历史卡（重试失败项、无限滚动加载更多）。
///
/// 挂在系统设置左侧「媒体管理」tab 下，与 [DesktopMediaMaintenancePage](desktop_media_maintenance_page.dart)
/// 是姊妹页；本页只承载「查看 / 批量整理」，失效清理仍走维护页。
class DesktopMediaManagementPage extends StatefulWidget {
  const DesktopMediaManagementPage({super.key, this.active = true});

  /// 作为系统设置页 tab 嵌入时用于懒加载：仅在 tab 激活后才发请求。
  final bool active;

  @override
  State<DesktopMediaManagementPage> createState() =>
      _DesktopMediaManagementPageState();
}

class _DesktopMediaManagementPageState extends State<DesktopMediaManagementPage>
    with SingleTickerProviderStateMixin {
  static const Duration _runningBatchPollInterval = Duration(seconds: 8);
  static const int _batchTabIndex = 1;

  late final MediaBrowseController _mediaController;
  late final MediaRapidUploadHistoryController _batchController;
  late final TabController _tabController;

  /// 页面级共享滚动控制器：`AppPageFrame` 的 `SingleChildScrollView` 用它。
  /// 每次 tab 切换回到顶部；`_handleScroll` 按当前 tab 分发 loadMore，
  /// 避免两个分页控制器同时监听同一 scroll、互相打架。
  final ScrollController _scrollController = ScrollController();
  Timer? _batchPollTimer;

  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  Map<int, MediaStorageDescriptor> _storageDescriptors =
      const <int, MediaStorageDescriptor>{};
  bool _isTriggeringUpload = false;
  int? _retryingBatchId;

  @override
  void initState() {
    super.initState();
    final api = context.read<MediaApi>();
    _mediaController = MediaBrowseController(mediaApi: api);
    _batchController = MediaRapidUploadHistoryController(mediaApi: api);
    _batchController.addListener(_handleBatchControllerChanged);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _scrollController.addListener(_handleScroll);
    if (widget.active) {
      _bootstrap();
    }
  }

  @override
  void didUpdateWidget(covariant DesktopMediaManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _batchPollTimer?.cancel();
    _batchController.removeListener(_handleBatchControllerChanged);
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _mediaController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  bool get _isBatchTab => _tabController.index == _batchTabIndex;

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    // 切标签时回到顶部，避免新标签沿用上一个标签的滚动位置导致误触发 loadMore。
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {});
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 400) {
      return;
    }
    if (_isBatchTab) {
      unawaited(_batchController.loadMore());
    } else {
      unawaited(_mediaController.loadMore());
    }
  }

  void _bootstrap() {
    unawaited(_mediaController.initialize());
    unawaited(_batchController.initialize());
    unawaited(_loadLibraries());
  }

  /// 后端秒传是异步作业，任一批次仍在 pending/running 时启动周期刷新，
  /// 确保用户不用手点也能看到批次向终态推进。全部批次都进入终态后立刻停轮询。
  void _handleBatchControllerChanged() {
    final hasRunning = _batchController.items.any(
      (batch) => batch.state.isRunning,
    );
    if (hasRunning) {
      _ensureBatchPollTimer();
    } else {
      _batchPollTimer?.cancel();
      _batchPollTimer = null;
    }
  }

  void _ensureBatchPollTimer() {
    if (_batchPollTimer != null && _batchPollTimer!.isActive) {
      return;
    }
    _batchPollTimer = Timer.periodic(_runningBatchPollInterval, (_) {
      _pollRunningBatches();
    });
  }

  void _pollRunningBatches() {
    if (!mounted) {
      return;
    }
    for (final batch in _batchController.items) {
      if (!batch.state.isRunning) {
        continue;
      }
      unawaited(_refreshBatch(batch.id, silent: true));
    }
  }

  /// 静默 [silent] 时不弹 toast——用于周期轮询，避免刷屏；
  /// 用户显式触发的刷新则把错误 toast 出来。
  Future<void> _refreshBatch(int batchId, {required bool silent}) async {
    try {
      await _batchController.refreshBatch(batchId);
    } catch (error) {
      if (!silent && mounted) {
        showToast(apiErrorMessage(error, fallback: '刷新批次详情失败'));
      }
    }
  }

  Future<void> _loadLibraries() async {
    MediaLibrariesApi? api;
    try {
      api = context.read<MediaLibrariesApi>();
    } on ProviderNotFoundException {
      return;
    }
    try {
      final libraries = await api.getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _storageDescriptors = buildMediaStorageDescriptors(libraries);
      });
    } catch (_) {
      // 库列表加载失败不阻断主流程；批量操作再次尝试时可发现问题。
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _mediaController.reload(),
      _batchController.reload(),
      _loadLibraries(),
    ]);
  }

  Future<void> _handleFilterChange(MediaBrowseFilterState next) async {
    await _mediaController.applyFilterState(next);
  }

  Future<void> _handleFilterReset() =>
      _mediaController.applyFilterState(MediaBrowseFilterState.initial);

  Future<void> _openRapidUploadDialog() async {
    final selectedIds = _mediaController.selectedIds.toList(growable: false);
    if (selectedIds.isEmpty) {
      return;
    }
    final cloud115Libraries = _libraries
        .where((library) => library.isCloud115)
        .toList(growable: false);
    final target = await showRapidUploadTargetLibraryDialog(
      context,
      selectedCount: selectedIds.length,
      libraries: cloud115Libraries,
    );
    if (target == null || !mounted) {
      return;
    }
    setState(() => _isTriggeringUpload = true);
    try {
      final response = await context.read<MediaApi>().createMediaRapidUpload(
        mediaIds: selectedIds,
        targetLibraryId: target.id,
      );
      if (!mounted) {
        return;
      }
      // 触发成功：把已选条目从列表中移除（进入批次后不允许重复选择），
      // 并异步补一次批次详情，UI 立刻看到新批次入队。
      _mediaController.removeItemsByIds(selectedIds);
      unawaited(_refreshBatch(response.batchId, silent: false));
      showToast('已创建秒传批次 #${response.batchId}，共 ${selectedIds.length} 项');
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '创建秒传批次失败'));
      }
    } finally {
      if (mounted) {
        setState(() => _isTriggeringUpload = false);
      }
    }
  }

  Future<void> _retryBatch(MediaRapidUploadBatchListItemDto batch) async {
    if (_retryingBatchId != null) {
      return;
    }
    setState(() => _retryingBatchId = batch.id);
    try {
      final response = await context.read<MediaApi>().retryMediaRapidUpload(
        batchId: batch.id,
      );
      if (!mounted) {
        return;
      }
      unawaited(_refreshBatch(response.batchId, silent: false));
      showToast('已创建重试批次 #${response.batchId}');
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '重试秒传批次失败'));
      }
    } finally {
      if (mounted) {
        setState(() => _retryingBatchId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _mediaController,
        _batchController,
        _tabController,
      ]),
      builder: (context, _) {
        final spacing = context.appSpacing;
        return AppPageFrame(
          title: '',
          scrollController: _scrollController,
          child: Column(
            key: const Key('desktop-media-management-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    key: Key('media-management-tab-list'),
                    text: '媒体列表',
                  ),
                  Tab(
                    key: Key('media-management-tab-batches'),
                    text: '秒传批次',
                  ),
                ],
              ),
              SizedBox(height: spacing.lg),
              if (_isBatchTab)
                _RapidUploadHistoryCard(
                  controller: _batchController,
                  libraries: _libraries,
                  onRetry: _retryBatch,
                  retryingBatchId: _retryingBatchId,
                )
              else
                _MediaListPane(
                  controller: _mediaController,
                  libraries: _libraries,
                  storageDescriptors: _storageDescriptors,
                  isTriggering: _isTriggeringUpload,
                  onFilterChanged: _handleFilterChange,
                  onFilterReset: _handleFilterReset,
                  onRefresh: _refreshAll,
                  onSelectAllOnPage: () => _mediaController.selectAllLoaded(),
                  onClearSelection: () => _mediaController.clearSelection(),
                  onRapidUpload: _openRapidUploadDialog,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 媒体列表 tab（筛选头 + 列表卡）
// ─────────────────────────────────────────────────────────────────────────────

class _MediaListPane extends StatelessWidget {
  const _MediaListPane({
    required this.controller,
    required this.libraries,
    required this.storageDescriptors,
    required this.isTriggering,
    required this.onFilterChanged,
    required this.onFilterReset,
    required this.onRefresh,
    required this.onSelectAllOnPage,
    required this.onClearSelection,
    required this.onRapidUpload,
  });

  final MediaBrowseController controller;
  final List<MediaLibraryDto> libraries;
  final Map<int, MediaStorageDescriptor> storageDescriptors;
  final bool isTriggering;
  final ValueChanged<MediaBrowseFilterState> onFilterChanged;
  final VoidCallback onFilterReset;
  final Future<void> Function() onRefresh;
  final VoidCallback onSelectAllOnPage;
  final VoidCallback onClearSelection;
  final Future<void> Function() onRapidUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterTotalHeader(
          leading: MediaBrowseFilterToolbar(
            filterState: controller.filterState,
            libraries: libraries,
            onChanged: onFilterChanged,
            onReset: onFilterReset,
          ),
          totalText: '共 ${controller.total} 条',
          totalKey: const Key('media-management-total-text'),
          trailing: AppIconButton(
            key: const Key('media-management-refresh-button'),
            tooltip: controller.isInitialLoading ? '刷新中' : '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.isInitialLoading ? null : onRefresh,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        _MediaListCard(
          controller: controller,
          storageDescriptors: storageDescriptors,
          onSelectAllOnPage: onSelectAllOnPage,
          onClearSelection: onClearSelection,
          onRapidUpload: onRapidUpload,
          isTriggering: isTriggering,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 媒体列表卡
// ─────────────────────────────────────────────────────────────────────────────

class _MediaListCard extends StatelessWidget {
  const _MediaListCard({
    required this.controller,
    required this.storageDescriptors,
    required this.onSelectAllOnPage,
    required this.onClearSelection,
    required this.onRapidUpload,
    required this.isTriggering,
  });

  final MediaBrowseController controller;
  final Map<int, MediaStorageDescriptor> storageDescriptors;
  final VoidCallback onSelectAllOnPage;
  final VoidCallback onClearSelection;
  final Future<void> Function() onRapidUpload;
  final bool isTriggering;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final selectionCount = controller.selectionCount;
    final hasSelection = selectionCount > 0;
    return AppContentCard(
      title: '媒体列表',
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s16,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerTrailing: Wrap(
        spacing: spacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasSelection)
            Text(
              '已选 $selectionCount 项',
              key: const Key('media-management-selection-count'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.accent,
              ),
            ),
          AppButton(
            key: const Key('media-management-select-all-button'),
            label: '全选本页',
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed: controller.items.isEmpty ? null : onSelectAllOnPage,
          ),
          AppButton(
            key: const Key('media-management-clear-selection-button'),
            label: '清空选择',
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed: hasSelection ? onClearSelection : null,
          ),
          AppButton(
            key: const Key('media-management-rapid-upload-button'),
            label: hasSelection ? '秒传到 115（$selectionCount）' : '秒传到 115',
            size: AppButtonSize.small,
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.cloud_upload_outlined),
            isLoading: isTriggering,
            onPressed: hasSelection && !isTriggering ? onRapidUpload : null,
          ),
        ],
      ),
      headerBottomSpacing: spacing.md,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.isInitialLoading) {
      return const _MediaListLoading();
    }
    if (controller.initialErrorMessage != null) {
      return _MediaListError(
        message: controller.initialErrorMessage!,
        onRetry: () => unawaited(controller.reload()),
        retryKey: const Key('media-management-initial-retry-button'),
      );
    }
    if (controller.items.isEmpty) {
      return const AppEmptyState(
        message: '当前筛选下没有媒体记录。调整筛选条件或稍后再试。',
      );
    }
    return Column(
      children: [
        for (final item in controller.items)
          Padding(
            padding: EdgeInsets.only(bottom: context.appSpacing.sm),
            child: _MediaRow(
              item: item,
              storage: resolveMediaStorageDescriptor(
                item.libraryId,
                storageDescriptors,
              ),
              isSelected: controller.isSelected(item.id),
              onToggle: () => controller.toggleSelection(item.id),
            ),
          ),
        if (controller.isLoadingMore ||
            controller.loadMoreErrorMessage != null) ...[
          SizedBox(height: context.appSpacing.md),
          AppPagedLoadMoreFooter(
            isLoading: controller.isLoadingMore,
            errorMessage: controller.loadMoreErrorMessage,
            onRetry: controller.loadMore,
          ),
        ],
      ],
    );
  }
}

class _MediaListLoading extends StatelessWidget {
  const _MediaListLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.appLayoutTokens.emptySectionVerticalPadding,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
        ),
      ),
    );
  }
}

class _MediaListError extends StatelessWidget {
  const _MediaListError({
    required this.message,
    required this.onRetry,
    required this.retryKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key retryKey;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      message: message,
      onRetry: onRetry,
      retryKey: retryKey,
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.storage,
    required this.isSelected,
    required this.onToggle,
  });

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final backgroundColor =
        isSelected ? colors.selectionSurface : colors.surfaceMuted;
    final borderColor =
        isSelected ? colors.selectionBorder : colors.borderSubtle;
    final coverWidth =
        context.appComponentTokens.mobileFollowMovieThinCoverWidth;
    final coverHeight = context.appComponentTokens.mobileFollowMovieCardHeight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: context.appRadius.mdBorder,
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: Key('media-management-row-checkbox-${item.id}'),
                value: isSelected,
                onChanged: (_) => onToggle(),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(width: spacing.sm),
              _MediaCover(
                item: item,
                width: coverWidth,
                height: coverHeight,
              ),
              SizedBox(width: spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.displayHeading,
                            key: Key('media-management-row-heading-${item.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s14,
                              weight: AppTextWeight.semibold,
                              tone: AppTextTone.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: spacing.sm),
                        _KindBadge(kind: item.kind),
                        if (storage.isCloud115) ...[
                          SizedBox(width: spacing.xs),
                          const AppBadge(
                            label: '115',
                            tone: AppBadgeTone.info,
                          ),
                        ] else if (storage.isLocal) ...[
                          SizedBox(width: spacing.xs),
                          const AppBadge(
                            label: '本地',
                            tone: AppBadgeTone.neutral,
                          ),
                        ],
                        if (!item.valid) ...[
                          SizedBox(width: spacing.xs),
                          const AppBadge(
                            label: '失效',
                            tone: AppBadgeTone.error,
                          ),
                        ],
                      ],
                    ),
                    if (item.displaySubtitle != null) ...[
                      SizedBox(height: spacing.xs),
                      Text(
                        item.displaySubtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                    SizedBox(height: spacing.sm),
                    _MediaMetaLine(item: item, storage: storage),
                    SizedBox(height: spacing.xs),
                    Text(
                      _storageLocationText(item, storage),
                      key: Key('media-management-row-path-${item.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _storageLocationText(
    MediaListItemDto item,
    MediaStorageDescriptor storage,
  ) {
    final raw = item.path.trim();
    if (storage.isCloud115 && raw.startsWith('cloud115:')) {
      final fileName = raw.substring('cloud115:'.length).trim();
      return fileName.isEmpty ? '115 网盘媒体' : fileName;
    }
    return raw.isEmpty ? storage.sourceLabel : raw;
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final MediaListItemKind kind;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: kind.label,
      tone: kind == MediaListItemKind.jav
          ? AppBadgeTone.primary
          : AppBadgeTone.neutral,
    );
  }
}

class _MediaCover extends StatelessWidget {
  const _MediaCover({
    required this.item,
    required this.width,
    required this.height,
  });

  final MediaListItemDto item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = item.preferredCoverUrl;
    return ClipRRect(
      borderRadius: context.appRadius.mdBorder,
      child: SizedBox(
        width: width,
        height: height,
        child: url == null || url.isEmpty
            ? DecoratedBox(
                key: Key('media-management-cover-placeholder-${item.id}'),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceCard,
                ),
                child: Icon(
                  Icons.movie_creation_outlined,
                  size: context.appComponentTokens.iconSize2xl,
                  color: context.appTextPalette.muted,
                ),
              )
            : MaskedImage(
                key: Key('media-management-cover-${item.id}'),
                url: url,
                fit: item.usesThinCover ? BoxFit.cover : BoxFit.contain,
              ),
      ),
    );
  }
}

class _MediaMetaLine extends StatelessWidget {
  const _MediaMetaLine({required this.item, required this.storage});

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final parts = <String>[
      _libraryText(),
      formatFileSize(item.fileSizeBytes),
      if (item.durationSeconds > 0)
        formatMediaDurationLabel(item.durationSeconds),
      if (item.resolution != null && item.resolution!.isNotEmpty)
        item.resolution!,
      if (item.updatedAt != null)
        '更新 ${formatUpdatedAtLabel(item.updatedAt) ?? '未知'}',
    ];
    return Wrap(
      spacing: spacing.md,
      runSpacing: spacing.xs,
      children: [
        for (final part in parts)
          Text(
            part,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
      ],
    );
  }

  String _libraryText() {
    final name = storage.normalizedLibraryName;
    if (name != null) {
      return storage.isCloud115 ? '$name（115）' : name;
    }
    if (item.libraryId == null) {
      return '媒体库已删除';
    }
    return '媒体库 ${item.libraryId}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 秒传批次历史卡
// ─────────────────────────────────────────────────────────────────────────────

class _RapidUploadHistoryCard extends StatelessWidget {
  const _RapidUploadHistoryCard({
    required this.controller,
    required this.libraries,
    required this.onRetry,
    required this.retryingBatchId,
  });

  final MediaRapidUploadHistoryController controller;
  final List<MediaLibraryDto> libraries;
  final Future<void> Function(MediaRapidUploadBatchListItemDto batch) onRetry;
  final int? retryingBatchId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      title: '秒传批次',
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s16,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerTrailing: AppIconButton(
        key: const Key('media-management-batch-refresh-button'),
        tooltip: '刷新批次',
        onPressed: controller.isInitialLoading
            ? null
            : () => unawaited(controller.reload()),
        icon: const Icon(Icons.refresh_rounded),
      ),
      headerBottomSpacing: spacing.md,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.isInitialLoading) {
      return const _MediaListLoading();
    }
    if (controller.initialErrorMessage != null) {
      return _MediaListError(
        message: controller.initialErrorMessage!,
        onRetry: () => unawaited(controller.reload()),
        retryKey: const Key('media-management-batch-retry-button'),
      );
    }
    if (controller.items.isEmpty) {
      return const AppEmptyState(
        message: '暂无秒传批次记录。选择媒体后可以从上方发起秒传。',
      );
    }
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final batch in controller.items)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: _RapidUploadBatchRow(
              batch: batch,
              libraries: libraries,
              isRetrying: retryingBatchId == batch.id,
              canRetry: retryingBatchId == null &&
                  batch.state.isTerminal &&
                  batch.hasRetryable,
              onRetry: () => unawaited(onRetry(batch)),
            ),
          ),
        if (controller.isLoadingMore ||
            controller.loadMoreErrorMessage != null) ...[
          SizedBox(height: spacing.md),
          AppPagedLoadMoreFooter(
            isLoading: controller.isLoadingMore,
            errorMessage: controller.loadMoreErrorMessage,
            onRetry: controller.loadMore,
          ),
        ],
      ],
    );
    // 批次 tab 独占页面滚动，翻页由 `_DesktopMediaManagementPageState._handleScroll`
    // 在滚到底时调 `_batchController.loadMore()` 触发，不再需要显式加载按钮。
  }
}

class _RapidUploadBatchRow extends StatelessWidget {
  const _RapidUploadBatchRow({
    required this.batch,
    required this.libraries,
    required this.isRetrying,
    required this.canRetry,
    required this.onRetry,
  });

  final MediaRapidUploadBatchListItemDto batch;
  final List<MediaLibraryDto> libraries;
  final bool isRetrying;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '批次 #${batch.id}',
                      key: Key('rapid-upload-batch-id-${batch.id}'),
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    AppBadge(
                      label: batch.state.label,
                      tone: _batchStateTone(batch.state),
                    ),
                    if (batch.retryOfBatchId != null) ...[
                      SizedBox(width: spacing.sm),
                      AppBadge(
                        label: '重试 #${batch.retryOfBatchId}',
                        tone: AppBadgeTone.info,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  '目标：${_targetLibraryName()}',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  _countsText(),
                  key: Key('rapid-upload-batch-counts-${batch.id}'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  _timeText(),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.md),
          if (canRetry || isRetrying)
            AppButton(
              key: Key('rapid-upload-batch-retry-${batch.id}'),
              label: isRetrying ? '重试中' : '重试失败项',
              size: AppButtonSize.small,
              variant: AppButtonVariant.secondary,
              isLoading: isRetrying,
              icon: const Icon(Icons.replay_rounded),
              onPressed: canRetry ? onRetry : null,
            ),
        ],
      ),
    );
  }

  String _targetLibraryName() {
    for (final library in libraries) {
      if (library.id == batch.targetLibraryId) {
        return library.isCloud115
            ? '${library.name}（115）'
            : library.name;
      }
    }
    return '媒体库 ${batch.targetLibraryId}';
  }

  String _countsText() {
    final parts = <String>[
      '共 ${batch.totalCount} 项',
      '成功 ${batch.succeededCount}',
      if (batch.failedCount > 0) '失败 ${batch.failedCount}',
      if (batch.cleanupFailedCount > 0)
        '清理失败 ${batch.cleanupFailedCount}',
      if (batch.pendingCount > 0) '进行中 ${batch.pendingCount}',
    ];
    return parts.join(' · ');
  }

  String _timeText() {
    final finished = batch.finishedAt;
    if (finished != null) {
      final label = formatUpdatedAtLabel(finished);
      return '结束于 ${label ?? '未知时间'}';
    }
    final started = batch.startedAt ?? batch.createdAt;
    if (started != null) {
      final label = formatUpdatedAtLabel(started);
      return '${batch.state.isRunning ? '进行中 · 开始于 ' : '创建于 '}${label ?? '未知时间'}';
    }
    return '时间未知';
  }
}

AppBadgeTone _batchStateTone(MediaRapidUploadBatchState state) {
  return switch (state) {
    MediaRapidUploadBatchState.pending => AppBadgeTone.info,
    MediaRapidUploadBatchState.running => AppBadgeTone.info,
    MediaRapidUploadBatchState.completed => AppBadgeTone.success,
    MediaRapidUploadBatchState.completedWithErrors => AppBadgeTone.warning,
    MediaRapidUploadBatchState.failed => AppBadgeTone.error,
    MediaRapidUploadBatchState.unknown => AppBadgeTone.neutral,
  };
}
