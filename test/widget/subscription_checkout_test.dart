import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/premium_feature.dart';
import 'package:atlas/models/subscription_plan.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/checkout_screen.dart';
import 'package:atlas/screens/subscription_screen.dart';
import 'package:atlas/services/billing/demo_plan_store.dart';
import 'package:atlas/services/billing/mock_payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpPlans(
  WidgetTester tester, {
  Size size = const Size(390, 900),
  double scale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: const SubscriptionScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('plans', () {
    test('prices are Free 0, Plus 199 and Pro 499 rupees a month', () {
      expect(PlanCatalog.free.priceLabel, '₹0');
      expect(PlanCatalog.plus.priceLabel, '₹199');
      expect(PlanCatalog.pro.priceLabel, '₹499');
      expect(PlanCatalog.all.map((p) => p.tier), [
        PlanTier.free,
        PlanTier.plus,
        PlanTier.pro,
      ]);
      expect(PlanCatalog.plus.recommended, isTrue);
      expect(PlanCatalog.pro.premium, isTrue);
    });

    test('nothing is called unlimited, and future items are marked soon', () {
      for (final p in PlanCatalog.all) {
        for (final f in p.features) {
          expect(f.text.toLowerCase(), isNot(contains('unlimited')));
        }
      }
      expect(PlanCatalog.plus.features.any((f) => f.comingSoon), isTrue);
      expect(PlanCatalog.pro.features.last.comingSoon, isTrue);
    });

    testWidgets('the page shows three plans with prices and features', (
      tester,
    ) async {
      await _pumpPlans(tester);
      expect(find.byKey(const Key('price_free')), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      await _scrollTo(tester, find.byKey(const Key('price_plus')));
      expect(find.text('₹199'), findsOneWidget);
      expect(find.text('RECOMMENDED'), findsOneWidget);
      await _scrollTo(tester, find.byKey(const Key('price_pro')));
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.textContaining('Atlas AI: up to 400 requests'), findsOne);
    });

    testWidgets('Free is the current plan to start with', (tester) async {
      await _pumpPlans(tester);
      expect(find.text('Your plan: Free'), findsOneWidget);
      expect(find.text('Current plan'), findsOneWidget);
    });

    for (final w in const [320.0, 360.0, 412.0]) {
      for (final s in const [1.0, 1.5, 2.0]) {
        testWidgets('no overflow at ${w.toInt()}dp, text x$s', (tester) async {
          await _pumpPlans(tester, size: Size(w, 800), scale: s);
          for (final k in ['price_plus', 'price_pro']) {
            await _scrollTo(tester, find.byKey(Key(k)));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('checkout and demo payment', () {
    Future<void> openCheckout(WidgetTester tester, String key) async {
      await _pumpPlans(tester);
      await _scrollTo(tester, find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('choosing Plus opens checkout with the right order', (
      tester,
    ) async {
      await openCheckout(tester, 'plan_button_plus');
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(find.byKey(const Key('demo_notice')), findsOneWidget);
      expect(find.text('Atlas Plus'), findsWidgets);
      expect(
        tester.widget<Text>(find.byKey(const Key('total_payable'))).data,
        '₹199',
      );
      expect(find.text('Pay ₹199 (demo)'), findsOneWidget);
    });

    testWidgets('all five payment methods are offered', (tester) async {
      await openCheckout(tester, 'plan_button_pro');
      for (final m in PaymentMethod.values) {
        expect(find.byKey(Key('method_${m.name}')), findsOneWidget);
      }
      expect(find.byKey(const Key('upi_Google Pay')), findsOneWidget);
      expect(find.byKey(const Key('upi_PhonePe')), findsOneWidget);
      expect(find.byKey(const Key('upi_Paytm')), findsOneWidget);
      await _tapKey(tester, 'method_creditCard');
      await tester.pump();
      expect(find.byKey(const Key('card_number')), findsOneWidget);
      expect(find.byKey(const Key('card_expiry')), findsOneWidget);
      expect(find.byKey(const Key('card_cvv')), findsOneWidget);
      await _tapKey(tester, 'method_netBanking');
      await tester.pump();
      expect(find.byKey(const Key('bank_HDFC Bank')), findsOneWidget);
    });

    testWidgets('a successful demo payment upgrades the demo plan only', (
      tester,
    ) async {
      await openCheckout(tester, 'plan_button_plus');
      await _tapKey(tester, 'upi_PhonePe');
      await tester.pump();
      await _tapKey(tester, 'pay_button');
      await tester.pump();
      expect(find.byKey(const Key('processing_text')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('result_title')), findsOneWidget);
      expect(find.text('Demo payment successful'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('mock_reference'))).data,
        startsWith('MOCK-'),
      );
      expect(find.textContaining('DEMO TRANSACTION'), findsOneWidget);
      expect(find.textContaining('UPI · PhonePe'), findsOneWidget);

      await tester.tap(find.byKey(const Key('result_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your plan: Atlas Plus'), findsOneWidget);
      expect(find.text('Current plan (demo)'), findsOneWidget);
      expect(DemoPlanStore.instance.demoTier, PlanTier.plus);

      // Real entitlements did not change.
      final provider = FitnessProvider.instance;
      expect(provider.isPremium, isFalse);
      expect(provider.canAccessFeature(PremiumFeature.wearableSync), isFalse);
      expect(provider.subscription.productIdentifier, 'free_plan');

      // And the demo plan can be put back to Free.
      await tester.pumpAndSettle();
      await _tapKey(tester, 'switch_to_free');
      await tester.pump();
      expect(DemoPlanStore.instance.demoTier, PlanTier.free);
      expect(find.text('Your plan: Free'), findsOneWidget);
    });

    testWidgets('a failed demo payment charges nothing and keeps Free', (
      tester,
    ) async {
      await openCheckout(tester, 'plan_button_plus');
      await _tapKey(tester, 'outcome_failure');
      await tester.pump();
      await _tapKey(tester, 'pay_button');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.textContaining('not charged'), findsWidgets);
      expect(DemoPlanStore.instance.demoTier, PlanTier.free);
      await tester.tap(find.byKey(const Key('result_done')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your plan: Free'), findsOneWidget);
    });

    testWidgets('cancelling while processing keeps Free', (tester) async {
      await openCheckout(tester, 'plan_button_pro');
      await _tapKey(tester, 'pay_button');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('cancel_payment')));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Payment cancelled'), findsOneWidget);
      expect(DemoPlanStore.instance.demoTier, PlanTier.free);
    });

    testWidgets('card details typed in the demo are never stored', (
      tester,
    ) async {
      await openCheckout(tester, 'plan_button_plus');
      await _tapKey(tester, 'method_creditCard');
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('card_number')),
        '4111111111111111',
      );
      await tester.enterText(find.byKey(const Key('card_expiry')), '12/30');
      await tester.enterText(find.byKey(const Key('card_cvv')), '123');
      await _tapKey(tester, 'pay_button');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      final prefs = await SharedPreferences.getInstance();
      final all = prefs.getKeys().map((k) => '$k=${prefs.get(k)}').join('\n');
      expect(all, isNot(contains('4111111111111111')));
      expect(all, isNot(contains('12/30')));
      expect(all, isNot(contains('"123"')));
      expect(all, contains('MOCK-'));
    });
  });

  group('Showcase isolation', () {
    test(
      'a Showcase demo purchase uses its own key and no billing record',
      () async {
        await LocalStorage.setShowcaseModeEnabled(true);
        addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
        final svc = MockPaymentService(processingTime: Duration.zero);
        final r = await svc.pay(
          plan: PlanCatalog.pro,
          method: PaymentMethod.upi,
          methodDetail: 'Google Pay',
        );
        expect(r.succeeded, isTrue);
        expect(DemoPlanStore.instance.demoTier, PlanTier.pro);
        expect(LocalStorage.getString(DemoPlanStore.showcaseKey), isNotEmpty);
        expect(LocalStorage.getString(DemoPlanStore.realKey), isNull);
        // No subscription record was written.
        expect(FitnessProvider.instance.isPremium, isFalse);

        // Leaving Showcase: the real account is still Free.
        await LocalStorage.setShowcaseModeEnabled(false);
        expect(DemoPlanStore.instance.demoTier, PlanTier.free);
      },
    );

    test('the Free plan cannot be "paid" for', () async {
      final r = await MockPaymentService(processingTime: Duration.zero).pay(
        plan: PlanCatalog.free,
        method: PaymentMethod.upi,
        methodDetail: '',
      );
      expect(r.outcome, MockPaymentOutcome.failure);
    });
  });
}
