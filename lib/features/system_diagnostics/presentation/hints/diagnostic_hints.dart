import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';

/// 「三段式」诊断文案：一次告诉用户"为什么挂 / 怎么改 / 影响是啥"。
///
/// 每个 hintKey 对应一份定案的 [DiagnosticHint]。key 命名规则：
/// `<component>-<situation>`，例如 `downloader-network-error`。全部走前端硬编码，
/// 后端不需要为此改结构化 error type。
@immutable
class DiagnosticHint {
  const DiagnosticHint({
    required this.cause,
    required this.fixHint,
    required this.impact,
    this.fixTarget,
  });

  final String cause;
  final String fixHint;
  final String impact;
  final DiagnosticFixTarget? fixTarget;
}
