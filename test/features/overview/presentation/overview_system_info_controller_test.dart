import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_controller.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late OverviewSystemInfoController controller;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-07-14T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    controller = OverviewSystemInfoController(
      statusApi: StatusApi(apiClient: apiClient),
    );
  });

  tearDown(() {
    controller.dispose();
    apiClient.dispose();
  });

  test('initial load and refresh do not probe cloud115 authentication',
      () async {
    _enqueueOverviewStatus(adapter);
    _enqueueOverviewStatus(adapter);

    await controller.load();
    await controller.refresh();

    expect(
      adapter.hitCount('GET', '/status/media-libraries/cloud115'),
      0,
    );
    expect(controller.cloud115CookiesStatus, isNull);
    expect(controller.cloud115AuthenticationRequestFailed, isFalse);
  });

  test('manual cloud115 authentication probe stores summary', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      body: _cloud115StatusJson(alive: 2, expired: 1, unavailable: 1),
    );

    await controller.testCloud115Authentication();

    expect(controller.isTestingCloud115Authentication, isFalse);
    expect(controller.cloud115AuthenticationRequestFailed, isFalse);
    expect(controller.cloud115CookiesStatus?.summary.total, 4);
    expect(controller.cloud115CookiesStatus?.summary.expired, 1);
    expect(controller.cloud115CookiesStatus?.summary.unavailable, 1);
  });

  test('manual cloud115 authentication probe exposes request failure',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': 'server error',
        },
      },
    );

    await controller.testCloud115Authentication();

    expect(controller.isTestingCloud115Authentication, isFalse);
    expect(controller.cloud115AuthenticationRequestFailed, isTrue);
    expect(controller.cloud115CookiesStatus, isNull);
  });

  test('duplicate cloud115 probe is ignored while request is running',
      () async {
    final release = Completer<void>();
    adapter.enqueueResponder(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      responder: (RequestOptions _, dynamic __) async {
        await release.future;
        return _jsonResponse(_cloud115StatusJson(alive: 1));
      },
    );

    final firstProbe = controller.testCloud115Authentication();
    await _waitForRequest(
      adapter,
      method: 'GET',
      path: '/status/media-libraries/cloud115',
    );
    await controller.testCloud115Authentication();

    expect(controller.isTestingCloud115Authentication, isTrue);
    expect(
      adapter.hitCount('GET', '/status/media-libraries/cloud115'),
      1,
    );

    release.complete();
    await firstProbe;
  });

  test('cloud115 and metadata provider probes run independently', () async {
    final releaseCloud115 = Completer<void>();
    adapter.enqueueResponder(
      method: 'GET',
      path: '/status/media-libraries/cloud115',
      responder: (RequestOptions _, dynamic __) async {
        await releaseCloud115.future;
        return _jsonResponse(_cloud115StatusJson(alive: 1));
      },
    );
    for (final provider in <String>['javdb', 'dmm']) {
      adapter.enqueueJson(
        method: 'GET',
        path: '/status/metadata-providers/$provider/test',
        body: <String, dynamic>{
          'healthy': true,
          'provider': provider,
          'error': null,
        },
      );
    }

    final cloud115Probe = controller.testCloud115Authentication();
    await _waitForRequest(
      adapter,
      method: 'GET',
      path: '/status/media-libraries/cloud115',
    );
    await controller.testExternalDataSources();

    expect(controller.isTestingCloud115Authentication, isTrue);
    expect(controller.isTestingMetadataProviders, isFalse);
    expect(controller.javdbHealthy, isTrue);
    expect(controller.dmmHealthy, isTrue);

    releaseCloud115.complete();
    await cloud115Probe;
  });
}

void _enqueueOverviewStatus(FakeHttpClientAdapter adapter) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    body: <String, dynamic>{},
  );
  adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: <String, dynamic>{},
  );
}

Map<String, dynamic> _cloud115StatusJson({
  int alive = 0,
  int expired = 0,
  int unavailable = 0,
}) {
  return <String, dynamic>{
    'checked_at': '2026-07-14T10:00:00Z',
    'summary': <String, dynamic>{
      'total': alive + expired + unavailable,
      'alive': alive,
      'expired': expired,
      'unavailable': unavailable,
    },
    'libraries': <dynamic>[],
  };
}

ResponseBody _jsonResponse(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

Future<void> _waitForRequest(
  FakeHttpClientAdapter adapter, {
  required String method,
  required String path,
}) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (adapter.hitCount(method, path) > 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Request was not started: $method $path');
}
