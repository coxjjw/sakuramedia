import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// 下载器（qBittorrent）连通性检测的 hint 表。
const Map<String, DiagnosticHint> downloaderConnectivityHints =
    <String, DiagnosticHint>{
  'network-error': DiagnosticHint(
    cause: '连不上下载器：主机不通、端口错误、或防火墙拦了。',
    fixHint:
        '检查 URL、端口是否正确。',
    impact: '自动化下载链路不可用。',
    fixTarget: DiagnosticFixTarget.configurationTab(2),
  ),
  'auth-error': DiagnosticHint(
    cause: 'qBittorrent 拒绝了当前的用户名 / 密码，多半是最近改过密码。',
    fixHint: '在 qBittorrent Web UI 里重置密码或确认已有账号密码；回到「下载器」重新填一次。',
    impact: '自动化下载链路不可用。',
    fixTarget: DiagnosticFixTarget.configurationTab(2),
  ),
  'unknown': DiagnosticHint(
    cause: '下载器返回了未识别的错误，可能是版本不兼容或 API 路径变了。',
    fixHint: '打开「下载器」卡片，点开该客户端的诊断详情看错误报文；必要时升级 qBittorrent 到 5.x。',
    impact: '自动化下载链路可能会在真实下载时才暴露问题。',
    fixTarget: DiagnosticFixTarget.configurationTab(2),
  ),
};

/// 下载器目录映射 / 硬链接检测的 hint 表。
const Map<String, DiagnosticHint> downloaderStorageHints =
    <String, DiagnosticHint>{
  'storage-mapping-error': DiagnosticHint(
    cause:
        'qBittorrent 保存路径 与本地根路径 映射不通。要么 qB 那边路径不存在，要么容器里挂错了卷。',
    fixHint:
        '核对「qBittorrent 保存路径」（qB 视角）和「本地根路径」（后端视角）确实指向宿主机的同一个目录。',
    impact: '下载完成后无法归档到媒体库；影片入库流程会一直卡在待处理。',
    fixTarget: DiagnosticFixTarget.configurationTab(2),
  ),
  'hardlink-unsupported': DiagnosticHint(
    cause:
        '存储不支持硬链接（跨设备、跨文件系统、SMB/NFS/exFAT 之类），导入下载完成的影片会被复制而不是链接。',
    fixHint:
        '查看wiki快速开始部分： 媒体目录怎么挂才能正确硬链接',
    impact: '导入下载完成影片时会消耗双倍磁盘空间。',
    fixTarget: DiagnosticFixTarget.configurationTab(2),
  ),
  'unknown': DiagnosticHint(
    cause: '存储探针返回了未识别的错误。',
    fixHint: '打开「下载器」卡片，点开该客户端的目录映射诊断详情看具体报文。',
    impact: '可能会在真实下载时才暴露问题。',
    fixTarget: DiagnosticFixTarget.configurationTab(2),
  ),
};

/// 根据后端返回的 error type 判定连通性检测挂在哪一类。
String resolveDownloaderConnectivityHintKey(
  DownloadClientDiagnosticErrorDto? error,
) {
  if (error == null) return 'unknown';
  final type = error.type.toLowerCase();
  final message = error.message.toLowerCase();
  if (type.contains('auth') ||
      type.contains('unauthorized') ||
      type.contains('forbidden') ||
      message.contains('unauthorized') ||
      message.contains('forbidden') ||
      message.contains('login')) {
    return 'auth-error';
  }
  if (type.contains('connect') ||
      type.contains('timeout') ||
      type.contains('network') ||
      type.contains('unreachable') ||
      message.contains('connection refused') ||
      message.contains('timed out') ||
      message.contains('no route')) {
    return 'network-error';
  }
  return 'unknown';
}

/// 根据存储检测结果判定挂在哪一类。
///
/// 优先级：directoryMapping 出错 > hardlink 不支持 > unknown。
String resolveDownloaderStorageHintKey(
  DownloadClientStorageTestResultDto result,
) {
  final mappingHealthy = result.directoryMapping.status.toLowerCase() == 'ok' &&
      result.directoryMapping.error == null &&
      result.directoryMapping.sentinelVisibleToQb;
  if (!mappingHealthy) {
    return 'storage-mapping-error';
  }
  if (!result.hardlink.supported) {
    return 'hardlink-unsupported';
  }
  return 'unknown';
}
