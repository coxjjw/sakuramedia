import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';

class MediaStorageDescriptor {
  const MediaStorageDescriptor({
    required this.libraryId,
    required this.libraryName,
    required this.backend,
  });

  const MediaStorageDescriptor.unknown({this.libraryId})
      : libraryName = null,
        backend = null;

  final int? libraryId;
  final String? libraryName;
  final MediaLibraryBackend? backend;

  bool get isLocal => backend == MediaLibraryBackend.local;
  bool get isCloud115 => backend == MediaLibraryBackend.cloud115;

  String get sourceLabel => switch (backend) {
        MediaLibraryBackend.local => '本地存储',
        MediaLibraryBackend.cloud115 => '115 网盘',
        null => '存储来源未知',
      };

  String? get normalizedLibraryName {
    final value = libraryName?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  factory MediaStorageDescriptor.fromLibrary(MediaLibraryDto library) {
    return MediaStorageDescriptor(
      libraryId: library.id,
      libraryName: library.name,
      backend: library.backend,
    );
  }
}

Map<int, MediaStorageDescriptor> buildMediaStorageDescriptors(
  Iterable<MediaLibraryDto> libraries,
) {
  return <int, MediaStorageDescriptor>{
    for (final library in libraries)
      library.id: MediaStorageDescriptor.fromLibrary(library),
  };
}

MediaStorageDescriptor resolveMediaStorageDescriptor(
  int? libraryId,
  Map<int, MediaStorageDescriptor> descriptors,
) {
  if (libraryId == null) {
    return const MediaStorageDescriptor.unknown();
  }
  return descriptors[libraryId] ??
      MediaStorageDescriptor.unknown(libraryId: libraryId);
}
