import 'package:sakuramedia/core/json/json_parse.dart';

class MediaThumbnailResetResultDto {
  const MediaThumbnailResetResultDto({
    required this.taskKey,
    required this.state,
    required this.resetCount,
    required this.resourceIds,
  });

  final String taskKey;
  final String state;
  final int resetCount;
  final List<int> resourceIds;

  factory MediaThumbnailResetResultDto.fromJson(Map<String, dynamic> json) {
    final rawIds = json['resource_ids'];
    return MediaThumbnailResetResultDto(
      taskKey: json['task_key'] as String? ?? '',
      state: json['state'] as String? ?? '',
      resetCount: asInt(json['reset_count']),
      resourceIds:
          rawIds is List
              ? rawIds
                  .whereType<num>()
                  .map((value) => value.toInt())
                  .toList(growable: false)
              : const <int>[],
    );
  }
}
