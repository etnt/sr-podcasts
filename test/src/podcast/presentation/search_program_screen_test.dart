import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_providers.dart';
import 'package:podcastshortcut/src/podcast/data/subscriptions.dart';
import 'package:podcastshortcut/src/podcast/presentation/search_program_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object json) => http.Response.bytes(
  utf8.encode(jsonEncode(json)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<SharedPreferences> _pumpSearch(
  WidgetTester tester, {
  required MockClient client,
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        httpClientProvider.overrideWithValue(client),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: SearchProgramScreen()),
    ),
  );
  return prefs;
}

void main() {
  final corpusFixture = jsonDecode(
    File('test/fixtures/sr_programs.json').readAsStringSync(),
  );

  testWidgets('shows loading state while the corpus is fetched', (
    tester,
  ) async {
    await _pumpSearch(
      tester,
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return _json(corpusFixture);
      }),
    );
    await tester.pump();

    expect(find.text('Loading the SR catalog…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.text('Search all Sveriges Radio podcasts by name or description.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a recoverable error and retries', (tester) async {
    var requests = 0;
    await _pumpSearch(
      tester,
      client: MockClient((request) async {
        requests++;
        if (requests == 1) return http.Response('boom', 503);
        return _json(corpusFixture);
      }),
    );
    await tester.pump();

    expect(find.text('Could not load the SR catalog'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Search all Sveriges Radio podcasts by name or description.'),
      findsOneWidget,
    );
  });

  testWidgets('filters podcast results by query', (tester) async {
    await _pumpSearch(
      tester,
      client: MockClient((request) async => _json(corpusFixture)),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'kina');
    await tester.pump();

    expect(find.text('Radiokorrespondenterna Kina'), findsOneWidget);
    expect(find.text('Kina och Keve i Barnradion'), findsOneWidget);
    expect(find.text('Nyheter P4 Jämtland'), findsNothing);
  });

  testWidgets('hides non-podcast programs from results', (tester) async {
    await _pumpSearch(
      tester,
      client: MockClient((request) async => _json(corpusFixture)),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Radiosporten');
    await tester.pump();

    expect(find.text('No shows match “Radiosporten”.'), findsOneWidget);
  });

  testWidgets('subscribing from results persists the show', (tester) async {
    final prefs = await _pumpSearch(
      tester,
      client: MockClient((request) async => _json(corpusFixture)),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'kina');
    await tester.pump();

    // The default show is seeded on first run, so it is already subscribed.
    expect(
      find.byTooltip('Unsubscribe from Radiokorrespondenterna Kina'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Subscribe to Kina och Keve i Barnradion'));
    await tester.pump();
    await tester.pump();

    expect(
      find.byTooltip('Unsubscribe from Kina och Keve i Barnradion'),
      findsOneWidget,
    );
    final stored = jsonDecode(prefs.getString('subscriptions.v1')!) as List;
    expect(stored, hasLength(2));
    expect(
      stored.map((program) => program['id']),
      containsAll(<Object>[5386, 4957]),
    );
  });
}
