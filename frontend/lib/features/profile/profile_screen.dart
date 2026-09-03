import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../state/app_state.dart';
import '../auth/login_screen.dart';
import '../onboarding/baseline_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppState appState;

  const ProfileScreen({super.key, required this.appState});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.champagneGold, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: oldPassController,
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
                    decoration: const InputDecoration(labelText: 'Current Password'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newPassController,
                    obscureText: true,
                    validator: Validators.validatePassword,
                    decoration: const InputDecoration(labelText: 'New Password (Min 8 Chars)'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmPassController,
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm new password';
                      if (v != newPassController.text) return 'Passwords do not match';
                      return null;
                    },
                    decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          widget.appState.changePassword(
                            currentPassword: oldPassController.text,
                            newPassword: newPassController.text,
                          );
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.royalForest,
                              content: Text(
                                '✓ Password updated successfully',
                                style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseline = widget.appState.baseline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: AppColors.champagneGold),
            onPressed: () {
              widget.appState.toggleTheme();
              setState(() {});
            },
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Avatar Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.royalForest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.goldBorder, width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.champagneGold, width: 2),
                        color: AppColors.deepForest,
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.champagneGold, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.appState.userName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.appState.userEmail,
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.champagneGold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Verified Eco Champion • Level 4',
                              style: TextStyle(fontSize: 11, color: AppColors.champagneGold, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Action Buttons: Update Profile & Change Password ─────────
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Update Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        // Opens the baseline setup screen pre-filled with the user's initial data!
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BaselineSetupScreen(
                              appState: widget.appState,
                              isInitialSetup: false,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: AppColors.champagneGold,
                        side: const BorderSide(color: AppColors.champagneGold, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                      label: const Text('Change Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      onPressed: _showChangePasswordDialog,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Baseline Configuration Summary
              Text(
                'Environmental Baseline Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Column(
                  children: [
                    _ProfileSummaryRow(label: 'Ward & City', value: baseline.cityWard),
                    const Divider(height: 18),
                    _ProfileSummaryRow(label: 'Primary Commute', value: '${baseline.primaryCommute} (${baseline.dailyCommuteKm} km/day)'),
                    const Divider(height: 18),
                    _ProfileSummaryRow(label: 'Dietary Preference', value: baseline.dietaryPreference),
                    const Divider(height: 18),
                    _ProfileSummaryRow(label: 'Monthly Electricity', value: '${baseline.monthlyElectricityKwh.round()} kWh'),
                    const Divider(height: 18),
                    _ProfileSummaryRow(label: 'Solar Installed', value: baseline.hasRooftopSolar ? 'Yes (Rooftop PV)' : 'No'),
                    const Divider(height: 18),
                    _ProfileSummaryRow(label: 'Primary Goal', value: baseline.primaryGoal),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Minted Achievement Badges Showcase
              Text(
                'Minted Achievement Crests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BadgeWidget(icon: Icons.park_rounded, name: 'Tree Saver', unlocked: true),
                  _BadgeWidget(icon: Icons.recycling_rounded, name: 'Recycler', unlocked: true),
                  _BadgeWidget(icon: Icons.local_fire_department_rounded, name: 'Streak Master', unlocked: true),
                  _BadgeWidget(icon: Icons.air_rounded, name: 'Air Guardian', unlocked: false),
                ],
              ),

              const SizedBox(height: 36),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.coral),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out of Grevidea', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    widget.appState.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => LoginScreen(appState: widget.appState)),
                      (route) => false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileSummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _BadgeWidget extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool unlocked;

  const _BadgeWidget({required this.icon, required this.name, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked ? AppColors.royalForest : Colors.grey.withOpacity(0.15),
            border: Border.all(
              color: unlocked ? AppColors.champagneGold : Colors.grey.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: unlocked ? AppColors.champagneGold : Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: unlocked ? FontWeight.w700 : FontWeight.w500,
            color: unlocked ? AppColors.champagneGold : Colors.grey,
          ),
        ),
      ],
    );
  }
}
