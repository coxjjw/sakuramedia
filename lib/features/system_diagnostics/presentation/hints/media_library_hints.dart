import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// 媒体库这一层用不到「后端 error 映射」——只有「空 / 非空」两种态。
/// 空态用这个 hint 就够了。
const DiagnosticHint mediaLibraryEmptyHint = DiagnosticHint(
  cause: '还没有配置任何媒体库，所有依赖它的组件（下载器、索引器）都无法验证。',
  fixHint: '在「设置 → 媒体库」中新建一个媒体库，指向本地或 NAS 挂载的根目录。',
  impact:
      '影片入库、下载后归档、以及影片详情页的媒体信息都会失败；后端相关配置会一直卡在半初始化状态。',
  fixTarget: DiagnosticFixTarget.configurationTab(1),
);
