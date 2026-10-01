import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/services/player/sleep_timer_service.dart';
import 'package:mobili/widgets/player/sleep_timer_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SleepTimerService Tests', () {
    late SleepTimerService service;

    setUp(() {
      service = SleepTimerService();
      service.cancelTimer();
    });

    tearDown(() {
      service.cancelTimer();
    });

    test('Initial state is inactive and mode is none', () {
      expect(service.isActive, isFalse);
      expect(service.mode, equals(SleepTimerMode.none));
      expect(service.remainingSeconds, equals(0));
      expect(service.progress, equals(0.0));
    });

    test('startTimer sets duration mode and remaining seconds', () {
      service.startTimer(const Duration(minutes: 15));
      expect(service.isActive, isTrue);
      expect(service.isDurationMode, isTrue);
      expect(service.isEndOfVideoMode, isFalse);
      expect(service.remainingSeconds, equals(900));
      expect(service.initialSeconds, equals(900));
      expect(service.progress, closeTo(1.0, 0.01));
    });

    test('cancelTimer resets state back to none', () {
      service.startTimer(const Duration(minutes: 30));
      expect(service.isActive, isTrue);
      service.cancelTimer();
      expect(service.isActive, isFalse);
      expect(service.mode, equals(SleepTimerMode.none));
      expect(service.remainingSeconds, equals(0));
    });

    test('setEndOfVideoMode sets endOfVideo mode', () {
      service.setEndOfVideoMode();
      expect(service.isActive, isTrue);
      expect(service.isEndOfVideoMode, isTrue);
      expect(service.isDurationMode, isFalse);
    });

    test('notifyVideoFinished triggers pause callbacks when endOfVideo is active', () {
      service.setEndOfVideoMode();
      bool pauseCalled = false;
      void onPause() {
        pauseCalled = true;
      }

      service.registerPauseCallback(onPause);
      final handled = service.notifyVideoFinished();
      expect(handled, isTrue);
      expect(pauseCalled, isTrue);
      expect(service.isActive, isFalse);

      service.unregisterPauseCallback(onPause);
    });

    test('notifyVideoFinished does not trigger when mode is none', () {
      bool pauseCalled = false;
      void onPause() {
        pauseCalled = true;
      }

      service.registerPauseCallback(onPause);
      final handled = service.notifyVideoFinished();
      expect(handled, isFalse);
      expect(pauseCalled, isFalse);

      service.unregisterPauseCallback(onPause);
    });
  });

  group('SleepTimerBottomSheet Widget Tests', () {
    setUp(() {
      SleepTimerService().cancelTimer();
    });

    tearDown(() {
      SleepTimerService().cancelTimer();
    });

    testWidgets('Renders sleep timer options and handles selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SleepTimerBottomSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('睡眠定时器'), findsOneWidget);
      expect(find.text('播完当前视频后停止'), findsOneWidget);
      expect(find.text('15 分钟'), findsOneWidget);
      expect(find.text('30 分钟'), findsOneWidget);
      expect(find.text('45 分钟'), findsOneWidget);
      expect(find.text('60 分钟'), findsOneWidget);

      // Tap 15 minutes
      await tester.tap(find.text('15 分钟'));
      expect(SleepTimerService().isActive, isTrue);
      expect(SleepTimerService().isDurationMode, isTrue);
      expect(SleepTimerService().remainingSeconds, equals(15 * 60));

      SleepTimerService().cancelTimer();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
