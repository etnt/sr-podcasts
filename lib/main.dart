import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'src/podcast/audio/podcast_audio_handler.dart';
import 'src/podcast/audio/podcast_playback.dart';
import 'src/podcast/data/subscriptions.dart';
import 'src/podcast/data/sr_api_client.dart';
import 'src/podcast/presentation/subscriptions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  // The handler lives outside the Riverpod scope, so it gets its
  // dependencies as constructor arguments (see plan CON-002).
  final handler = createPodcastAudioHandler(
    apiClient: SrApiClient(httpClient: http.Client()),
    loadSubscriptions: () =>
        SubscriptionsNotifier.loadSubscriptions(sharedPreferences),
  );
  await AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'se.sverigesradio.podcastshortcut.audio',
      androidNotificationChannelName: 'Podcast playback',
      androidNotificationOngoing: true,
      androidBrowsableRootExtras:
          PodcastAudioHandler.androidBrowsableRootExtras,
    ),
  );
  await configurePodcastAudioSession();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SR Podcasts',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006AA7)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006AA7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SubscriptionsScreen(),
    );
  }
}
