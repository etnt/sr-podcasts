import 'package:auto_upgrade/auto_upgrade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcastshortcut/src/podcast/data/subscriptions.dart';
import 'package:podcastshortcut/src/podcast/data/update_service.dart';
import 'package:podcastshortcut/src/podcast/presentation/subscriptions_screen.dart';
import 'package:podcastshortcut/src/podcast/presentation/update_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [ReleaseChecker] that never touches the network: it resolves [check]
/// with a canned [result] and counts calls.
class _FakeChecker extends ReleaseChecker {
  final UpdateCheckResult result;
  int calls = 0;

  _FakeChecker(this.result)
    : super(owner: 'etnt', repo: 'sr-podcasts', currentVersion: '1.0.0');

  @override
  Future<UpdateCheckResult> check() async {
    calls++;
    return result;
  }
}

const _updateInfo = UpdateInfo(
  latestVersion: '1.2.0',
  currentVersion: '1.0.0',
  releasePageUrl: 'https://github.com/etnt/sr-podcasts/releases/tag/v1.2.0',
  releaseNotes: 'Faster playback.',
);

/// Hosts the check from inside a MaterialApp, as the real home screen does,
/// and records "Update now" launches.
class _TriggerPage extends ConsumerStatefulWidget {
  final List<UpdateInfo> launched;

  const _TriggerPage({required this.launched});

  @override
  ConsumerState<_TriggerPage> createState() => _TriggerPageState();
}

class _TriggerPageState extends ConsumerState<_TriggerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      maybeShowUpdateDialog(
        context,
        checker: ref.read(releaseCheckerProvider),
        onUpdate: (info) async => widget.launched.add(info),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

/// Pumps the trigger page with [checker] injected through the same provider
/// the real home screen reads.
Future<List<UpdateInfo>> _pumpTrigger(
  WidgetTester tester,
  _FakeChecker checker,
) async {
  final launched = <UpdateInfo>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [releaseCheckerProvider.overrideWithValue(checker)],
      child: MaterialApp(home: _TriggerPage(launched: launched)),
    ),
  );
  await tester.pumpAndSettle();
  return launched;
}

void main() {
  group('maybeShowUpdateDialog', () {
    testWidgets('shows version and notes on UpdateAvailable', (tester) async {
      await _pumpTrigger(
        tester,
        _FakeChecker(const UpdateAvailable(_updateInfo)),
      );

      expect(find.text('Update available'), findsOneWidget);
      expect(find.textContaining('Version 1.2.0 is available'), findsOneWidget);
      expect(find.text('Faster playback.'), findsOneWidget);
    });

    testWidgets('"Update now" hands the release to onUpdate', (tester) async {
      final checker = _FakeChecker(const UpdateAvailable(_updateInfo));
      final launched = await _pumpTrigger(tester, checker);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(launched, [_updateInfo]);
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('"Later" dismisses without launching anything', (tester) async {
      final checker = _FakeChecker(const UpdateAvailable(_updateInfo));
      final launched = await _pumpTrigger(tester, checker);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(launched, isEmpty);
      expect(find.text('Update available'), findsNothing);
    });

    for (final result in <UpdateCheckResult>[
      const UpToDate(),
      const CheckSkipped(),
      const CheckError('offline'),
    ]) {
      testWidgets('stays silent on ${result.runtimeType}', (tester) async {
        final checker = _FakeChecker(result);
        final launched = await _pumpTrigger(tester, checker);

        expect(checker.calls, 1);
        expect(find.text('Update available'), findsNothing);
        expect(launched, isEmpty);
      });
    }
  });

  group('SubscriptionsScreen update check', () {
    testWidgets('runs the check on startup', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final checker = _FakeChecker(const UpToDate());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            releaseCheckerProvider.overrideWithValue(checker),
          ],
          child: const MaterialApp(home: SubscriptionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(checker.calls, 1);
    });
  });
}
