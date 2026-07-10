import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/controllers/system_diagnostics_controller.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_status_badge.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 概览页顶部一条紧凑横条：
/// - notTested：显示 CTA「开始检测」
/// - probing：显示进度 + "取消"（第一期 disabled）
/// - healthy/warning/unhealthy：显示 6 个分组徽章 + 上次检测时间 + 「刷新」/「进入诊断页」
///
/// Strip 内部自建 controller（跟 [OverviewSystemInfoController] 一样在 initState
/// 里 new + dispose 释放）；不进 app.dart 全局 provider。诊断页会另建一份自己的
/// controller，两份状态互不共享——用户视角常见的操作路径是"strip 上看一眼→进
/// 诊断页点重新检测"，两份状态各自独立没问题。
class SystemDiagnosticsStrip extends StatefulWidget {
  const SystemDiagnosticsStrip({super.key});

  @override
  State<SystemDiagnosticsStrip> createState() => _SystemDiagnosticsStripState();
}

class _SystemDiagnosticsStripState extends State<SystemDiagnosticsStrip> {
  late final SystemDiagnosticsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SystemDiagnosticsController(
      mediaLibrariesApi: context.read<MediaLibrariesApi>(),
      downloadClientsApi: context.read<DownloadClientsApi>(),
      indexerSettingsApi: context.read<IndexerSettingsApi>(),
      statusApi: context.read<StatusApi>(),
      llmApi: context.read<MovieDescTranslationSettingsApi>(),
    )..addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final controller = _controller;
    final overall = controller.overallStatus;
    final hasRun = controller.lastRunAt != null;

    return AppContentCard(
      key: const Key('system-diagnostics-strip'),
      title: '组件诊断',
      headerBottomSpacing: spacing.md,
      headerTrailing: _buildHeaderTrailing(context, hasRun, overall),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xl,
        vertical: spacing.lg,
      ),
      child: _buildBody(context, controller),
    );
  }

  Widget _buildHeaderTrailing(
    BuildContext context,
    bool hasRun,
    DiagnosticItemStatus overall,
  ) {
    if (_controller.isRunning || !hasRun) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          key: const Key('system-diagnostics-strip-refresh'),
          tooltip: '重新检测',
          semanticLabel: '重新检测',
          size: AppIconButtonSize.mini,
          icon: const Icon(Icons.refresh),
          onPressed: _controller.runAll,
        ),
        SizedBox(width: context.appSpacing.xs),
        AppIconButton(
          key: const Key('system-diagnostics-strip-open'),
          tooltip: '打开组件诊断页',
          semanticLabel: '打开组件诊断页',
          size: AppIconButtonSize.mini,
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => context.pushDesktopSystemDiagnostics(),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, SystemDiagnosticsController c) {
    final spacing = context.appSpacing;
    if (c.isRunning) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: context.appComponentTokens.iconSizeSm,
            height: context.appComponentTokens.iconSizeSm,
            child: CircularProgressIndicator(
              strokeWidth:
                  context.appComponentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              '正在检测组件 ${c.completedItemCount}/${c.totalItemCount}…',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
        ],
      );
    }

    if (c.lastRunAt == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '一键检测媒体库、下载器、索引器、外部数据源、LLM 与 JoyTag 的连通性。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          SizedBox(width: spacing.md),
          AppButton(
            key: const Key('system-diagnostics-strip-start'),
            label: '开始检测',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            icon: const Icon(Icons.radar_rounded),
            onPressed: c.runAll,
          ),
        ],
      );
    }

    // 已完成一次。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: <Widget>[
            for (final cat in c.categories)
              DiagnosticStatusBadge(
                key: Key('system-diagnostics-strip-badge-${cat.label}'),
                label: cat.label,
                status: cat.aggregate,
                dense: true,
                detail: _detailForCategory(cat),
              ),
          ],
        ),
        SizedBox(height: spacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                _buildFooterLine(c),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: c.unhealthyCount > 0
                      ? AppTextTone.error
                      : AppTextTone.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _detailForCategory(DiagnosticCategoryState cat) {
    final unhealthy = cat.items
        .where((i) => i.status == DiagnosticItemStatus.unhealthy)
        .length;
    if (unhealthy > 0) return '$unhealthy';
    return null;
  }

  String _buildFooterLine(SystemDiagnosticsController c) {
    final rel = _formatRelativeTime(c.lastRunAt!);
    if (c.unhealthyCount > 0) {
      return '$rel · ${c.unhealthyCount} 项异常';
    }
    return '$rel · 全部通过';
  }

  static String _formatRelativeTime(DateTime moment) {
    final diff = DateTime.now().difference(moment);
    if (diff.inSeconds < 60) return '刚刚检测';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前检测';
    if (diff.inHours < 24) return '${diff.inHours} 小时前检测';
    return '${diff.inDays} 天前检测';
  }
}
