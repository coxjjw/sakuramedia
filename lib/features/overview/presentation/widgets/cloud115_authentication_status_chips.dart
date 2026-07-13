import 'package:flutter/material.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

class Cloud115AuthenticationStatusChips extends StatelessWidget {
  const Cloud115AuthenticationStatusChips({
    super.key,
    required this.summary,
    required this.isTesting,
    required this.requestFailed,
    this.keyPrefix = 'overview',
  });

  final StatusCloud115CookieSummaryDto? summary;
  final bool isTesting;
  final bool requestFailed;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.appSpacing.xs,
      runSpacing: context.appSpacing.xs,
      children: _buildChips(context),
    );
  }

  List<Widget> _buildChips(BuildContext context) {
    if (isTesting) {
      return <Widget>[
        _chip(
          context,
          id: 'testing',
          label: '检测中',
          palette: _neutralPalette(context),
          isBusy: true,
        ),
      ];
    }
    if (requestFailed) {
      return <Widget>[
        _chip(
          context,
          id: 'failed',
          label: '检测失败',
          palette: _errorPalette(context),
        ),
      ];
    }

    final current = summary;
    if (current == null) {
      return <Widget>[
        _chip(
          context,
          id: 'not-tested',
          label: '未检测',
          palette: _neutralPalette(context),
        ),
      ];
    }
    if (current.total == 0) {
      return <Widget>[
        _chip(
          context,
          id: 'not-configured',
          label: '未配置',
          palette: _neutralPalette(context),
        ),
      ];
    }

    final problems = <Widget>[];
    if (current.expired > 0) {
      problems.add(
        _chip(
          context,
          id: 'expired',
          label: '认证失效',
          detail: current.expired.toString(),
          palette: _errorPalette(context),
        ),
      );
    }
    if (current.unavailable > 0) {
      problems.add(
        _chip(
          context,
          id: 'unavailable',
          label: '暂不可用',
          detail: current.unavailable.toString(),
          palette: _warningPalette(context),
        ),
      );
    }
    if (problems.isNotEmpty) {
      return problems;
    }

    return <Widget>[
      _chip(
        context,
        id: 'alive',
        label: '全部正常',
        detail: '${current.alive}/${current.total}',
        palette: _successPalette(context),
      ),
    ];
  }

  Widget _chip(
    BuildContext context, {
    required String id,
    required String label,
    required AppStatusChipPalette palette,
    String? detail,
    bool isBusy = false,
  }) {
    return AppStatusChip(
      key: Key('$keyPrefix-cloud115-authentication-$id'),
      label: label,
      detail: detail,
      palette: palette,
      isBusy: isBusy,
      dense: true,
    );
  }

  AppStatusChipPalette _neutralPalette(BuildContext context) {
    return AppStatusChipPalette(
      background: context.appColors.surfaceMuted,
      borderColor: context.appColors.borderSubtle,
      tone: AppTextTone.secondary,
      foreground: context.appTextPalette.secondary,
      icon: Icons.radio_button_unchecked,
    );
  }

  AppStatusChipPalette _successPalette(BuildContext context) {
    return AppStatusChipPalette(
      background: context.appColors.successSurface,
      borderColor: null,
      tone: AppTextTone.success,
      foreground: resolveAppTextToneColor(context, AppTextTone.success),
      icon: Icons.check_circle_outline,
    );
  }

  AppStatusChipPalette _warningPalette(BuildContext context) {
    return AppStatusChipPalette(
      background: context.appColors.warningSurface,
      borderColor: null,
      tone: AppTextTone.warning,
      foreground: resolveAppTextToneColor(context, AppTextTone.warning),
      icon: Icons.warning_amber_rounded,
    );
  }

  AppStatusChipPalette _errorPalette(BuildContext context) {
    return AppStatusChipPalette(
      background: context.appColors.errorSurface,
      borderColor: null,
      tone: AppTextTone.error,
      foreground: resolveAppTextToneColor(context, AppTextTone.error),
      icon: Icons.error_outline,
    );
  }
}
