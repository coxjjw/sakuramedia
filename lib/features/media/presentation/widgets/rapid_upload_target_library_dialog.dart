import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selectable_tile.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 秒传目标 115 网盘挑选弹窗。
///
/// - 无 115 库时给一个明确的空态引导用户先去「媒体库」tab 新建；
/// - 只有一个 115 库时默认选中它；
/// - 用户点击确认返回选中的 [MediaLibraryDto]，取消返回 `null`。
Future<MediaLibraryDto?> showRapidUploadTargetLibraryDialog(
  BuildContext context, {
  required int selectedCount,
  required List<MediaLibraryDto> libraries,
}) {
  return showDialog<MediaLibraryDto>(
    context: context,
    builder: (dialogContext) {
      return AppDesktopDialog(
        dialogKey: const Key('rapid-upload-target-library-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: _RapidUploadTargetBody(
          selectedCount: selectedCount,
          libraries: libraries,
        ),
      );
    },
  );
}

class _RapidUploadTargetBody extends StatefulWidget {
  const _RapidUploadTargetBody({
    required this.selectedCount,
    required this.libraries,
  });

  final int selectedCount;
  final List<MediaLibraryDto> libraries;

  @override
  State<_RapidUploadTargetBody> createState() => _RapidUploadTargetBodyState();
}

class _RapidUploadTargetBodyState extends State<_RapidUploadTargetBody> {
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    if (widget.libraries.length == 1) {
      _selectedId = widget.libraries.first.id;
    }
  }

  MediaLibraryDto? get _selectedLibrary {
    if (_selectedId == null) {
      return null;
    }
    for (final library in widget.libraries) {
      if (library.id == _selectedId) {
        return library;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final hasLibraries = widget.libraries.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '秒传到 115',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        Text(
          '已选 ${widget.selectedCount} 项本地媒体。选择目标 115 网盘后，'
          '系统会创建后台批次逐个秒传；成功的条目会切换到云端并删除本地文件。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        if (!hasLibraries)
          const AppEmptyState(
            message: '尚未配置任何 115 网盘媒体库。请到「媒体库」中先扫码创建一个 115 库。',
          )
        else
          _LibraryList(
            libraries: widget.libraries,
            selectedId: _selectedId,
            onSelected: (id) => setState(() => _selectedId = id),
          ),
        SizedBox(height: spacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('rapid-upload-target-cancel-button'),
                label: '取消',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('rapid-upload-target-confirm-button'),
                label: '开始秒传',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: _selectedLibrary == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedLibrary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({
    required this.libraries,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MediaLibraryDto> libraries;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      children: [
        for (final library in libraries)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: _LibraryTile(
              library: library,
              selected: library.id == selectedId,
              onTap: () => onSelected(library.id),
            ),
          ),
      ],
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.library,
    required this.selected,
    required this.onTap,
  });

  final MediaLibraryDto library;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppSelectableTile(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Radio<int>(
            key: Key('rapid-upload-target-radio-${library.id}'),
            value: library.id,
            groupValue: selected ? library.id : null,
            onChanged: (_) => onTap(),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        library.name,
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
                    const AppBadge(label: '115 网盘', tone: AppBadgeTone.info),
                  ],
                ),
                if (library.rootCid.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    '根目录 CID：${library.rootCid}',
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
