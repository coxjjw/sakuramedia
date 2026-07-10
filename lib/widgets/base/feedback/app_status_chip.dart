import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 已解析好的状态徽章调色板。各业务方维护自己的状态枚举 →
/// [AppStatusChipPalette] 映射，只共享 [AppStatusChip] 的渲染逻辑。
@immutable
class AppStatusChipPalette {
  const AppStatusChipPalette({
    required this.background,
    required this.borderColor,
    required this.tone,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color? borderColor;
  final AppTextTone tone;
  final Color foreground;
  final IconData icon;
}

/// 状态徽章的纯展示层：`[图标或 spinner] 标签 (可选 detail)`，圆角色块底。
///
/// 不含交互逻辑（点击/tooltip 由调用方按需包一层）；调用方只需提供已解析好的
/// [AppStatusChipPalette]。用于统一「探针/诊断类状态指示」的视觉语言，
/// 避免每个 feature 各自重写一份容器 + 调色板代码。
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.palette,
    this.isBusy = false,
    this.detail,
    this.dense = false,
  });

  final String label;
  final AppStatusChipPalette palette;

  /// true 时用 spinner 替代 [AppStatusChipPalette.icon]（例如"检测中"态）。
  final bool isBusy;
  final String? detail;

  /// dense=true 用在需要更紧凑的横条/阵列场景（矮一点、字更小）。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final iconSize = context.appComponentTokens.iconSize2xs;
    final textSize = dense ? AppTextSize.s10 : AppTextSize.s12;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: dense ? spacing.xs / 2 : spacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: context.appRadius.smBorder,
        border: palette.borderColor == null
            ? null
            : Border.all(color: palette.borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy)
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: palette.foreground,
              ),
            )
          else
            Icon(palette.icon, size: iconSize, color: palette.foreground),
          SizedBox(width: spacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: textSize,
              weight: AppTextWeight.medium,
              tone: palette.tone,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            SizedBox(width: spacing.xs),
            Text(
              detail!,
              style: resolveAppTextStyle(
                context,
                size: textSize,
                weight: AppTextWeight.regular,
                tone: palette.tone,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
