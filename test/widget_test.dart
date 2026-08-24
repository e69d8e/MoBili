import 'package:flutter_test/flutter_test.dart';
import 'package:mobili/main.dart';
import 'package:mobili/providers/auth_provider.dart';
import 'package:mobili/providers/home_provider.dart';
import 'package:mobili/providers/listen_video_provider.dart';
import 'package:mobili/providers/search_provider.dart';
import 'package:mobili/providers/theme_provider.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    final homeProvider = HomeProvider();
    final searchProvider = SearchProvider();
    final themeProvider = ThemeProvider();
    final listenVideoProvider = ListenVideoProvider();

    await tester.pumpWidget(
      MoBiliRoot(
        authProvider: authProvider,
        homeProvider: homeProvider,
        searchProvider: searchProvider,
        themeProvider: themeProvider,
        listenVideoProvider: listenVideoProvider,
      ),
    );
    expect(find.byType(MoBiliApp), findsOneWidget);
  });
}
