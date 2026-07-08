class ConfigResourceDto {
  const ConfigResourceDto({
    required this.media,
    required this.metadata,
    required this.scheduler,
    required this.downloads,
    required this.logging,
    required this.effects,
  });

  final AdvancedMediaConfigDto media;
  final AdvancedMetadataConfigDto metadata;
  final AdvancedSchedulerConfigDto scheduler;
  final AdvancedDownloadsConfigDto downloads;
  final AdvancedLoggingConfigDto logging;
  final Map<String, String> effects;

  factory ConfigResourceDto.fromJson(Map<String, dynamic> json) {
    final values = _objectAt(json, 'values', '/config response');
    final effects = _optionalObjectAt(json, 'effects', '/config response');
    return ConfigResourceDto(
      media: AdvancedMediaConfigDto.fromJson(
        _objectAt(values, 'media', '/config values'),
      ),
      metadata: AdvancedMetadataConfigDto.fromJson(
        _objectAt(values, 'metadata', '/config values'),
      ),
      scheduler: AdvancedSchedulerConfigDto.fromJson(
        _objectAt(values, 'scheduler', '/config values'),
      ),
      downloads: AdvancedDownloadsConfigDto.fromJson(
        _objectAt(values, 'downloads', '/config values'),
      ),
      logging: AdvancedLoggingConfigDto.fromJson(
        _objectAt(values, 'logging', '/config values'),
      ),
      effects: Map<String, String>.unmodifiable(
        _targetSectionKeys.fold<Map<String, String>>(<String, String>{}, (
          result,
          key,
        ) {
          final value = effects[key];
          if (value == null) {
            return result;
          }
          if (value is! String) {
            throw FormatException('/config effects "$key" must be a string');
          }
          result[key] = value;
          return result;
        }),
      ),
    );
  }
}

class ConfigUpdateResultDto {
  const ConfigUpdateResultDto({
    required this.values,
    required this.applied,
    required this.pendingRestart,
  });

  final ConfigResourceDto values;
  final List<String> applied;
  final List<PendingRestartFieldDto> pendingRestart;

  factory ConfigUpdateResultDto.fromJson(Map<String, dynamic> json) {
    return ConfigUpdateResultDto(
      values: ConfigResourceDto.fromJson(json),
      applied: List<String>.unmodifiable(_stringList(json, 'applied')),
      pendingRestart: List<PendingRestartFieldDto>.unmodifiable(
        _objectList(
          json,
          'pending_restart',
        ).map(PendingRestartFieldDto.fromJson),
      ),
    );
  }
}

class PendingRestartFieldDto {
  const PendingRestartFieldDto({required this.field, required this.restart});

  final String field;
  final String restart;

  factory PendingRestartFieldDto.fromJson(Map<String, dynamic> json) {
    return PendingRestartFieldDto(
      field: _stringAt(json, 'field'),
      restart: _stringAt(json, 'restart'),
    );
  }
}

class AdvancedMediaConfigDto {
  const AdvancedMediaConfigDto({
    required this.othersNumberFeatures,
    required this.collectionDurationThresholdMinutes,
    required this.innerSubTags,
    required this.bluerayTags,
    required this.uncensoredTags,
    required this.uncensoredPrefix,
    required this.allowedMinVideoFileSize,
  });

  final List<String> othersNumberFeatures;
  final int collectionDurationThresholdMinutes;
  final List<String> innerSubTags;
  final List<String> bluerayTags;
  final List<String> uncensoredTags;
  final List<String> uncensoredPrefix;
  final int allowedMinVideoFileSize;

  factory AdvancedMediaConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedMediaConfigDto(
      othersNumberFeatures: List<String>.unmodifiable(
        _stringList(json, 'others_number_features'),
      ),
      collectionDurationThresholdMinutes: _intAt(
        json,
        'collection_duration_threshold_minutes',
      ),
      innerSubTags: List<String>.unmodifiable(
        _stringList(json, 'inner_sub_tags'),
      ),
      bluerayTags: List<String>.unmodifiable(_stringList(json, 'blueray_tags')),
      uncensoredTags: List<String>.unmodifiable(
        _stringList(json, 'uncensored_tags'),
      ),
      uncensoredPrefix: List<String>.unmodifiable(
        _stringList(json, 'uncensored_prefix'),
      ),
      allowedMinVideoFileSize: _intAt(json, 'allowed_min_video_file_size'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'others_number_features': othersNumberFeatures,
      'collection_duration_threshold_minutes':
          collectionDurationThresholdMinutes,
      'inner_sub_tags': innerSubTags,
      'blueray_tags': bluerayTags,
      'uncensored_tags': uncensoredTags,
      'uncensored_prefix': uncensoredPrefix,
      'allowed_min_video_file_size': allowedMinVideoFileSize,
    };
  }
}

class AdvancedMetadataConfigDto {
  const AdvancedMetadataConfigDto({
    required this.javdbHost,
    required this.javdbUsername,
    required this.javdbPassword,
    required this.proxy,
  });

  final String javdbHost;
  final String javdbUsername;
  final String javdbPassword;
  final String proxy;

  factory AdvancedMetadataConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedMetadataConfigDto(
      javdbHost: _stringAt(json, 'javdb_host'),
      javdbUsername: _nullableStringAt(json, 'javdb_username'),
      javdbPassword: _nullableStringAt(json, 'javdb_password'),
      proxy: _nullableStringAt(json, 'proxy'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'javdb_host': javdbHost,
      'javdb_username': javdbUsername,
      'javdb_password': javdbPassword,
      'proxy': proxy,
    };
  }
}

class AdvancedSchedulerConfigDto {
  const AdvancedSchedulerConfigDto({required this.crons});

  static const List<String> cronKeys = <String>[
    'actor_subscription_sync',
    'subscribed_movie_auto_download',
    'download_task_sync',
    'download_task_auto_import',
    'download_small_file_cleanup',
    'movie_collection_sync',
    'movie_heat',
    'movie_interaction_sync',
    'ranking_sync',
    'hot_review_sync',
    'media_file_scan',
    'movie_desc_sync',
    'movie_desc_translation',
    'movie_title_translation',
    'media_thumbnail',
    'image_search_index',
    'image_search_optimize',
    'movie_similarity_recompute',
    'moment_recommendation_generate',
    'daily_recommendation_generate',
    'activity_cleanup',
  ];

  final Map<String, String> crons;

  factory AdvancedSchedulerConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedSchedulerConfigDto(
      crons: Map<String, String>.unmodifiable(
        cronKeys.fold<Map<String, String>>(<String, String>{}, (result, key) {
          result[key] = _stringAt(json, '${key}_cron');
          return result;
        }),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      for (final entry in crons.entries) '${entry.key}_cron': entry.value,
    };
  }
}

class AdvancedDownloadsConfigDto {
  const AdvancedDownloadsConfigDto({required this.smallFileCleanupThresholdMb});

  final int smallFileCleanupThresholdMb;

  factory AdvancedDownloadsConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedDownloadsConfigDto(
      smallFileCleanupThresholdMb: _intAt(
        json,
        'small_file_cleanup_threshold_mb',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'small_file_cleanup_threshold_mb': smallFileCleanupThresholdMb,
    };
  }
}

class AdvancedLoggingConfigDto {
  const AdvancedLoggingConfigDto({required this.level});

  final String level;

  factory AdvancedLoggingConfigDto.fromJson(Map<String, dynamic> json) {
    return AdvancedLoggingConfigDto(level: _stringAt(json, 'level'));
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'level': level};
  }
}

const List<String> _targetSectionKeys = <String>[
  'media',
  'metadata',
  'scheduler',
  'downloads',
  'logging',
];

Map<String, dynamic> _objectAt(
  Map<String, dynamic> json,
  String key, [
  String path = 'object',
]) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('$path missing "$key" object');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _optionalObjectAt(
  Map<String, dynamic> json,
  String key, [
  String path = 'object',
]) {
  final value = json[key];
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is! Map) {
    throw FormatException('$path "$key" must be an object');
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <Map<String, dynamic>>[];
  }
  if (value is! List) {
    throw FormatException('object "$key" must be a list');
  }
  return <Map<String, dynamic>>[
    for (final item in value)
      if (item is Map)
        Map<String, dynamic>.from(item)
      else
        throw FormatException('object "$key" contains a non-object item'),
  ];
}

String _stringAt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('object missing "$key" string');
  }
  return value;
}

String _nullableStringAt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return '';
  }
  if (value is! String) {
    throw FormatException('object "$key" must be a string or null');
  }
  return value;
}

int _intAt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('object missing "$key" integer');
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('object missing "$key" list');
  }
  return <String>[
    for (final item in value)
      if (item is String)
        item
      else
        throw FormatException('object "$key" contains a non-string item'),
  ];
}
