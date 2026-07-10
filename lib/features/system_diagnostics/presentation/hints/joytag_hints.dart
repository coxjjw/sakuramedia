import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// JoyTag 模型部署在后端，前端没有可配置的入口；所以 fixTarget 一律留空。
const Map<String, DiagnosticHint> joyTagHints = <String, DiagnosticHint>{
  'unhealthy': DiagnosticHint(
    cause: 'JoyTag 推理服务不可用：模型没加载、GPU 没释放、或 Python 依赖丢了。',
    fixHint:
        '在部署后端的机器上查看 sakuramedia backend 日志（关键字 joytag），确认模型权重文件与 CUDA 驱动可用。',
    impact: '以图搜图不可用；影片入库时的自动打标签会跳过。',
  ),
};
