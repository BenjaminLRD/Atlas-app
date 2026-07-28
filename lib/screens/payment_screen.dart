import 'package:flutter/material.dart';
import '../app_theme.dart';

class PaymentScreen extends StatefulWidget {
  final String planName;
  final String price;

  const PaymentScreen({
    super.key,
    required this.planName,
    required this.price,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'card'; // 'card', 'upi', 'netbanking'
  final _formKey = GlobalKey<FormState>();

  // Card controller
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  // UPI controller
  final _upiController = TextEditingController();

  // Net banking bank
  String _selectedBank = 'State Bank of India';
  final List<String> _banks = [
    'State Bank of India',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Punjab National Bank',
    'Mizoram Rural Bank',
  ];

  bool _isProcessing = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _processPayment() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isProcessing = true;
      });

      // Simulate payment processing
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          _showSuccessDialog();
        }
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.background,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Successful (Demo)',
                style: AppTheme.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your subscription to the ${widget.planName} plan has been processed successfully.',
                style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Dismiss dialog
                  Navigator.of(context).pop(true); // Return success to caller
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Back to Profile'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choose Payment Method'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Processing payment...',
                    style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary Card
                    _buildOrderSummary(),
                    const SizedBox(height: 24),

                    // Payment Mode Icons
                    Text('Select Payment Method', style: AppTheme.headlineMd.copyWith(fontSize: 18)),
                    const SizedBox(height: 12),
                    _buildMethodSelector(),
                    const SizedBox(height: 24),

                    // Form Fields based on Method
                    if (_selectedMethod == 'card') _buildCardForm(),
                    if (_selectedMethod == 'upi') _buildUpiForm(),
                    if (_selectedMethod == 'netbanking') _buildNetBankingForm(),

                    const SizedBox(height: 32),

                    // Pay Button
                    ElevatedButton(
                      onPressed: _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        'Pay ${widget.price} Now',
                        style: AppTheme.bodyMd.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPGRADE PLAN',
                style: AppTheme.labelCaps.copyWith(color: AppColors.tertiary),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.planName} Plan Suite',
                style: AppTheme.headlineMd,
              ),
            ],
          ),
          Text(
            widget.price,
            style: AppTheme.headlineLgMobile.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildMethodCard('card', Icons.credit_card, 'Card'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMethodCard('upi', Icons.qr_code, 'UPI'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMethodCard('netbanking', Icons.account_balance, 'Net Bank'),
        ),
      ],
    );
  }

  Widget _buildMethodCard(String method, IconData icon, String label) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryFixed.withValues(alpha: 0.15)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTheme.bodySm.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          controller: _nameController,
          label: 'Cardholder Name',
          hint: 'John Doe',
          icon: Icons.person,
          validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _cardNumberController,
          label: 'Card Number',
          hint: '4111 2222 3333 4444',
          icon: Icons.credit_card,
          keyboardType: TextInputType.number,
          validator: (val) {
            if (val == null || val.isEmpty) return 'Required field';
            if (val.replaceAll(' ', '').length < 16) return 'Invalid card number';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _expiryController,
                label: 'Expiry Date',
                hint: 'MM/YY',
                icon: Icons.date_range,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required field';
                  if (!val.contains('/')) return 'Invalid format';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInputField(
                controller: _cvvController,
                label: 'CVV',
                hint: '123',
                icon: Icons.lock,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required field';
                  if (val.length < 3) return 'Invalid CVV';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpiForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          controller: _upiController,
          label: 'UPI ID',
          hint: 'john@okaxis',
          icon: Icons.alternate_email,
          validator: (val) {
            if (val == null || val.isEmpty) return 'Required field';
            if (!val.contains('@')) return 'Invalid UPI ID';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                'OR SCAN QR CODE',
                style: AppTheme.labelCaps.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Image(
                  image: NetworkImage(
                    'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=aizawlgym-subscription-payment-demo',
                  ),
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetBankingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Bank',
          style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBank,
              isExpanded: true,
              dropdownColor: AppColors.background,
              items: _banks.map((String bank) {
                return DropdownMenuItem<String>(
                  value: bank,
                  child: Text(
                    bank,
                    style: AppTheme.bodyMd.copyWith(color: AppColors.onSurface),
                  ),
                );
              }).toList(),
              onChanged: (String? val) {
                if (val != null) {
                  setState(() {
                    _selectedBank = val;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          cursorColor: AppColors.primary,
          style: AppTheme.bodyMd.copyWith(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.bodyMd.copyWith(color: AppColors.outline),
            prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
