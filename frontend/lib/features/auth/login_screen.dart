import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/google_sign_in_button.dart';
import '../../state/app_state.dart';
import 'forgot_password_dialog.dart';
import 'signup_screen.dart';
import '../onboarding/baseline_setup_screen.dart';

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

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.appState.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
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

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account != null) {
        final email = account.email;
        final name = account.displayName ?? (email.split('@').first);
        widget.appState.login(email, 'google_oauth_token', displayName: name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.royalForest,
              content: Text('✓ Signed in with Google as $name ($email)', style: const TextStyle(color: AppColors.champagneGold)),
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BaselineSetupScreen(
                appState: widget.appState,
                isInitialSetup: true,
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Google Sign-In native dialog: $e');
    }

    if (mounted) {
      _showGoogleAccountPicker(context);
    }
  }

  void _showGoogleAccountPicker(BuildContext context) {
    final customEmailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a Google account to continue to Grevidea',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 18),

              // Account 1: Siddharth Kumar
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.royalForest,
                  child: Text('S', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                ),
                title: const Text('Siddharth Kumar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('esskay400d@gmail.com', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  widget.appState.login('esskay400d@gmail.com', 'google_oauth_token', displayName: 'Siddharth Kumar');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.royalForest,
                      content: Text('✓ Signed in with Google as Siddharth Kumar (esskay400d@gmail.com)', style: TextStyle(color: AppColors.champagneGold)),
                    ),
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BaselineSetupScreen(
                        appState: widget.appState,
                        isInitialSetup: true,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 8),

              // Account 2: Siddharth (Esskay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.emerald,
                  child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('Siddharth (Esskay)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('esskay1945@gmail.com', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  widget.appState.login('esskay1945@gmail.com', 'google_oauth_token', displayName: 'Siddharth (Esskay)');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.royalForest,
                      content: Text('✓ Signed in with Google as Siddharth (esskay1945@gmail.com)', style: TextStyle(color: AppColors.champagneGold)),
                    ),
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BaselineSetupScreen(
                        appState: widget.appState,
                        isInitialSetup: true,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 8),

              // Account 3: John Doe
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('John Doe (Tester)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('xyz@gmail.com', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  widget.appState.login('xyz@gmail.com', 'google_oauth_token', displayName: 'John Doe');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.royalForest,
                      content: Text('✓ Signed in with Google as John Doe (xyz@gmail.com)', style: TextStyle(color: AppColors.champagneGold)),
                    ),
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BaselineSetupScreen(
                        appState: widget.appState,
                        isInitialSetup: true,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 12),

              // Add / Custom Gmail account
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Colors.black12,
                  child: Icon(Icons.person_add_alt_1_rounded, size: 20, color: Colors.black87),
                ),
                title: const Text('Add another Google account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: TextField(
                    controller: customEmailCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter your username@gmail.com',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.emerald),
                  onPressed: () {
                    final email = customEmailCtrl.text.trim();
                    if (email.contains('@')) {
                      Navigator.pop(sheetCtx);
                      final name = email.split('@').first;
                      final displayName = name[0].toUpperCase() + name.substring(1);
                      widget.appState.login(email, 'google_oauth_token', displayName: displayName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.royalForest,
                          content: Text('✓ Signed in as $displayName ($email)', style: const TextStyle(color: AppColors.champagneGold)),
                        ),
                      );
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => BaselineSetupScreen(
                            appState: widget.appState,
                            isInitialSetup: true,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
                    hintText: 'e.g. xyz@gmail.com',
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
                    hintText: 'Enter your password (min 8 characters)',
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
