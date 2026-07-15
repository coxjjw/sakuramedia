import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

/// 「媒体管理」列表控制器：
/// - 分页拉取全局 `/media`；
/// - 持有 [filterState]，UI 改完调用 [applyFilterState] 触发 reload；
/// - 维护多选 [selectedIds]，供批量秒传等操作使用。
///
/// 参考 `PagedLoadController` 约定：筛选状态不放进基类 fetcher 而是闭包捕获，
/// UI 修改 filterState 后需显式 reload 才生效。
class MediaBrowseController extends PagedLoadController<MediaListItemDto> {
  MediaBrowseController({
    required MediaApi mediaApi,
    MediaBrowseFilterState initialFilterState = const MediaBrowseFilterState(),
    super.pageSize = 30,
    super.loadMoreTriggerOffset = 400,
    super.scrollController,
  })  : _mediaApi = mediaApi,
        _filterState = initialFilterState,
        super(
          initialPage: 1,
          fetchPage: (_, __) =>
              throw UnimplementedError('由 fetchPage override 提供闭包实现'),
          initialLoadErrorText: '媒体列表加载失败，请稍后重试',
          loadMoreErrorText: '加载更多媒体失败，请点击重试',
        );

  final MediaApi _mediaApi;
  MediaBrowseFilterState _filterState;
  final Set<int> _selectedIds = <int>{};

  MediaBrowseFilterState get filterState => _filterState;

  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);

  int get selectionCount => _selectedIds.length;

  bool isSelected(int id) => _selectedIds.contains(id);

  /// 应用新的筛选状态。变化后会清空多选并 reload（若未变化则短路）。
  ///
  /// 依赖 [reload] 覆写会 `_selectedIds.clear() + notifyListenersSafely()`，
  /// 这里只更新 `_filterState` 就行，避免双通知。
  Future<void> applyFilterState(MediaBrowseFilterState next) {
    if (next == _filterState) {
      return Future<void>.value();
    }
    _filterState = next;
    return reload();
  }

  @override
  Future<void> reload() {
    _selectedIds.clear();
    return super.reload();
  }

  @override
  Future<void> initialize() {
    _selectedIds.clear();
    return super.initialize();
  }

  @override
  Future<PaginatedResponseDto<MediaListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    final filter = _filterState;
    return _mediaApi.getMediaList(
      page: page,
      pageSize: pageSize,
      kind: mediaBrowseKindWire(filter.kind),
      libraryId: filter.libraryId,
      sort: filter.sortWire,
    );
  }

  void toggleSelection(int id) {
    if (!_selectedIds.remove(id)) {
      _selectedIds.add(id);
    }
    notifyListenersSafely();
  }

  void setSelected(int id, bool selected) {
    final changed = selected ? _selectedIds.add(id) : _selectedIds.remove(id);
    if (changed) {
      notifyListenersSafely();
    }
  }

  /// 选中当前已加载页面里的全部（非叠加所有页）。
  void selectAllLoaded() {
    var changed = false;
    for (final item in items) {
      if (_selectedIds.add(item.id)) {
        changed = true;
      }
    }
    if (changed) {
      notifyListenersSafely();
    }
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) {
      return;
    }
    _selectedIds.clear();
    notifyListenersSafely();
  }

  /// 秒传触发成功后，从本地列表中把已进入批次的条目移除，避免用户再次选中。
  void removeItemsByIds(Iterable<int> ids) {
    final targets = ids.toSet();
    if (targets.isEmpty) {
      return;
    }
    final beforeLength = mutableItems.length;
    mutableItems.removeWhere((item) => targets.contains(item.id));
    final removed = beforeLength - mutableItems.length;
    if (removed > 0) {
      mutableTotal = mutableTotal - removed;
      if (mutableTotal < 0) {
        mutableTotal = 0;
      }
    }
    _selectedIds.removeAll(targets);
    notifyListenersSafely();
  }
}
