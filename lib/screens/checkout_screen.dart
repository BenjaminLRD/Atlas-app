import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/subscription_plan.dart';
import '../services/billing/demo_plan_store.dart';
import '../services/billing/mock_payment_service.dart';

/// Demo checkout: review the order, pick a payment option, pay.
///
/// Everything here is simulated. The card fields exist only to look like a
/// real checkout: they are never read, stored or sent (the controllers are
/// cleared and discarded), and there is no UPI PIN or OTP step.
class CheckoutScreen extends StatefulWidget {
  final PlanOffer plan;

  /// Injected in tests so the flow does not wait.
  final MockPaymentService? service;

  const CheckoutScreen({super.key, required this.plan, this.service});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _upiApps = ['Google Pay', 'PhonePe', 'Paytm'];
  static const _banks = [
    'State Bank of India',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
  ];
  static const _wallets = ['Paytm Wallet', 'Amazon Pay', 'MobiKwik'];

  late final MockPaymentService _service =
      widget.service ?? MockPaymentService();

  PaymentMethod _method = PaymentMethod.upi;
  String _upiApp = _upiApps.first;
  String _bank = _banks.first;
  String _wallet = _wallets.first;
  MockPaymentOutcome _demoOutcome = MockPaymentOutcome.success;
  bool _processing = false;
  bool _cancelRequested = false;

  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String get _methodDetail {
    switch (_method) {
      case PaymentMethod.upi:
        return _upiApp;
      case PaymentMethod.netBanking:
        return _bank;
      case PaymentMethod.wallet:
        return _wallet;
      case PaymentMethod.creditCard:
        return 'Credit card';
      case PaymentMethod.debitCard:
        return 'Debit card';
    }
  }

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _cancelRequested = false;
    });
    final result = await _service.pay(
      plan: widget.plan,
      method: _method,
      methodDetail: _methodDetail,
      outcome: _demoOutcome,
      cancelled: () => _cancelRequested,
    );
    // Nothing typed into the demo card fields is kept.
    _cardNumber.clear();
    _expiry.clear();
    _cvv.clear();
    if (!mounted) return;
    setState(() => _processing = false);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(plan: widget.plan, result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appBackground,
          elevation: 0,
          title: const Text('Checkout'),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DemoNotice(),
                  const SizedBox(height: 16),
                  _orderSummary(context, plan),
                  const SizedBox(height: 20),
                  _sectionTitle(context, 'Payment method'),
                  for (final m in PaymentMethod.values) _methodTile(context, m),
                  const SizedBox(height: 8),
                  _methodDetails(context),
                  const SizedBox(height: 20),
                  _outcomePicker(context),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('pay_button'),
                      onPressed: _processing ? null : _pay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appPrimary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Pay ₹${plan.priceInr} (demo)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No real payment is made. Do not enter real card, UPI PIN or OTP details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_processing) _processingOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _processingOverlay(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: context.appPrimary),
                const SizedBox(height: 18),
                const Text(
                  'Processing demo payment…',
                  key: Key('processing_text'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  key: const Key('cancel_payment'),
                  onPressed: () => setState(() => _cancelRequested = true),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2),
    child: Text(
      text.toUpperCase(),
      style: AppTheme.labelCaps.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: context.appTextSecondary,
      ),
    ),
  );

  Widget _orderSummary(BuildContext context, PlanOffer plan) {
    Widget row(String l, String r, {bool bold = false, Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l,
              style: TextStyle(
                color: bold ? context.appTextPrimary : context.appTextSecondary,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              r,
              key: key,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: bold ? context.appPrimary : context.appTextPrimary,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                fontSize: bold ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Order summary'),
          row('Plan', plan.name),
          row('Price', '${plan.priceLabel} / month'),
          row('Billing period', 'Monthly (demo, no renewal)'),
          // No discount is supported, so none is shown.
          Divider(color: context.appOutlineVariant, height: 20),
          row(
            'Total payable',
            '₹${plan.priceInr}',
            bold: true,
            key: const Key('total_payable'),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(BuildContext context, PaymentMethod m) {
    final selected = _method == m;
    final icon = switch (m) {
      PaymentMethod.upi => Icons.qr_code_2_rounded,
      PaymentMethod.creditCard => Icons.credit_card_rounded,
      PaymentMethod.debitCard => Icons.payment_rounded,
      PaymentMethod.netBanking => Icons.account_balance_rounded,
      PaymentMethod.wallet => Icons.account_balance_wallet_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('method_${m.name}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _method = m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? context.appPrimary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: context.isDarkMode ? 0.04 : 0),
            border: Border.all(
              color: selected
                  ? context.appPrimary
                  : context.appOutlineVariant.withValues(alpha: 0.7),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? context.appPrimary : context.appTextSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  m.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? context.appPrimary : context.appTextMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceWrap(
    BuildContext context,
    List<String> options,
    String selected,
    ValueChanged<String> onPick,
    String keyPrefix,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            key: Key('$keyPrefix$o'),
            label: Text(o),
            selected: selected == o,
            selectedColor: context.appPrimary.withValues(alpha: 0.25),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected == o
                  ? context.appPrimary
                  : context.appTextPrimary,
            ),
            onSelected: (_) => setState(() => onPick(o)),
          ),
      ],
    );
  }

  Widget _methodDetails(BuildContext context) {
    switch (_method) {
      case PaymentMethod.upi:
        return GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pay with',
                style: TextStyle(color: context.appTextSecondary),
              ),
              const SizedBox(height: 10),
              _choiceWrap(
                context,
                _upiApps,
                _upiApp,
                (v) => _upiApp = v,
                'upi_',
              ),
              const SizedBox(height: 10),
              Text(
                'Demo: no UPI ID, PIN or approval request is used.',
                style: TextStyle(fontSize: 12, color: context.appTextMuted),
              ),
            ],
          ),
        );
      case PaymentMethod.creditCard:
      case PaymentMethod.debitCard:
        return GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('card_number'),
                controller: _cardNumber,
                keyboardType: TextInputType.number,
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                ],
                decoration: const InputDecoration(
                  labelText: 'Card number (demo)',
                  hintText: '0000 0000 0000 0000',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('card_expiry'),
                      controller: _expiry,
                      keyboardType: TextInputType.number,
                      enableSuggestions: false,
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Expiry',
                        hintText: 'MM/YY',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('card_cvv'),
                      controller: _cvv,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      enableSuggestions: false,
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '•••',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Demo fields. Never enter a real card; nothing typed here is saved or sent.',
                style: TextStyle(fontSize: 12, color: context.appTextMuted),
              ),
            ],
          ),
        );
      case PaymentMethod.netBanking:
        return GlassPanel(
          child: _choiceWrap(context, _banks, _bank, (v) => _bank = v, 'bank_'),
        );
      case PaymentMethod.wallet:
        return GlassPanel(
          child: _choiceWrap(
            context,
            _wallets,
            _wallet,
            (v) => _wallet = v,
            'wallet_',
          ),
        );
    }
  }

  Widget _outcomePicker(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEMO CONTROL',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 10,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how this simulated payment ends.',
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                key: const Key('outcome_success'),
                label: const Text('Succeeds'),
                selected: _demoOutcome == MockPaymentOutcome.success,
                onSelected: (_) =>
                    setState(() => _demoOutcome = MockPaymentOutcome.success),
              ),
              ChoiceChip(
                key: const Key('outcome_failure'),
                label: const Text('Fails'),
                selected: _demoOutcome == MockPaymentOutcome.failure,
                onSelected: (_) =>
                    setState(() => _demoOutcome = MockPaymentOutcome.failure),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The notice that marks every part of the flow as a demo.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final amber = context.isDarkMode
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);
    return Container(
      key: const Key('demo_notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_rounded, color: amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              MockPaymentService.demoNotice,
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent card shared by the checkout and plan pages.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [Colors.white, Colors.white.withValues(alpha: 0.7)],
        ),
        border: Border.all(
          color:
              borderColor ??
              (dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : context.appOutlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: child,
    );
  }
}

/// Outcome of a demo payment: receipt, failure or cancellation.
class PaymentResultScreen extends StatelessWidget {
  final PlanOffer plan;
  final MockPaymentResult result;

  const PaymentResultScreen({
    super.key,
    required this.plan,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final purchase = result.purchase;
    final ok = result.succeeded && purchase != null;
    final cancelled = result.outcome == MockPaymentOutcome.cancelled;
    final color = ok
        ? context.appPrimary
        : (cancelled ? context.appTextSecondary : const Color(0xFFF87171));
    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  ok
                      ? Icons.check_rounded
                      : (cancelled ? Icons.close_rounded : Icons.error_outline),
                  size: 44,
                  color: color,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                ok
                    ? 'Demo payment successful'
                    : (cancelled ? 'Payment cancelled' : 'Payment failed'),
                key: const Key('result_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ok
                    ? 'You are now on ${plan.name} in the demo.'
                    : (result.message ?? 'Something went wrong.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appTextSecondary),
              ),
              const SizedBox(height: 20),
              const DemoNotice(),
              if (ok) ...[
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    children: [
                      _line(context, 'Plan', plan.name),
                      _line(context, 'Amount', '₹${purchase.amountInr}'),
                      _line(
                        context,
                        'Method',
                        purchase.methodDetail.isEmpty
                            ? purchase.method.label
                            : '${purchase.method.label} · ${purchase.methodDetail}',
                      ),
                      _line(
                        context,
                        'Mock reference',
                        purchase.reference,
                        key: const Key('mock_reference'),
                      ),
                      _line(
                        context,
                        'Status',
                        'DEMO TRANSACTION, not a real payment',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('result_done'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appPrimary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    ok ? 'Back to Atlas' : 'Back to plans',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String l, String r, {Key? key}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: TextStyle(color: context.appTextSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              r,
              key: key,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only helper for tests and the plan page.
String describeDemoPurchase(DemoPurchase? p) => p == null
    ? 'No demo purchase'
    : '${PlanCatalog.of(p.tier).name} · ₹${p.amountInr} · ${p.reference}';
