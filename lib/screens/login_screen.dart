import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../widgets/common/app_button.dart';
import 'forgot_password_screen.dart';
import '../main.dart';
import '../providers/fitness_provider.dart';
import '../providers/showcase_mode_provider.dart';
import '../services/cloud/auth_availability.dart';
import '../services/cloud/auth_failure.dart';
import '../services/onboarding_state_service.dart';
import 'onboarding/user_goal_setup_flow.dart';

/// Signs in or registers with the given credentials. Throws on failure.
typedef AuthSubmit =
    Future<void> Function({
      required String email,
      required String password,
      required bool isSignUp,
    });

class LoginScreen extends StatefulWidget {
  /// Replaces the real authentication call. Only for tests.
  @visibleForTesting
  final AuthSubmit? submitOverride;

  const LoginScreen({super.key, this.submitOverride});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _radius = 12;
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isCreatingAccount = false;
  CloudAuthException? _notice;

  /// Release build without Supabase: no account can be created or used.
  late final bool _accountsUnavailable = AuthAvailability.accountsUnavailable;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (_isCreatingAccount && value.length < 8) {
      return 'Use at least 8 characters';
    }
    return null;
  }

  Future<void> _defaultSubmit({
    required String email,
    required String password,
    required bool isSignUp,
  }) async {
    if (isSignUp) {
      await FitnessProvider.instance.signup(email: email, password: password);
    } else {
      await FitnessProvider.instance.login(email: email, password: password);
    }
    await LocalStorage.setLoggedIn(true);
    await OnboardingStateService.instance.setCompletedOnboarding(true);
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (_accountsUnavailable) {
      setState(() => _notice = AuthAvailability.exception);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _notice = null;
    });
    final submit = widget.submitOverride ?? _defaultSubmit;
    try {
      await submit(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        isSignUp: _isCreatingAccount,
      );
      if (!mounted) return;
      final goalCompleted =
          LocalStorage.isGoalOnboardingCompleted() ||
          FitnessProvider.instance.currentGoal != null;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              goalCompleted ? const MainShell() : const UserGoalSetupFlow(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final failure = e is FormatException
          ? CloudAuthException(e.message)
          : AuthFailure.from(e, operation: 'submit');
      setState(() {
        _notice = failure;
        if (failure.kind == AuthFailureKind.emailConfirmationRequired) {
          // The account exists now; continue on the sign-in form.
          _isCreatingAccount = false;
          _passwordController.clear();
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleShowcaseMode() async {
    setState(() => _isLoading = true);
    await ShowcaseModeProvider.instance.enableShowcaseMode();
    await OnboardingStateService.instance.setCompletedOnboarding(true);
    await LocalStorage.setLoggedIn(true);
    await LocalStorage.setGoalOnboardingCompleted(true);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _isCreatingAccount = !_isCreatingAccount;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 20),
                      _buildForm(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.primary.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Atlas',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Stronger every day',
          style: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isCreatingAccount ? 'Create your account' : 'Welcome Back',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isCreatingAccount
                    ? 'Save your training, meals and progress.'
                    : 'Log in to continue your training.',
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                  fontSize: 13,
                ),
              ),
              if (_accountsUnavailable || _notice != null) ...[
                const SizedBox(height: 14),
                _AuthNotice(notice: _notice ?? AuthAvailability.exception),
              ],
              const SizedBox(height: 18),
              _label(context, 'Email'),
              TextFormField(
                key: const Key('login_email'),
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: _validateEmail,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                style: _fieldStyle(context),
                decoration: _inputDecoration(
                  context,
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 14),
              _label(context, 'Password'),
              TextFormField(
                key: const Key('login_password'),
                controller: _passwordController,
                focusNode: _passwordFocus,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: [
                  _isCreatingAccount
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                validator: _validatePassword,
                onFieldSubmitted: (_) => _handleLogin(),
                style: _fieldStyle(context),
                decoration: _inputDecoration(
                  context,
                  hint: _isCreatingAccount
                      ? 'At least 8 characters'
                      : 'Your password',
                  icon: Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: context.appTextSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              if (!_isCreatingAccount)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
              AppButton.primary(
                label: _isCreatingAccount ? 'Create account' : 'Login',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleLogin,
              ),
              const SizedBox(height: 10),
              AppButton.outlined(
                label: 'Explore in Showcase Mode',
                icon: Icons.auto_awesome_rounded,
                onPressed: _isLoading ? null : _handleShowcaseMode,
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  key: const Key('toggle_mode'),
                  onPressed: _isLoading ? null : _toggleMode,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13),
                      children: [
                        TextSpan(
                          text: _isCreatingAccount
                              ? 'Already have an account? '
                              : 'New to Atlas? ',
                          style: TextStyle(color: context.appTextSecondary),
                        ),
                        TextSpan(
                          text: _isCreatingAccount ? 'Log In' : 'Sign Up',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _fieldStyle(BuildContext context) =>
      AppTheme.bodySm.copyWith(color: context.appTextPrimary, fontSize: 15);

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTheme.bodySm.copyWith(
        fontWeight: FontWeight.w600,
        color: context.appTextPrimary,
        fontSize: 13,
      ),
    ),
  );

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: color, width: width),
        );
    final subtle = context.appOutlineVariant.withValues(alpha: 0.4);
    final errorColor = Theme.of(context).colorScheme.error;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.bodySm.copyWith(
        color: context.appTextSecondary.withValues(alpha: 0.6),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: context.appTextSecondary, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: context.appSurfaceElevated,
      isDense: true,
      border: border(subtle),
      enabledBorder: border(subtle),
      disabledBorder: border(subtle),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(errorColor),
      focusedErrorBorder: border(errorColor, 1.5),
      errorStyle: TextStyle(color: errorColor, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

/// Inline banner for sign-in results: errors in red, "check your inbox" in
/// green.
class _AuthNotice extends StatelessWidget {
  final CloudAuthException notice;
  const _AuthNotice({required this.notice});

  @override
  Widget build(BuildContext context) {
    final isInfo = notice.isInfo;
    final color = isInfo
        ? AppColors.primary
        : Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('auth_notice'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isInfo
                  ? Icons.mark_email_read_outlined
                  : Icons.error_outline_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notice.message,
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextPrimary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
