import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcastshortcut/src/podcast/data/podcast_catalog.dart';
import 'package:podcastshortcut/src/podcast/data/subscriptions.dart';
import 'package:podcastshortcut/src/podcast/domain/podcast_program.dart';
import 'package:shared_preferences/shared_preferences.dart';

PodcastProgram _program(int id) => PodcastProgram(
  id: id,
  name: 'Show $id',
  pageUrl: Uri.parse('https://example.com/show-$id'),
  hasPod: true,
);

Future<(ProviderContainer, SharedPreferences)> _createContainer({
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'seeds the hardcoded default show on first run and persists it',
    () async {
      final (container, prefs) = await _createContainer();

      final subscriptions = await container.read(subscriptionsProvider.future);

      expect(subscriptions.map((program) => program.id), [
        podcastCatalog.first.id,
      ]);
      final stored =
          jsonDecode(prefs.getString('subscriptions.v1')!) as List<dynamic>;
      expect(stored, hasLength(1));
      expect(
        (stored.first as Map<String, dynamic>)['id'],
        podcastCatalog.first.id,
      );
    },
  );

  test('restores stored subscriptions instead of seeding again', () async {
    final (container, _) = await _createContainer(
      initialValues: {
        'subscriptions.v1': jsonEncode([_program(1234).toJson()]),
      },
    );

    final subscriptions = await container.read(subscriptionsProvider.future);

    expect(subscriptions.map((program) => program.id), [1234]);
  });

  test('toggle subscribes and unsubscribes with persistence', () async {
    final (container, prefs) = await _createContainer();
    final notifier = container.read(subscriptionsProvider.notifier);
    await container.read(subscriptionsProvider.future);

    final extra = _program(4321);
    await notifier.toggle(extra);

    expect(
      container.read(subscriptionsProvider).value!.map((p) => p.id),
      containsAll(<int>[podcastCatalog.first.id, 4321]),
    );
    expect(jsonDecode(prefs.getString('subscriptions.v1')!), hasLength(2));

    await notifier.toggle(extra);

    expect(
      container.read(subscriptionsProvider).value!.map((p) => p.id),
      isNot(contains(4321)),
    );
    expect(jsonDecode(prefs.getString('subscriptions.v1')!), hasLength(1));
  });

  test(
    'corrupt stored JSON yields an empty list instead of crashing',
    () async {
      final (container, _) = await _createContainer(
        initialValues: {'subscriptions.v1': 'not json'},
      );

      expect(await container.read(subscriptionsProvider.future), isEmpty);
    },
  );
}
