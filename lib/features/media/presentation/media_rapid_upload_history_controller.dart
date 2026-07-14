import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

/// 秒传批次历史控制器：只读分页 + 单批次覆盖更新（触发/重试成功后可就地
/// 把最新详情合并进列表，避免整页 reload）。
class MediaRapidUploadHistoryController
    extends PagedLoadController<MediaRapidUploadBatchListItemDto> {
  MediaRapidUploadHistoryController({
    required MediaApi mediaApi,
    super.pageSize = 20,
    super.scrollController,
  })  : _mediaApi = mediaApi,
        super(
          initialPage: 1,
          fetchPage: (page, pageSize) =>
              mediaApi.getMediaRapidUploads(page: page, pageSize: pageSize),
          initialLoadErrorText: '秒传批次加载失败，请稍后重试',
          loadMoreErrorText: '加载更多秒传批次失败，请点击重试',
        );

  final MediaApi _mediaApi;

  /// 把服务端返回的最新批次合并进列表：
  /// 已存在 → 覆盖；不存在 → 插到最前。
  void upsertBatch(MediaRapidUploadBatchListItemDto batch) {
    final index = mutableItems.indexWhere((item) => item.id == batch.id);
    if (index >= 0) {
      mutableItems[index] = batch;
    } else {
      mutableItems.insert(0, batch);
      mutableTotal = mutableTotal + 1;
    }
    notifyListenersSafely();
  }

  /// 拉某个批次的最新详情，成功后 upsert。
  Future<MediaRapidUploadBatchDto> refreshBatch(int batchId) async {
    final detail = await _mediaApi.getMediaRapidUpload(batchId: batchId);
    if (!isDisposed) {
      upsertBatch(detail);
    }
    return detail;
  }
}
