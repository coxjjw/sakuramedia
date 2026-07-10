import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// LLM 后端目前只返回 `{ok: bool}`，前端只能给通用兜底文案；错误细分只能等后端改造。
const Map<String, DiagnosticHint> llmHints = <String, DiagnosticHint>{
  'disabled': DiagnosticHint(
    cause: 'LLM 翻译总开关关着，跳过本次检测。',
    fixHint: '若需要影片信息中文化，打开「LLM」页启用并填 URL / API Key / 模型。',
    impact: '影片信息只显示原始语言；封面上的标签会保持原文。',
    fixTarget: DiagnosticFixTarget.configurationTab(4),
  ),
  'not-configured': DiagnosticHint(
    cause: '启用了 LLM 但 URL / API Key / 模型至少有一个是空的。',
    fixHint: '打开「LLM」页把三个字段补齐，或先关掉开关。',
    impact: '任何触发 LLM 翻译的请求都会立即失败。',
    fixTarget: DiagnosticFixTarget.configurationTab(4),
  ),
  'unknown': DiagnosticHint(
    cause:
        '测试请求失败。可能是 base URL / 模型名错、API Key 无效、供应商配额用尽，或网络不通。',
    fixHint:
        '打开「LLM」页核对 URL 是否包含 `/v1`、模型名与供应商列表一致；换一个免费模型 (例如 gpt-4o-mini) 快速验证；确认后端容器能出站。',
    impact: '影片信息的中文化不可用；也影响自动翻译流水线。',
    fixTarget: DiagnosticFixTarget.configurationTab(4),
  ),
};
