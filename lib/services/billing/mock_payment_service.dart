import '../../models/subscription_plan.dart';
import 'demo_plan_store.dart';

/// How a simulated payment ends.
enum MockPaymentOutcome { success, failure, cancelled }

/// The result of a simulated payment.
class MockPaymentResult {
  final MockPaymentOutcome outcome;
  final DemoPurchase? purchase;
  final String? message;

  const MockPaymentResult(this.outcome, {this.purchase, this.message});

  bool get succeeded => outcome == MockPaymentOutcome.success;
}

/// A SIMULATED payment. No money moves, no payment network or bank is
/// contacted, and no card number, expiry, CVV, UPI ID, PIN or OTP is passed
/// in, stored or sent anywhere: the method is only a label such as "UPI" or
/// "Google Pay". A success records a demo plan on this device only.
class MockPaymentService {
  /// Shown on every screen of the flow.
  static const String demoNotice =
      'DEMO payment. No money is charged and your real plan does not change.';

  /// Pretend processing time.
  final Duration processingTime;

  final DemoPlanStore store;
  final DateTime Function() clock;

  MockPaymentService({
    this.processingTime = const Duration(milliseconds: 1800),
    DemoPlanStore? store,
    DateTime Function()? clock,
  }) : store = store ?? DemoPlanStore.instance,
       clock = clock ?? DateTime.now;

  /// Reference shown on the receipt, clearly marked as a mock.
  static String referenceFor(DateTime at) =>
      'MOCK-${at.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

  /// Runs the simulated payment. [cancelled] is polled while "processing" so
  /// the user can back out; [outcome] lets the demo show a failed payment.
  Future<MockPaymentResult> pay({
    required PlanOffer plan,
    required PaymentMethod method,
    required String methodDetail,
    MockPaymentOutcome outcome = MockPaymentOutcome.success,
    bool Function()? cancelled,
  }) async {
    if (plan.isFree) {
      return const MockPaymentResult(
        MockPaymentOutcome.failure,
        message: 'The Free plan needs no payment.',
      );
    }
    final step = processingTime ~/ 6;
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(step);
      if (cancelled?.call() ?? false) {
        return const MockPaymentResult(
          MockPaymentOutcome.cancelled,
          message: 'Payment cancelled. You were not charged.',
        );
      }
    }
    if (outcome == MockPaymentOutcome.cancelled) {
      return const MockPaymentResult(
        MockPaymentOutcome.cancelled,
        message: 'Payment cancelled. You were not charged.',
      );
    }
    if (outcome == MockPaymentOutcome.failure) {
      return const MockPaymentResult(
        MockPaymentOutcome.failure,
        message:
            'The demo payment failed (simulated). You were not charged. '
            'Try another method.',
      );
    }
    final at = clock();
    final purchase = DemoPurchase(
      tier: plan.tier,
      amountInr: plan.priceInr,
      method: method,
      methodDetail: methodDetail,
      reference: referenceFor(at),
      at: at,
    );
    await store.record(purchase);
    return MockPaymentResult(MockPaymentOutcome.success, purchase: purchase);
  }
}
