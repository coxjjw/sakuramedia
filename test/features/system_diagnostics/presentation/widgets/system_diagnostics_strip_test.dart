import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/system_diagnostics_strip.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/test_api_bundle.dart';

late TestApiBundle _bundle;

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 't',
    refreshToken: 'r',
    expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
  );
  return store;
}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider<MediaLibrariesApi>.value(value: _bundle.mediaLibrariesApi),
      Provider<DownloadClientsApi>.value(value: _bundle.downloadClientsApi),
      Provider<IndexerSettingsApi>.value(value: _bundle.indexerSettingsApi),
      Provider<StatusApi>.value(value: _bundle.statusApi),
      Provider<MovieDescTranslationSettingsApi>.value(
        value: _bundle.movieDescTranslationSettingsApi,
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: sakuraThemeData,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await _buildLoggedInSessionStore();
    _bundle = await createTestApiBundle(store);
  });

  tearDown(() {
    _bundle.dispose();
  });

  testWidgets('未检测态渲染「开始检测」按钮 + Key 稳定', (tester) async {
    await tester.pumpWidget(_wrap(const SystemDiagnosticsStrip()));

    expect(find.byKey(const Key('system-diagnostics-strip')), findsOneWidget);
    expect(
      find.byKey(const Key('system-diagnostics-strip-start')),
      findsOneWidget,
    );
    expect(find.text('组件诊断'), findsOneWidget);
    expect(find.text('开始检测'), findsOneWidget);
  });
}
