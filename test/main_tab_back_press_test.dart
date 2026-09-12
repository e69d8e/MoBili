import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobili/providers/auth_provider.dart';
import 'package:mobili/providers/home_provider.dart';
import 'package:mobili/providers/listen_video_provider.dart';
import 'package:mobili/providers/search_provider.dart';
import 'package:mobili/providers/theme_provider.dart';
import 'package:mobili/screens/main_tab_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int popCallCount;
  late DateTime mockNow;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    popCallCount = 0;
    mockNow = DateTime(2026, 9, 8, 12, 0, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'SystemNavigator.pop') {
        popCallCount++;
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpMainScreen(WidgetTester tester) async {
    final authProvider = AuthProvider();
    final homeProvider = HomeProvider();
    final searchProvider = SearchProvider();
    final themeProvider = ThemeProvider();
    final listenVideoProvider = ListenVideoProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: homeProvider),
          ChangeNotifierProvider.value(value: searchProvider),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: listenVideoProvider),
        ],
        child: MaterialApp(
          home: MainTabScreen(nowProvider: () => mockNow),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Pressing back on Home tab shows toast and requires double back to exit',
      (WidgetTester tester) async {
    await pumpMainScreen(tester);

    // Initial state: no exit calls
    expect(popCallCount, equals(0));

    // First back press
    await tester.binding.handlePopRoute();
    await tester.pump();

    // Verify toast is displayed and pop was not called
    expect(find.text('再次返回退出应用'), findsOneWidget);
    expect(popCallCount, equals(0));

    // Advance mock time slightly (500ms)
    mockNow = mockNow.add(const Duration(milliseconds: 500));

    // Second back press within 2 seconds
    await tester.binding.handlePopRoute();
    await tester.pump();

    // Verify SystemNavigator.pop was called
    expect(popCallCount, equals(1));

    // Drain toast timers
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('Pressing back on Dynamic tab shows toast and requires double back to exit',
      (WidgetTester tester) async {
    await pumpMainScreen(tester);

    // Switch to Dynamic tab
    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();

    // First back press
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('再次返回退出应用'), findsOneWidget);
    expect(popCallCount, equals(0));

    // Advance mock time slightly (400ms)
    mockNow = mockNow.add(const Duration(milliseconds: 400));

    // Second back press within 2 seconds
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(popCallCount, equals(1));

    // Drain toast timers
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('Pressing back on Profile tab resets after 2 seconds delay',
      (WidgetTester tester) async {
    await pumpMainScreen(tester);

    // Switch to Profile tab
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    // First back press
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('再次返回退出应用'), findsOneWidget);
    expect(popCallCount, equals(0));

    // Advance mock time past 2 seconds (2500ms)
    mockNow = mockNow.add(const Duration(milliseconds: 2500));
    // Also pump virtual timer past toast duration
    await tester.pump(const Duration(milliseconds: 2500));

    // Back press again after timeout -> should show toast again, not exit
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('再次返回退出应用'), findsOneWidget);
    expect(popCallCount, equals(0));

    // Advance mock time slightly (300ms)
    mockNow = mockNow.add(const Duration(milliseconds: 300));

    // Immediate second back press within 2 seconds -> should exit
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(popCallCount, equals(1));

    // Drain toast timers
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
