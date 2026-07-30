import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    await LocalStorage.setLoggedIn(true);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    await LocalStorage.setLoggedIn(true);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    await LocalStorage.setLoggedIn(true);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Stack(
        children: [
          // Background ambient green glow highlights
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // 1. Logo & App Branding Header
                  _buildBrandingHeader(context),
                  const SizedBox(height: 24),

                  // 2. Main Login Form Card
                  _buildLoginFormCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandingHeader(BuildContext context) {
    return Column(
      children: [
        // Dumbbell Circle Icon Container
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.appSurfaceElevated,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Brand Title Text
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Aizawl ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Gym',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Tagline Subtitle
        Text(
          'Stronger Every Day',
          style: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Title & Subtitle
            Text(
              'Welcome Back',
              style: AppTheme.headlineLg.copyWith(
                fontSize: 22,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Login to continue your fitness journey',
              style: AppTheme.bodySm.copyWith(
                color: context.appTextSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),

            // Email Address Input Field
            Text(
              'Email Address',
              style: AppTheme.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              style: AppTheme.bodySm.copyWith(color: context.appTextPrimary, fontSize: 14),
              decoration: _inputDecoration(
                context,
                hint: 'Enter your email',
                icon: Icons.mail_outline_rounded,
              ),
            ),
            const SizedBox(height: 16),

            // Password Input Field
            Text(
              'Password',
              style: AppTheme.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: _validatePassword,
              style: AppTheme.bodySm.copyWith(color: context.appTextPrimary, fontSize: 14),
              decoration: _inputDecoration(
                context,
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: context.appTextSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Forgot Password Link
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                child: Text(
                  'Forgot Password?',
                  style: AppTheme.bodySm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Primary Login Button
            AppButton.primary(
              label: 'Login',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleLogin,
            ),
            const SizedBox(height: 22),

            // Divider "or continue with"
            Row(
              children: [
                Expanded(child: Divider(color: context.appOutlineVariant.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: context.appOutlineVariant.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(height: 16),

            // Social Buttons Row
            Row(
              children: [
                Expanded(
                  child: _buildSocialButton(
                    context,
                    label: 'Google',
                    icon: _googleIcon(),
                    onTap: _handleGoogleSignIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSocialButton(
                    context,
                    label: 'Apple',
                    icon: Icon(Icons.apple, size: 20, color: context.appTextPrimary),
                    onTap: _handleAppleSignIn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Sign Up Footer Link
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appOutlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.bodySm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.bodySm.copyWith(
        color: context.appTextSecondary.withValues(alpha: 0.6),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
      suffixIcon: suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix,
            )
          : null,
      filled: true,
      fillColor: context.appSurfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.appOutlineVariant.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.appOutlineVariant.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _googleIcon() {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRed = Paint()..color = const Color(0xFFEA4335);
    final paintBlue = Paint()..color = const Color(0xFF4285F4);
    final paintYellow = Paint()..color = const Color(0xFFFBBC04);
    final paintGreen = Paint()..color = const Color(0xFF34A853);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      1.5708,
      false,
      paintBlue..strokeWidth = radius * 0.35..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.5708,
      false,
      paintGreen..strokeWidth = radius * 0.35..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.5708,
      1.5708,
      false,
      paintYellow..strokeWidth = radius * 0.35..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.1416,
      1.5708,
      false,
      paintRed..strokeWidth = radius * 0.35..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(
      center,
      innerRadius,
      Paint()..color = Colors.transparent,
    );

    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.12, radius * 0.9, radius * 0.24),
      Paint()..color = paintBlue.color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
