import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/podcast_program.dart';
import 'podcast_catalog.dart';

/// Overridden in `main()` with the initialized SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override sharedPreferencesProvider in main() before watching subscriptions.',
  ),
);

final subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsNotifier, List<PodcastProgram>>(
      SubscriptionsNotifier.new,
    );

/// Locally persisted list of subscribed shows. The first run seeds the
/// hardcoded default show so the app is useful out of the box.
class SubscriptionsNotifier extends AsyncNotifier<List<PodcastProgram>> {
  static const _storageKey = 'subscriptions.v1';

  @override
  Future<List<PodcastProgram>> build() =>
      loadSubscriptions(ref.watch(sharedPreferencesProvider));

  /// Loads the saved subscriptions from [prefs], seeding the hardcoded
  /// default show on first run. Shared by the notifier above and by the
  /// audio handler in `main()`, which runs outside the Riverpod scope.
  static Future<List<PodcastProgram>> loadSubscriptions(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      final seed = [podcastCatalog.first];
      await prefs.setString(
        _storageKey,
        jsonEncode(seed.map((program) => program.toJson()).toList()),
      );
      return seed;
    }
    return _decode(raw);
  }

  /// Subscribes to [program] if it is not subscribed yet, otherwise
  /// unsubscribes it. UI state updates immediately; persistence follows.
  Future<void> toggle(PodcastProgram program) async {
    final subscribed = await future;
    final wasSubscribed = subscribed.any((p) => p.id == program.id);
    final updated = wasSubscribed
        ? subscribed.where((p) => p.id != program.id).toList()
        : [...subscribed, program];
    state = AsyncData(updated);
    await _persist(ref.read(sharedPreferencesProvider), updated);
  }

  Future<void> _persist(
    SharedPreferences prefs,
    List<PodcastProgram> programs,
  ) {
    return prefs.setString(
      _storageKey,
      jsonEncode(programs.map((program) => program.toJson()).toList()),
    );
  }

  static List<PodcastProgram> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final programs = <PodcastProgram>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          programs.add(PodcastProgram.fromJson(entry));
        } on FormatException {
          continue; // A corrupt entry must not break the whole list.
        }
      }
      return programs;
    } on FormatException {
      return const [];
    }
  }
}
