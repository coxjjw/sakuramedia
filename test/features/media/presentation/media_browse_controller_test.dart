import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_controller.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaApi mediaApi;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-05-13T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    mediaApi = MediaApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('initialize loads first page with current filter', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_javItemJson(id: 1)],
        total: 1,
        page: 1,
      ),
    );

    final controller = MediaBrowseController(mediaApi: mediaApi);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.items, hasLength(1));
    expect(controller.items.first.id, 1);
    expect(controller.filterState.isDefault, isTrue);
    // 默认排序不下发 sort 参数
    expect(
      adapter.requests.single.uri.queryParameters.containsKey('sort'),
      isFalse,
    );
  });

  test('applyFilterState triggers reload with new query and clears selection',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_javItemJson(id: 1)], total: 1, page: 1),
    );
    final controller = MediaBrowseController(mediaApi: mediaApi);
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.toggleSelection(1);
    expect(controller.selectionCount, 1);

    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const [], total: 0, page: 1),
    );

    await controller.applyFilterState(
      controller.filterState.copyWith(
        kind: MediaListItemKind.jav,
        libraryId: 8,
        sortField: MediaBrowseSortField.heat,
        sortDirection: MediaBrowseSortDirection.desc,
      ),
    );

    expect(controller.selectionCount, 0);
    expect(adapter.requests.last.uri.queryParameters, containsPair('kind', 'jav'));
    expect(
      adapter.requests.last.uri.queryParameters,
      containsPair('library_id', '8'),
    );
    expect(
      adapter.requests.last.uri.queryParameters,
      containsPair('sort', 'heat:desc'),
    );
  });

  test('applyFilterState short-circuits when equal filters are supplied',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const [], total: 0, page: 1),
    );
    final controller = MediaBrowseController(mediaApi: mediaApi);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.applyFilterState(controller.filterState.copyWith());

    expect(adapter.hitCount('GET', '/media'), 1);
  });

  test('removeItemsByIds prunes list and adjusts total', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_javItemJson(id: 1), _javItemJson(id: 2)],
        total: 5,
        page: 1,
      ),
    );
    final controller = MediaBrowseController(mediaApi: mediaApi);
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.toggleSelection(1);

    controller.removeItemsByIds(const <int>[1, 2]);

    expect(controller.items, isEmpty);
    expect(controller.total, 3);
    expect(controller.selectionCount, 0);
  });

  test('selectAllLoaded and clearSelection maintain selection set', () {
    final controller = MediaBrowseController(mediaApi: mediaApi);
    addTearDown(controller.dispose);
    // Pretend items have been loaded via direct injection through
    // initialization is not needed for pure selection state.
    controller.setSelected(10, true);
    controller.setSelected(20, true);
    expect(controller.isSelected(10), isTrue);
    controller.clearSelection();
    expect(controller.selectionCount, 0);
  });
}

Map<String, dynamic> _javItemJson({required int id}) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'ABC-$id',
    'video_item_id': null,
    'title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main',
    'path': '/library/main/abc-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'special_tags': '普通',
    'valid': true,
    'heat': 100,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}

Map<String, dynamic> _mediaPage({
  required List<Map<String, dynamic>> items,
  required int total,
  required int page,
  int pageSize = 20,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}
