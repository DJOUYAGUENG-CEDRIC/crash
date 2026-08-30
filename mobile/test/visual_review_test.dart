import 'dart:io';
import 'dart:typed_data';

import 'package:crashx/models/bet.dart';
import 'package:crashx/models/enums.dart';
import 'package:crashx/models/game_round.dart';
import 'package:crashx/providers/game_providers.dart';
import 'package:crashx/providers/service_providers.dart';
import 'package:crashx/screens/crash/crash_screen.dart';
import 'package:crashx/widgets/game_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

Widget _screen(GameRound round, {List<Bet> myBets = const []}) {
  return ProviderScope(
    overrides: [
      gameServiceProvider.overrideWithValue(FakeGameService()),
      currentRoundProvider.overrideWith((ref) => Stream.value(round)),
      myBetsForCurrentRoundProvider.overrideWith((ref) => Stream.value(myBets)),
      liveBetsForCurrentRoundProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const Scaffold(
        body: RepaintBoundary(key: Key('capture'), child: CrashScreen()),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    if (Platform.isWindows) {
      final bytes = await File(r'C:\Windows\Fonts\arial.ttf').readAsBytes();
      final data = ByteData.view(Uint8List.fromList(bytes).buffer);
      await (FontLoader('Roboto')..addFont(Future.value(data))).load();
    }
  });

  setUp(() => gameNoticeController.value = null);

  Future<void> prepare(WidgetTester tester, Widget widget) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  testWidgets('countdown visual review', (tester) async {
    final round = sampleRound(
      status: RoundStatus.betting,
      bettingStartedAt: DateTime.now().subtract(const Duration(seconds: 2)),
    );
    await prepare(tester, _screen(round));
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/countdown.png'),
    );
  });

  testWidgets('accepted bet visual review', (tester) async {
    final round = sampleRound(
      status: RoundStatus.running,
      runningStartedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    );
    await prepare(
      tester,
      _screen(round, myBets: [sampleBet(status: BetStatus.active)]),
    );
    gameNoticeController.show('Votre pari est accepté !');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Votre pari est accepté !'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/bet_accepted.png'),
    );
  });

  testWidgets('gain visual review', (tester) async {
    final round = sampleRound(
      status: RoundStatus.running,
      runningStartedAt: DateTime.now().subtract(const Duration(seconds: 8)),
    );
    await prepare(tester, _screen(round));
    gameNoticeController.show('Vous avez gagné : 1995 XAF');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Vous avez gagné : 1995 XAF'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/gain.png'),
    );
  });

  testWidgets('crashed table visual review', (tester) async {
    final round = sampleRound(
      status: RoundStatus.crashed,
      crashMultiplier: 2.18,
      runningStartedAt: DateTime.now().subtract(const Duration(seconds: 11)),
    );
    await prepare(tester, _screen(round));
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/table_crashed.png'),
    );
  });
}
