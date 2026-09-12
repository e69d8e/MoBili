import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/utils/responsive_util.dart';
import 'package:mobili/widgets/state_views.dart';

void main() {
  group('ResponsiveGridConfig Tests', () {
    testWidgets('Calculates 2 columns on phone widths (< 600)', (tester) async {
      int? crossAxisCount;
      double? aspectRatio;

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              crossAxisCount = ResponsiveGridConfig.calculateCrossAxisCount(
                context,
              );
              aspectRatio = ResponsiveGridConfig.calculateChildAspectRatio(
                context,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(crossAxisCount, equals(2));
      expect(aspectRatio, equals(0.95));
    });

    testWidgets('Calculates 3 columns on tablet widths (600 - 959)', (
      tester,
    ) async {
      int? crossAxisCount;
      double? aspectRatio;

      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              crossAxisCount = ResponsiveGridConfig.calculateCrossAxisCount(
                context,
              );
              aspectRatio = ResponsiveGridConfig.calculateChildAspectRatio(
                context,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(crossAxisCount, equals(3));
      expect(aspectRatio, equals(0.98));
    });

    testWidgets(
      'Calculates 4 columns on desktop standard widths (960 - 1319)',
      (tester) async {
        int? crossAxisCount;
        double? aspectRatio;

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                crossAxisCount = ResponsiveGridConfig.calculateCrossAxisCount(
                  context,
                );
                aspectRatio = ResponsiveGridConfig.calculateChildAspectRatio(
                  context,
                );
                return const SizedBox();
              },
            ),
          ),
        );

        expect(crossAxisCount, equals(4));
        expect(aspectRatio, equals(1.02));
      },
    );

    testWidgets('Calculates 5 columns on wide desktop widths (>= 1320)', (
      tester,
    ) async {
      int? crossAxisCount;

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              crossAxisCount = ResponsiveGridConfig.calculateCrossAxisCount(
                context,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(crossAxisCount, equals(5));
    });
  });

  group('StateViews & Skeleton UI Tests', () {
    testWidgets(
      'VideoGridSkeleton renders without errors and contains skeleton cards',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: VideoGridSkeleton(itemCount: 4)),
          ),
        );

        expect(find.byType(VideoGridSkeleton), findsOneWidget);
        expect(find.byType(VideoCardSkeleton), findsNWidgets(4));
        expect(find.byType(ShimmerLoading), findsOneWidget);

        // Advance animation frame
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(VideoCardSkeleton), findsNWidgets(4));
      },
    );

    testWidgets('CommentSkeleton renders placeholder rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentSkeleton(itemCount: 3))),
      );

      expect(find.byType(CommentSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets(
      'EmptyView renders with message, icon, and handles retry callback',
      (tester) async {
        bool retried = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyView(
                message: '测试空状态',
                icon: Icons.inbox_rounded,
                retryText: '重新加载',
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        expect(find.text('测试空状态'), findsOneWidget);
        expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
        expect(find.text('重新加载'), findsOneWidget);

        await tester.tap(find.text('重新加载'));
        await tester.pump();
        expect(retried, isTrue);
      },
    );

    testWidgets('ErrorView renders error outline icon and triggers retry', (
      tester,
    ) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(message: '网络异常，请重试', onRetry: () => retried = true),
          ),
        ),
      );

      expect(find.text('网络异常，请重试'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });
}
