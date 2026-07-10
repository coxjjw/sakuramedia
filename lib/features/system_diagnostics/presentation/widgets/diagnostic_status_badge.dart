import 'package:flutter/material.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

/// 6 态状态徽章 —— 覆盖单项和大类聚合两种使用场景。
///
/// 视觉与 [DownloadClientProbeStatusChip]（configuration feature）共用同一套
/// [AppStatusChip] 渲染层；这里独立成组件是因为多了 `blocked` 一态，且不需要
/// chip 的点击/tooltip 交互。
class DiagnosticStatusBadge extends StatelessWidget {
  const DiagnosticStatusBadge({
    super.key,
    required this.label,
    required this.status,
    this.detail,
    this.dense = false,
  });

  final String label;
  final DiagnosticItemStatus status;
  final String? detail;

  /// [dense]=true 用在横条 chip 阵列（矮一点、字更紧）。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(
      label: label,
      palette: _resolvePalette(context, status),
      isBusy: status == DiagnosticItemStatus.probing,
      detail: detail,
      dense: dense,
    );
  }

  AppStatusChipPalette _resolvePalette(
    BuildContext context,
    DiagnosticItemStatus status,
  ) {
    final colors = context.appColors;
    switch (status) {
      case DiagnosticItemStatus.notTested:
        return AppStatusChipPalette(
          background: colors.surfaceMuted,
          borderColor: colors.borderSubtle,
          tone: AppTextTone.secondary,
          foreground: context.appTextPalette.secondary,
          icon: Icons.radio_button_unchecked,
        );
      case DiagnosticItemStatus.probing:
        return AppStatusChipPalette(
          background: colors.surfaceMuted,
          borderColor: colors.borderSubtle,
          tone: AppTextTone.secondary,
          foreground: context.appTextPalette.secondary,
          icon: Icons.hourglass_top,
        );
      case DiagnosticItemStatus.healthy:
        return AppStatusChipPalette(
          background: colors.successSurface,
          borderColor: null,
          tone: AppTextTone.success,
          foreground: resolveAppTextToneColor(context, AppTextTone.success),
          icon: Icons.check_circle_outline,
        );
      case DiagnosticItemStatus.warning:
        return AppStatusChipPalette(
          background: colors.warningSurface,
          borderColor: null,
          tone: AppTextTone.warning,
          foreground: resolveAppTextToneColor(context, AppTextTone.warning),
          icon: Icons.warning_amber_rounded,
        );
      case DiagnosticItemStatus.unhealthy:
        return AppStatusChipPalette(
          background: colors.errorSurface,
          borderColor: null,
          tone: AppTextTone.error,
          foreground: resolveAppTextToneColor(context, AppTextTone.error),
          icon: Icons.error_outline,
        );
      case DiagnosticItemStatus.blocked:
        return AppStatusChipPalette(
          background: colors.surfaceMuted,
          borderColor: colors.borderSubtle,
          tone: AppTextTone.muted,
          foreground: context.appTextPalette.muted,
          icon: Icons.block,
        );
    }
  }
}
