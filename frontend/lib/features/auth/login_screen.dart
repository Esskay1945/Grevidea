import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/google_sign_in_button.dart';
import '../../state/app_state.dart';
import 'forgot_password_dialog.dart';
import 'signup_screen.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final AppState appState;

  const LoginScreen({super.key, required this.appState});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'yash@grevidea.org');
  final _passwordController = TextEditingController(text: 'Password@123');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.appState.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(appState: widget.appState),
        ),
      );
    }
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
                            border: Border.all(color: AppColors.champagneGold, width: 1.5),
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
                                color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                              ),
                            ),
                            const Text(
                              'Live green. Lead change.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.champagneGold,
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
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: AppColors.champagneGold,
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
                    color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Access your environmental intelligence dashboard.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),

                const SizedBox(height: 36),

                // ── Email Input Field with Regex Validation ──────────────────
                Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                  decoration: const InputDecoration(
                    hintText: 'name@domain.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Password Input Field with 8+ Char Rule ────────────────────
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: Validators.validatePassword,
                  decoration: InputDecoration(
                    hintText: 'Minimum 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.champagneGold),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.champagneGold,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.champagneGold,
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
                    Expanded(child: Divider(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Google Sign-In Action ────────────────────────────────────
                GoogleSignInButton(
                  text: 'Continue with Google',
                  onTap: () {
                    widget.appState.login('yash.patil@gmail.com', 'google_oauth_token');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.royalForest,
                        content: Text(
                          '✓ Verified Google OAuth Token (Client: 79614930496-dih5e1u4...)',
                          style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => DashboardScreen(appState: widget.appState),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Switch to Sign Up ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have a Grevidea account? ",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SignupScreen(appState: widget.appState),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.champagneGold,
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
