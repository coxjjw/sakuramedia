import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_controller.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/widgets/media_browse_filter_toolbar.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selectable_tile.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 「媒体管理」页的媒体列表 tab 主体：筛选头 + 列表卡。
///
/// 状态由父页面注入（controller / callbacks），本文件只承载展示。
class MediaListPane extends StatelessWidget {
  const MediaListPane({
    super.key,
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
      return const AppSectionSkeleton(lineCount: 6);
    }
    if (controller.initialErrorMessage != null) {
      return AppEmptyState(
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
    final coverWidth =
        context.appComponentTokens.mobileFollowMovieThinCoverWidth;
    final coverHeight = context.appComponentTokens.mobileFollowMovieCardHeight;

    return AppSelectableTile(
      selected: isSelected,
      onTap: onToggle,
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
          _MediaCover(item: item, width: coverWidth, height: coverHeight),
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
                    AppBadge(
                      label: item.kind.label,
                      tone: item.kind == MediaListItemKind.jav
                          ? AppBadgeTone.primary
                          : AppBadgeTone.neutral,
                    ),
                    if (storage.isCloud115) ...[
                      SizedBox(width: spacing.xs),
                      const AppBadge(label: '115', tone: AppBadgeTone.info),
                    ] else if (storage.isLocal) ...[
                      SizedBox(width: spacing.xs),
                      const AppBadge(
                        label: '本地',
                        tone: AppBadgeTone.neutral,
                      ),
                    ],
                    if (!item.valid) ...[
                      SizedBox(width: spacing.xs),
                      const AppBadge(label: '失效', tone: AppBadgeTone.error),
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
