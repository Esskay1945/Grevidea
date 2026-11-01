import 'package:flutter/material.dart';
import '../../core/services/google_identity_service.dart';
import '../../core/widgets/connection_settings_dialog.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/google_sign_in_button.dart';
import '../../state/app_state.dart';
import '../onboarding/baseline_setup_screen.dart';
import '../dashboard/dashboard_screen.dart';
import 'widgets/password_strength_bar.dart';

class SignupScreen extends StatefulWidget {
  final AppState appState;

  const SignupScreen({super.key, required this.appState});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  PasswordStrength _passwordStrength = PasswordStrength.none;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordStrength = Validators.calculatePasswordStrength(value);
    });
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

  Future<void> _handleSignup() async {
    if (_googleBusy || widget.appState.authBusy) return;
    if (_formKey.currentState?.validate() ?? false) {
      final success = await widget.appState.signup(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      if (success) { _navigateAfterAuth(context); } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.appState.authError ?? 'Registration failed')));
      }
    }
  }

  bool _googleBusy = false;
  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (_googleBusy || widget.appState.authBusy) return;
    setState(() => _googleBusy = true);
    try {
      final clientId = await widget.appState.api.fetchGoogleClientId();
      if (!mounted) return;
      if (clientId == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.appState.api.authFailure ?? 'Google configuration unavailable.'))); return; }
      final token = await GoogleIdentityService.acquireIdToken(serverClientId: clientId);
      if (!mounted || token == null) return;
      final success = await widget.appState.loginWithGoogle(token);
      if (!mounted) return;
      if (success) { _navigateAfterAuth(context); }
      else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.appState.authError ?? 'Google sign-in failed.'))); }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-in could not complete. Check this build’s OAuth configuration and try again.')));
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
                Align(alignment: Alignment.centerRight, child: TextButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => ConnectionSettingsDialog(appState: widget.appState)),
                  icon: const Icon(Icons.settings_ethernet, size: 18), label: const Text('Connection settings'))),
                const SizedBox(height: 12),
                // ── Top Bar: Logo & Theme Switcher ───────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    IconButton(
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: AppColors.accentOf(context),
                        size: 26,
                      ),
                      onPressed: () {
                        widget.appState.toggleTheme();
                        setState(() {});
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                Text(
                  'Join Grevidea',
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
                  'Create your account to initiate personal environmental intelligence.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.mutedOf(context),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Full Name ────────────────────────────────────────────────
                Text(
                  'Full Name',
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
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. John Doe',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Email Address ────────────────────────────────────────────
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

                const SizedBox(height: 18),

                // ── Password with Easy/Medium/Difficult Strength Bar ─────────
                Text(
                  'Password (Min 8 Characters)',
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
                  onChanged: _onPasswordChanged,
                  validator: Validators.validatePassword,
                  decoration: InputDecoration(
                    hintText: 'Create a password (min 8 characters)',
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

                // Dynamic Strength Meter
                PasswordStrengthBar(strength: _passwordStrength),

                const SizedBox(height: 14),

                // ── Confirm Password ─────────────────────────────────────────
                Text(
                  'Confirm Password',
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
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'Please confirm password';
                    if (val != _passwordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Re-enter your password to confirm',
                    prefixIcon: Icon(
                      Icons.lock_clock_outlined,
                      color: AppColors.accentOf(context),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.accentOf(context),
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Register Button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleSignup,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue to Setup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

                // ── Google Sign-Up Action ────────────────────────────────────
                GoogleSignInButton(
                  text: 'Sign up with Google',
                  onTap: () => _handleGoogleSignIn(context),
                ),

                const SizedBox(height: 24),

                // ── Already Have Account ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already registered? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.mutedOf(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Sign In',
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
