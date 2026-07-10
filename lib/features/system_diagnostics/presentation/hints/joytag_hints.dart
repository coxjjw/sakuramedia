import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// JoyTag 模型部署在后端，前端没有可配置的入口；所以 fixTarget 一律留空。
const Map<String, DiagnosticHint> joyTagHints = <String, DiagnosticHint>{
  'unhealthy': DiagnosticHint(
    cause: 'JoyTag 推理服务不可用。',
    fixHint:
        '在部署后端的机器上查看 joytag-infer 日志。',
    impact: '以图搜图不可用；推荐时刻不可用。',
  ),
};
