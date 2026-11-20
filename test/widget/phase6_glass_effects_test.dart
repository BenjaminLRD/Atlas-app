import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/theme/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/main.dart';
import 'package:atlas/widgets/ai_chat_button.dart';
import 'package:atlas/widgets/app_drawer.dart';
import 'package:atlas/widgets/common/app_glass.dart';
import 'package:atlas/screens/ai_coach_screen.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.instance;
  });

  Widget buildTestApp(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(body: child),
    );
  }

  group('Phase 6 Glass Effects Tests', () {
    testWidgets(
      'AppGlassContainer renders with BackdropFilter, blur, border, and shadows',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            AppGlassContainer(
              blur: 16.0,
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.8),
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
              child: const Text('Glass Content'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Glass Content'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);

        final backdropFilter = tester.widget<BackdropFilter>(
          find.byType(BackdropFilter),
        );
        expect(backdropFilter.filter, isNotNull);
      },
    );

    testWidgets(
      'AiChatButton renders with AppGlassContainer.fab and BackdropFilter',
      (tester) async {
        await tester.pumpWidget(buildTestApp(const AiChatButton()));
        await tester.pump();

        expect(find.byType(AiChatButton), findsOneWidget);
        expect(find.byType(AppGlassContainer), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'MainShell floating Bottom Navigation renders with AppGlassContainer.bottomNav',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const MainShell()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify bottom navigation contains AppGlassContainer and BackdropFilter
        expect(find.byType(AppGlassContainer), findsWidgets);
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
        expect(find.text('Diet Plan'), findsOneWidget);
        expect(find.text('Workouts'), findsOneWidget);
        expect(find.text('Community'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      },
    );

    testWidgets(
      'AppDrawer renders with BackdropFilter, frosted glass transparency and 0 overflows',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final scaffoldKey = GlobalKey<ScaffoldState>();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              key: scaffoldKey,
              drawer: const AppDrawer(),
              body: const Center(child: Text('Home')),
            ),
          ),
        );
        await tester.pump();

        scaffoldKey.currentState?.openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppDrawer), findsOneWidget);
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(find.text('MAIN'), findsOneWidget);
        expect(find.text('TRAINING'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AICoachScreen renders messages with AppGlassContainer.chatBubble or AppGlass',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const AICoachScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(AICoachScreen), findsOneWidget);
        expect(find.byType(AppGlassContainer), findsWidgets);
      },
    );
  });
}
