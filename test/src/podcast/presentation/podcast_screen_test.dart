import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_providers.dart';
import 'package:podcastshortcut/src/podcast/presentation/podcast_screen.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/radiokorrespondenterna_kina_episodes.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Future<void> pumpScreen(
    WidgetTester tester, {
    required MockClient Function() clientFactory,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [httpClientProvider.overrideWith((ref) => clientFactory())],
        child: const MaterialApp(home: PodcastScreen()),
      ),
    );
  }

  testWidgets('shows program, loading, then fetched episode', (tester) async {
    var responded = false;
    await pumpScreen(
      tester,
      clientFactory: () => MockClient((request) async {
        if (!responded) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          responded = true;
        }
        return http.Response(
          jsonEncode(fixture),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    // The program name appears twice: AppBar title and program header.
    expect(find.text('Radiokorrespondenterna Kina'), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      find.text('Därför platsar BRICS i Kinas världsordning'),
      findsOneWidget,
    );
  });

  testWidgets('shows empty response state', (tester) async {
    await pumpScreen(
      tester,
      clientFactory: () => MockClient(
        (request) async => http.Response(
          '{"episodes":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No episodes are currently available.'), findsOneWidget);
  });

  testWidgets('shows recoverable error and retries', (tester) async {
    var requests = 0;
    await pumpScreen(
      tester,
      clientFactory: () => MockClient((request) async {
        requests++;
        if (requests == 1) return http.Response('failure', 503);
        return http.Response(
          jsonEncode(fixture),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpAndSettle();
    expect(find.text('Could not load episodes'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Därför platsar BRICS i Kinas världsordning'),
      findsOneWidget,
    );
  });

  testWidgets('provides external SR page action', (tester) async {
    await pumpScreen(
      tester,
      clientFactory: () => MockClient(
        (request) async => http.Response(
          '{"episodes":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open Sveriges Radio page'), findsOneWidget);
  });
}
