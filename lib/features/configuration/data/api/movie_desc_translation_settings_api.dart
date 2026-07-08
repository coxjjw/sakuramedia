import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/movie_desc_translation_settings_dto.dart';

/// 影片信息翻译（LLM）配置读写。
///
/// 后端已收敛到统一配置接口：读写走 `GET/PATCH /config` 的
/// `movie_info_translation` 节；连通性探测仍走 `POST /movie-desc-translation-settings/test`。
class MovieDescTranslationSettingsApi {
  const MovieDescTranslationSettingsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const String _configSection = 'movie_info_translation';

  final ApiClient _apiClient;

  Future<MovieDescTranslationSettingsDto> getSettings() async {
    final response = await _apiClient.get('/config');
    return _extractSettings(response);
  }

  Future<MovieDescTranslationSettingsDto> updateSettings(
    UpdateMovieDescTranslationSettingsPayload payload,
  ) async {
    final response = await _apiClient.patch(
      '/config',
      data: <String, dynamic>{_configSection: payload.toJson()},
    );
    return _extractSettings(response);
  }

  Future<bool> testSettings(
    TestMovieDescTranslationSettingsPayload payload,
  ) async {
    final response = await _apiClient.post(
      '/movie-desc-translation-settings/test',
      data: payload.toJson(),
    );
    return response['ok'] == true;
  }

  /// 从 `/config` 响应里取 `movie_info_translation` 节。
  ///
  /// 节缺失 / 类型不对 → 抛 [FormatException]。不能沉默返回默认 DTO：
  /// UI 层靠异常触发 error state + 重试按钮；一旦返回全默认值，用户会看到
  /// 「配置是空的」的假象，随手点保存就会把服务器上的配置踩踏成空。
  MovieDescTranslationSettingsDto _extractSettings(
    Map<String, dynamic> response,
  ) {
    final values = response['values'];
    if (values is! Map) {
      throw const FormatException(
        '/config response missing "values" object',
      );
    }
    final section = values[_configSection];
    if (section is! Map) {
      throw FormatException(
        '/config response missing "$_configSection" section',
      );
    }
    return MovieDescTranslationSettingsDto.fromJson(
      Map<String, dynamic>.from(section),
    );
  }
}
