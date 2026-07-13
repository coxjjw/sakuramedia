sealed class MediaImportSource {
  const MediaImportSource();

  const factory MediaImportSource.local(String path) = LocalMediaImportSource;
  const factory MediaImportSource.cloud115(String cid) =
      Cloud115MediaImportSource;

  Map<String, dynamic> toJson();
}

class LocalMediaImportSource extends MediaImportSource {
  const LocalMediaImportSource(this.path);

  final String path;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'source_path': path};
}

class Cloud115MediaImportSource extends MediaImportSource {
  const Cloud115MediaImportSource(this.cid);

  final String cid;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'source_cid': cid};
}
