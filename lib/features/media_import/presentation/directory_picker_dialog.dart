import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/cloud115_directory_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/filesystem_entry_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

class MediaImportRequest {
  const MediaImportRequest({
    required this.libraryId,
    required this.source,
    required this.transferMode,
  });

  final int libraryId;
  final MediaImportSource source;
  final TransferMode transferMode;
}

Future<MediaImportRequest?> showDirectoryPickerDialog(BuildContext context) {
  return showDialog<MediaImportRequest>(
    context: context,
    builder: (_) => const _DirectoryPickerDialog(),
  );
}

class _DirectoryPickerDialog extends StatefulWidget {
  const _DirectoryPickerDialog();

  @override
  State<_DirectoryPickerDialog> createState() => _DirectoryPickerDialogState();
}

class _DirectoryPickerDialogState extends State<_DirectoryPickerDialog> {
  static const int _cloudPageSize = 200;

  late final MediaImportApi _mediaImportApi;
  late final MediaLibrariesApi _librariesApi;

  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  int? _selectedLibraryId;
  bool _isLoadingLibraries = true;
  String? _librariesError;

  FilesystemListResponseDto? _localListing;
  String? _localBrowsePath;
  Cloud115DirectoryPageDto? _cloudPage;
  List<Cloud115DirectoryEntryDto> _cloudEntries =
      const <Cloud115DirectoryEntryDto>[];
  List<_CloudPathSegment> _cloudPath = const <_CloudPathSegment>[];

  bool _isBrowsing = false;
  bool _isLoadingMore = false;
  String? _browseError;
  String? _loadMoreError;
  TransferMode _transferMode = TransferMode.auto;
  int _browseGeneration = 0;

  MediaLibraryDto? get _selectedLibrary {
    final selectedId = _selectedLibraryId;
    if (selectedId == null) {
      return null;
    }
    for (final library in _libraries) {
      if (library.id == selectedId) {
        return library;
      }
    }
    return null;
  }

  bool get _isCloud115 => _selectedLibrary?.isCloud115 ?? false;

  List<TransferMode> get _availableTransferModes => _isCloud115
      ? const <TransferMode>[
          TransferMode.copy,
          TransferMode.cleanupSource,
        ]
      : const <TransferMode>[
          TransferMode.auto,
          TransferMode.cleanupSource,
        ];

  bool get _canSubmit {
    if (_isBrowsing || _selectedLibrary == null) {
      return false;
    }
    if (_isCloud115) {
      final page = _cloudPage;
      if (page == null || _cloudPath.length <= 1) {
        return false;
      }
      return !_cloudPath.any((segment) => segment.cid == page.rootCid);
    }
    final listing = _localListing;
    return listing != null &&
        !listing.isRootsOverview &&
        listing.path.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _mediaImportApi = context.read<MediaImportApi>();
    _librariesApi = context.read<MediaLibrariesApi>();
    unawaited(_loadLibraries());
  }

  @override
  void dispose() {
    _browseGeneration += 1;
    super.dispose();
  }

  Future<void> _loadLibraries() async {
    setState(() {
      _isLoadingLibraries = true;
      _librariesError = null;
    });
    try {
      final libraries = await _librariesApi.getLibraries();
      if (!mounted) {
        return;
      }
      final firstId = libraries.isEmpty ? null : libraries.first.id;
      setState(() {
        _libraries = libraries;
        _isLoadingLibraries = false;
        _selectedLibraryId = firstId;
      });
      if (firstId != null) {
        unawaited(_resetAndBrowse(firstId));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLibraries = false;
        _librariesError = apiErrorMessage(
          error,
          fallback: '媒体库加载失败，请重试。',
        );
      });
    }
  }

  Future<void> _resetAndBrowse(int libraryId) async {
    final library =
        _libraries.where((item) => item.id == libraryId).firstOrNull;
    if (library == null) {
      return;
    }
    final generation = ++_browseGeneration;
    setState(() {
      _selectedLibraryId = library.id;
      _transferMode =
          library.isCloud115 ? TransferMode.copy : TransferMode.auto;
      _localListing = null;
      _localBrowsePath = null;
      _cloudPage = null;
      _cloudEntries = const <Cloud115DirectoryEntryDto>[];
      _cloudPath = library.isCloud115
          ? const <_CloudPathSegment>[
              _CloudPathSegment(cid: '0', name: '115 网盘'),
            ]
          : const <_CloudPathSegment>[];
      _browseError = null;
      _loadMoreError = null;
      _isLoadingMore = false;
      _isBrowsing = true;
    });
    if (library.isCloud115) {
      await _fetchCloudDirectory(generation: generation, cid: '0');
    } else {
      await _fetchLocalDirectory(generation: generation, path: null);
    }
  }

  Future<void> _browseLocal(String? path) async {
    final generation = ++_browseGeneration;
    setState(() {
      _localBrowsePath = path;
      _localListing = null;
      _browseError = null;
      _isBrowsing = true;
    });
    await _fetchLocalDirectory(generation: generation, path: path);
  }

  Future<void> _fetchLocalDirectory({
    required int generation,
    required String? path,
  }) async {
    try {
      final listing = await _mediaImportApi.listEntries(path: path);
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _localListing = listing;
        _localBrowsePath = listing.path;
        _isBrowsing = false;
      });
    } catch (error) {
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _isBrowsing = false;
        _browseError = _browseErrorMessage(error);
      });
    }
  }

  Future<void> _browseCloudFolder(Cloud115DirectoryEntryDto entry) async {
    final generation = ++_browseGeneration;
    setState(() {
      _cloudPath = <_CloudPathSegment>[
        ..._cloudPath,
        _CloudPathSegment(cid: entry.entryId, name: entry.name),
      ];
      _cloudPage = null;
      _cloudEntries = const <Cloud115DirectoryEntryDto>[];
      _browseError = null;
      _loadMoreError = null;
      _isLoadingMore = false;
      _isBrowsing = true;
    });
    await _fetchCloudDirectory(generation: generation, cid: entry.entryId);
  }

  Future<void> _browseCloudParent() async {
    if (_cloudPath.length <= 1) {
      return;
    }
    final nextPath = _cloudPath.sublist(0, _cloudPath.length - 1);
    final generation = ++_browseGeneration;
    setState(() {
      _cloudPath = nextPath;
      _cloudPage = null;
      _cloudEntries = const <Cloud115DirectoryEntryDto>[];
      _browseError = null;
      _loadMoreError = null;
      _isLoadingMore = false;
      _isBrowsing = true;
    });
    await _fetchCloudDirectory(
      generation: generation,
      cid: nextPath.last.cid,
    );
  }

  Future<void> _fetchCloudDirectory({
    required int generation,
    required String cid,
  }) async {
    final library = _selectedLibrary;
    if (library == null || !library.isCloud115) {
      return;
    }
    try {
      final page = await _librariesApi.listCloud115Directory(
        libraryId: library.id,
        cid: cid,
        limit: _cloudPageSize,
      );
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _cloudPage = page;
        _cloudEntries = page.entries;
        _isBrowsing = false;
      });
    } catch (error) {
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _isBrowsing = false;
        _browseError = _browseErrorMessage(error);
      });
    }
  }

  Future<void> _loadMoreCloud() async {
    final library = _selectedLibrary;
    final page = _cloudPage;
    if (library == null || page == null || _isLoadingMore || !page.hasMore) {
      return;
    }
    final generation = _browseGeneration;
    final cid = page.cid;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final nextPage = await _librariesApi.listCloud115Directory(
        libraryId: library.id,
        cid: cid,
        offset: _cloudEntries.length,
        limit: _cloudPageSize,
      );
      if (!mounted || generation != _browseGeneration || nextPage.cid != cid) {
        return;
      }
      setState(() {
        _cloudPage = nextPage;
        _cloudEntries = <Cloud115DirectoryEntryDto>[
          ..._cloudEntries,
          ...nextPage.entries,
        ];
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = _browseErrorMessage(error);
      });
    }
  }

  String _browseErrorMessage(Object error) {
    if (error is ApiException &&
        error.error?.code == 'cloud115_cookies_invalid') {
      return '115 登录已失效，请前往“系统设置 → 媒体库”重新认证后重试。';
    }
    return apiErrorMessage(error, fallback: '浏览目录失败，请重试。');
  }

  void _retryBrowse() {
    if (_isCloud115) {
      final cid = _cloudPath.isEmpty ? '0' : _cloudPath.last.cid;
      final generation = ++_browseGeneration;
      setState(() {
        _browseError = null;
        _isBrowsing = true;
      });
      unawaited(_fetchCloudDirectory(generation: generation, cid: cid));
      return;
    }
    unawaited(_browseLocal(_localBrowsePath));
  }

  void _submit() {
    final library = _selectedLibrary;
    if (!_canSubmit || library == null) {
      return;
    }
    final MediaImportSource source;
    if (library.isCloud115) {
      source = MediaImportSource.cloud115(_cloudPath.last.cid);
    } else {
      source = MediaImportSource.local(_localListing!.path);
    }
    Navigator.of(context).pop(
      MediaImportRequest(
        libraryId: library.id,
        source: source,
        transferMode: _transferMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final deletingCloudSource =
        _isCloud115 && _transferMode == TransferMode.cleanupSource;
    return AppDesktopDialog(
      dialogKey: const Key('media-import-directory-picker-dialog'),
      width: context.appLayoutTokens.dialogWidthMd,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '新建媒体导入',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.md),
            _buildLibrarySelector(context),
            if (_selectedLibrary != null) ...[
              SizedBox(height: spacing.md),
              _buildPathBar(context),
              SizedBox(height: spacing.sm),
              _buildBrowser(context),
              SizedBox(height: spacing.lg),
              _buildTransferModeSelector(context),
              if (deletingCloudSource) ...[
                SizedBox(height: spacing.md),
                const AppNoticeCard(
                  key: Key('media-import-cloud-cleanup-warning'),
                  leadingIcon: Icons.warning_amber_rounded,
                  title: '导入完成后将删除源文件',
                  description:
                      'SakuraMedia 会先在 115 网盘内复制并确认媒体已入库，再删除所选来源目录中的已成功导入文件。',
                ),
              ],
            ],
            SizedBox(height: spacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('media-import-picker-cancel-button'),
                    label: '取消',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: AppButton(
                    key: const Key('media-import-picker-submit-button'),
                    label: deletingCloudSource ? '导入并删除源文件' : '开始导入',
                    variant: AppButtonVariant.primary,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrarySelector(BuildContext context) {
    if (_isLoadingLibraries) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_librariesError != null) {
      return Column(
        children: [
          AppEmptyState(message: _librariesError!),
          SizedBox(height: context.appSpacing.sm),
          AppButton(
            key: const Key('media-import-picker-libraries-retry-button'),
            label: '重新加载媒体库',
            size: AppButtonSize.small,
            onPressed: () => unawaited(_loadLibraries()),
          ),
        ],
      );
    }
    if (_libraries.isEmpty) {
      return const AppEmptyState(message: '暂无媒体库，请先在系统设置中添加媒体库。');
    }
    return AppSelectField<int>(
      key: const Key('media-import-picker-library-select'),
      label: '导入到媒体库',
      value: _selectedLibraryId,
      items: _libraries
          .map(
            (library) => DropdownMenuItem<int>(
              value: library.id,
              child: Text(
                '${library.name} · ${library.isCloud115 ? '115 网盘' : '本地存储'}',
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null && value != _selectedLibraryId) {
          unawaited(_resetAndBrowse(value));
        }
      },
    );
  }

  Widget _buildPathBar(BuildContext context) {
    final listing = _localListing;
    final canGoUp = !_isBrowsing &&
        (_isCloud115 ? _cloudPath.length > 1 : listing?.parent != null);
    final pathText = _isCloud115
        ? (_cloudPath.isEmpty
            ? '115 网盘'
            : _cloudPath.map((segment) => segment.name).join(' / '))
        : switch (listing) {
            null when _localBrowsePath != null => _localBrowsePath!,
            null => '加载中…',
            final value when value.isRootsOverview => '选择一个白名单根目录',
            final value => value.path,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIconButton(
              key: const Key('media-import-picker-up-button'),
              icon: const Icon(Icons.arrow_upward_rounded),
              tooltip: '上一级',
              onPressed: canGoUp
                  ? () {
                      if (_isCloud115) {
                        unawaited(_browseCloudParent());
                      } else {
                        unawaited(_browseLocal(listing!.parent));
                      }
                    }
                  : null,
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: Text(
                pathText,
                key: const Key('media-import-picker-current-path'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
          ],
        ),
        if (_isCloud115 && _cloudPath.length <= 1) ...[
          SizedBox(height: context.appSpacing.xs),
          Text(
            '请选择根目录下的来源文件夹；115 根目录本身不能作为导入源。',
            key: const Key('media-import-cloud-root-hint'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBrowser(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildBrowserBody(context),
    );
  }

  Widget _buildBrowserBody(BuildContext context) {
    if (_isBrowsing) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
        ),
      );
    }
    if (_browseError != null) {
      return Padding(
        padding: EdgeInsets.all(context.appSpacing.lg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEmptyState(message: _browseError!),
              SizedBox(height: context.appSpacing.md),
              AppButton(
                key: const Key('media-import-picker-browse-retry-button'),
                label: '重试',
                size: AppButtonSize.small,
                onPressed: _retryBrowse,
              ),
            ],
          ),
        ),
      );
    }
    return _isCloud115
        ? _buildCloudBrowserBody(context)
        : _buildLocalBrowserBody(context);
  }

  Widget _buildLocalBrowserBody(BuildContext context) {
    final listing = _localListing;
    if (listing == null || listing.entries.isEmpty) {
      return const AppEmptyState(message: '该目录下没有可显示的子目录或视频文件');
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
      itemCount: listing.entries.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appColors.divider),
      itemBuilder: (context, index) {
        final entry = listing.entries[index];
        return _LocalEntryRow(
          entry: entry,
          onTap: entry.isDirectory
              ? () => unawaited(_browseLocal(entry.path))
              : null,
        );
      },
    );
  }

  Widget _buildCloudBrowserBody(BuildContext context) {
    if (_cloudEntries.isEmpty) {
      return const AppEmptyState(message: '该目录下没有可显示的子目录或视频文件');
    }
    final showFooter =
        _cloudPage?.hasMore == true || _loadMoreError != null || _isLoadingMore;
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
      itemCount: _cloudEntries.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appColors.divider),
      itemBuilder: (context, index) {
        if (index == _cloudEntries.length) {
          return _buildCloudLoadMoreFooter(context);
        }
        final entry = _cloudEntries[index];
        final isManagementDirectory =
            entry.isDirectory && entry.entryId == _cloudPage?.rootCid;
        return _CloudEntryRow(
          entry: entry,
          isManagementDirectory: isManagementDirectory,
          onTap: entry.isDirectory && !isManagementDirectory
              ? () => unawaited(_browseCloudFolder(entry))
              : null,
        );
      },
    );
  }

  Widget _buildCloudLoadMoreFooter(BuildContext context) {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: EdgeInsets.all(context.appSpacing.sm),
      child: Column(
        children: [
          if (_loadMoreError != null)
            Text(
              _loadMoreError!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          AppButton(
            key: const Key('media-import-cloud-load-more-button'),
            label: _loadMoreError == null ? '加载更多' : '重试加载',
            size: AppButtonSize.small,
            onPressed: () => unawaited(_loadMoreCloud()),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferModeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelectField<TransferMode>(
          key: const Key('media-import-picker-transfer-mode-select'),
          label: '导入方式',
          value: _transferMode,
          items: _availableTransferModes
              .map(
                (mode) => DropdownMenuItem<TransferMode>(
                  value: mode,
                  child: Text(mode.label),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              setState(() => _transferMode = value);
            }
          },
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          _isCloud115
              ? '115 导入在云端完成，文件不会经过当前设备。'
              : '硬链接优先模式要求来源和媒体库根路径位于同一块物理盘，否则会回退到复制。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
      ],
    );
  }
}

class _CloudPathSegment {
  const _CloudPathSegment({required this.cid, required this.name});

  final String cid;
  final String name;
}

class _LocalEntryRow extends StatelessWidget {
  const _LocalEntryRow({required this.entry, required this.onTap});

  final FilesystemEntryDto entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _DirectoryEntryRow(
      name: entry.name,
      isDirectory: entry.isDirectory,
      size: entry.size,
      onTap: onTap,
    );
  }
}

class _CloudEntryRow extends StatelessWidget {
  const _CloudEntryRow({
    required this.entry,
    required this.isManagementDirectory,
    required this.onTap,
  });

  final Cloud115DirectoryEntryDto entry;
  final bool isManagementDirectory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _DirectoryEntryRow(
      key: Key('media-import-cloud-entry-${entry.entryId}'),
      name: entry.name,
      isDirectory: entry.isDirectory,
      size: entry.size,
      trailingText: isManagementDirectory ? '媒体库管理目录，不可选择' : null,
      muted: isManagementDirectory,
      onTap: onTap,
    );
  }
}

class _DirectoryEntryRow extends StatelessWidget {
  const _DirectoryEntryRow({
    super.key,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.onTap,
    this.trailingText,
    this.muted = false,
  });

  final String name;
  final bool isDirectory;
  final int size;
  final VoidCallback? onTap;
  final String? trailingText;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              isDirectory ? Icons.folder_rounded : Icons.movie_outlined,
              size: context.appComponentTokens.iconSizeSm,
              color: muted
                  ? context.appTextPalette.muted
                  : isDirectory
                      ? context.appTextPalette.accent
                      : context.appTextPalette.muted,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: muted
                      ? AppTextTone.muted
                      : isDirectory
                          ? AppTextTone.primary
                          : AppTextTone.muted,
                ),
              ),
            ),
            if (trailingText != null) ...[
              SizedBox(width: spacing.sm),
              Text(
                trailingText!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            ] else if (!isDirectory) ...[
              SizedBox(width: spacing.sm),
              Text(
                formatFileSize(size),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
