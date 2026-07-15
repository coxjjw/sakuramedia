import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_controller.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/media_rapid_upload_history_controller.dart';
import 'package:sakuramedia/features/media/presentation/widgets/media_list_pane.dart';
import 'package:sakuramedia/features/media/presentation/widgets/rapid_upload_history_card.dart';
import 'package:sakuramedia/features/media/presentation/widgets/rapid_upload_target_library_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';
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
                RapidUploadHistoryCard(
                  controller: _batchController,
                  libraries: _libraries,
                  onRetry: _retryBatch,
                  retryingBatchId: _retryingBatchId,
                )
              else
                MediaListPane(
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

