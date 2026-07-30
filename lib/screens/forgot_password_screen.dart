import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Stack(
        children: [
          // Ambient background green glow matching LoginScreen
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Back Button Navigation Bar
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.appSurfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: context.appTextPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Branding / Reset Header Block
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.appSurfaceElevated,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock_reset_rounded,
                              color: AppColors.primary,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Forgot Password?',
                          style: AppTheme.headlineLgMobile.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "Enter your registered email address to receive instant password reset instructions.",
                            textAlign: TextAlign.center,
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 13,
                              color: context.appTextSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2. Main Form or Confirmation State Glass Card
                  if (!_emailSent)
                    _buildResetFormCard(context)
                  else
                    _buildSuccessCard(context),

                  const SizedBox(height: 20),

                  // Footer Back to Login Link
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '← Back to Login',
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetFormCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset Password',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We will send a secure recovery link to your inbox.',
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Email Address Input Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTheme.bodySm.copyWith(
                fontSize: 15,
                color: context.appTextPrimary,
              ),
              validator: _validateEmail,
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: AppTheme.bodySm.copyWith(
                  fontSize: 13,
                  color: context.appTextSecondary,
                ),
                hintText: 'athlete@aizawlgym.com',
                hintStyle: AppTheme.bodySm.copyWith(
                  fontSize: 14,
                  color: context.appTextSecondary.withValues(alpha: 0.6),
                ),
                prefixIcon: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                filled: true,
                fillColor: context.appSurfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.appOutlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.appOutlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Primary Reset Action Button
            AppButton.primary(
              label: 'Send Reset Link',
              icon: Icons.send_rounded,
              isLoading: _isLoading,
              onPressed: _sendResetLink,
              isFullWidth: false,
              isPill: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Check Your Inbox!',
            style: AppTheme.headlineLgMobile.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Password recovery instructions have been dispatched to:',
            textAlign: TextAlign.center,
            style: AppTheme.bodySm.copyWith(
              fontSize: 13,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _emailController.text,
            textAlign: TextAlign.center,
            style: AppTheme.bodySm.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          AppButton.primary(
            label: 'Back to Login',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
            isFullWidth: false,
            isPill: true,
          ),
        ],
      ),
    );
  }
}
