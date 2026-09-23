import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_providers.dart';
import 'package:podcastshortcut/src/podcast/data/subscriptions.dart';
import 'package:podcastshortcut/src/podcast/presentation/subscriptions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _pumpHome(
  WidgetTester tester, {
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final episodesFixture = jsonDecode(
    File(
      'test/fixtures/radiokorrespondenterna_kina_episodes.json',
    ).readAsStringSync(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        httpClientProvider.overrideWithValue(
          MockClient(
            (request) async => http.Response.bytes(
              utf8.encode(jsonEncode(episodesFixture)),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: SubscriptionsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return prefs;
}

Iterable<String> _plainTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

void main() {
  testWidgets('shows version badge and seeded default show', (tester) async {
    await _pumpHome(tester);

    final title = _plainTexts(
      tester,
    ).where((text) => text.contains('SR Podcasts'));
    expect(title, isNotEmpty);
    expect(title.first, contains('dev'));
    expect(find.text('Radiokorrespondenterna Kina'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is subscribed', (
    tester,
  ) async {
    await _pumpHome(tester, initialValues: {'subscriptions.v1': '[]'});

    expect(find.text('No subscribed shows'), findsOneWidget);
    expect(find.text('Find shows'), findsOneWidget);
  });

  testWidgets('unsubscribing removes the show', (tester) async {
    final prefs = await _pumpHome(tester);

    expect(find.text('Radiokorrespondenterna Kina'), findsOneWidget);
    await tester.tap(
      find.byTooltip('Unsubscribe from Radiokorrespondenterna Kina'),
    );
    await tester.pump();

    expect(find.text('No subscribed shows'), findsOneWidget);
    expect(jsonDecode(prefs.getString('subscriptions.v1')!), isEmpty);
  });

  testWidgets('tapping a show opens its episode screen', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Radiokorrespondenterna Kina'));
    await tester.pumpAndSettle();

    expect(
      find.text('Därför platsar BRICS i Kinas världsordning'),
      findsOneWidget,
    );
  });
}
