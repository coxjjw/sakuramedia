import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// JavDB / DMM 共用一套 hint。JavDB 需要账号密码 + 可能需要代理；DMM 完全无前端可
/// 配置字段（受 IP/UA 限制），所以 fixTarget 只在 JavDB 相关分支给。
const Map<String, DiagnosticHint> javdbHints = <String, DiagnosticHint>{
  'account-required': DiagnosticHint(
    cause: 'JavDB 拒绝了当前账号（多半是没配 cookie / 账号密码，或者被临时封了）。',
    fixHint: '打开「高级设置」→ JavDB，重新填 cookie 或账号密码；如果被封需要换 IP / 隔天再试。',
    impact: '影片详情里的女优信息、评分、评论获取不到；订阅新片也会漏。',
    fixTarget: DiagnosticFixTarget.configurationTab(6),
  ),
  'proxy-required': DiagnosticHint(
    cause: '当前网络访问不了 JavDB，通常需要走代理。',
    fixHint: '在「高级设置」中确认代理配置有效；确保后端容器能通过代理访问 javdb.com。',
    impact: '影片详情里的女优信息、评分、评论获取不到；订阅新片会失败。',
    fixTarget: DiagnosticFixTarget.configurationTab(6),
  ),
  'dmm-blocked': DiagnosticHint(
    cause: 'DMM 因 IP 归属地 / UA 检测拒绝了本次请求（对日本以外 IP 有限制）。',
    fixHint: '一般需要走日本 IP 的代理让后端出站；DMM 在前端没有直接可配置的字段。',
    impact: '影片详情的封面、日文标题、系列信息可能会缺；不影响其他数据源。',
    fixTarget: null,
  ),
  'unknown': DiagnosticHint(
    cause: '数据源返回了未识别的错误。',
    fixHint:
        '再点一次重新检测确认不是偶发；若持续失败，查看后端日志确认是网络还是解析错误。',
    impact: '影片详情的部分外部字段会缺失；不阻塞下载和播放。',
    fixTarget: null,
  ),
};

/// 根据探针 error message 关键字判定，命中不到就返回 `unknown`。
///
/// [provider] 用来在 DMM 上覆写默认的 `unknown` 为 `dmm-blocked`（DMM 挂了绝
/// 大多数场景就是 IP 被拒）。
String resolveMetadataProviderHintKey({
  required String provider,
  StatusMetadataProviderTestErrorDto? error,
}) {
  final message = error?.message.toLowerCase() ?? '';
  if (message.contains('account') ||
      message.contains('login') ||
      message.contains('unauthorized') ||
      message.contains('cookie')) {
    return 'account-required';
  }
  if (message.contains('proxy') ||
      message.contains('timeout') ||
      message.contains('unreachable') ||
      message.contains('connection')) {
    return 'proxy-required';
  }
  if (provider == 'dmm') {
    return 'dmm-blocked';
  }
  return 'unknown';
}
