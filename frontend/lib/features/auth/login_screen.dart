import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/google_sign_in_button.dart';
import '../../state/app_state.dart';
import 'forgot_password_dialog.dart';
import 'signup_screen.dart';
import '../onboarding/baseline_setup_screen.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final AppState appState;

  const LoginScreen({super.key, required this.appState});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateAfterAuth(BuildContext context) {
    if (widget.appState.hasCompletedOnboarding) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/dashboard'),
          builder: (_) => DashboardScreen(appState: widget.appState),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BaselineSetupScreen(
            appState: widget.appState,
            isInitialSetup: true,
          ),
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_googleBusy || widget.appState.authBusy) return;
    if (_formKey.currentState?.validate() ?? false) {
      final success = await widget.appState.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (success) {
        _navigateAfterAuth(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.coral,
            content: Text(
              'Invalid password. Please check your credentials or try again.',
            ),
          ),
        );
      }
    }
  }

  bool _googleBusy = false;
  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (_googleBusy || widget.appState.authBusy) return;
    setState(() => _googleBusy = true);
    try {
      final success = await widget.appState.loginLocallyWithGoogle(email: _emailController.text.trim());
      if (!mounted) return;
      if (success) _navigateAfterAuth(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the local profile. Please try again.')));
    } finally { if (mounted) setState(() => _googleBusy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // ── Top Navigation Row: Logo on Left, Theme Toggle on Right ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Left Logo & Crest
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.royalForest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.champagneGold,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: AppColors.champagneGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grevidea',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.inkOf(context),
                              ),
                            ),
                            Text(
                              'Live green. Lead change.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.accentOf(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Top Right Theme Switcher Converter
                    IconButton(
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: AppColors.accentOf(context),
                        size: 26,
                      ),
                      tooltip: 'Toggle Light / Dark Mode',
                      onPressed: () {
                        widget.appState.toggleTheme();
                        setState(() {});
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // ── Welcome Heading ──────────────────────────────────────────
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.inkOf(context),
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Access your environmental intelligence dashboard.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.mutedOf(context),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Email Input Field with Regex Validation ──────────────────
                Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.inkOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                  decoration: InputDecoration(
                    hintText: 'e.g. xyz@gmail.com',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Password Input Field with 8+ Char Rule ────────────────────
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.inkOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: Validators.validatePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password (min 8 characters)',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.accentOf(context),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.accentOf(context),
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                // ── Forgot Password Action ───────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ForgotPasswordDialog(),
                      );
                    },
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.accentOf(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Login Button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── OR Divider ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.mutedOf(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Google Sign-In Action ────────────────────────────────────
                GoogleSignInButton(
                  text: 'Continue with Google',
                  onTap: () => _handleGoogleSignIn(context),
                ),

                const SizedBox(height: 24),

                // ── Switch to Sign Up ────────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Don't have a Grevidea account? ",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.mutedOf(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SignupScreen(appState: widget.appState),
                          ),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
