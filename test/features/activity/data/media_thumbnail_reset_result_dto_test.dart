import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/activity/data/media_thumbnail_reset_result_dto.dart';

void main() {
  group('MediaThumbnailResetResultDto.fromJson', () {
    test('maps the full payload', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 3,
        'resource_ids': <dynamic>[10, 20, 30],
      });

      expect(dto.taskKey, 'media_thumbnail_generation');
      expect(dto.state, 'pending');
      expect(dto.resetCount, 3);
      expect(dto.resourceIds, <int>[10, 20, 30]);
    });

    test('tolerates missing fields with sane defaults', () {
      final dto = MediaThumbnailResetResultDto.fromJson(
        const <String, dynamic>{},
      );

      expect(dto.taskKey, '');
      expect(dto.state, '');
      expect(dto.resetCount, 0);
      expect(dto.resourceIds, isEmpty);
    });

    test('accepts numeric resource ids as double and truncates', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 2,
        'resource_ids': <dynamic>[10.0, 11.9, 'not-a-number'],
      });

      // 非 num 项被过滤，num 项被 toInt。
      expect(dto.resourceIds, <int>[10, 11]);
    });

    test('empty resource_ids list yields empty list', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 0,
        'resource_ids': <dynamic>[],
      });

      expect(dto.resourceIds, isEmpty);
    });
  });
}
