import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';
import '../onboarding/baseline_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;
  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local toggles for settings preferences
  bool _pushNotifications = true;
  bool _dailyQuestReminders = true;
  bool _aqiAlerts = true;
  bool _civicDispatchUpdates = true;
  bool _speedTransitPrompts = true;

  bool _biometricAuth = false;
  bool _locationTracking = true;
  bool _anonymizeReports = false;

  bool _googleFitConnected = false;
  bool _googleHomeConnected = false;
  int _syncedSteps = 0;

  void _showNotificationPreferences(BuildContext context, bool isDark, Color cardBg, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.champagneGold, size: 24),
                  const SizedBox(width: 10),
                  Text('Notification Preferences', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Manage real-time notifications, severe weather, and municipal dispatches.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Device status bar alerts for urgent eco events', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _pushNotifications,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _pushNotifications = val);
                  setState(() => _pushNotifications = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Daily Eco-Quest Reminders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Morning prompts with your 3 assigned daily quests', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _dailyQuestReminders,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _dailyQuestReminders = val);
                  setState(() => _dailyQuestReminders = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Severe Hyperlocal AQI Warnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Immediate alert when PM2.5 crosses Hazardous in your ward', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _aqiAlerts,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _aqiAlerts = val);
                  setState(() => _aqiAlerts = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Municipal Grievance Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Dispatches, clean-up SLA milestones and resolution notices', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _civicDispatchUpdates,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _civicDispatchUpdates = val);
                  setState(() => _civicDispatchUpdates = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('In-Transit Speed Prompts (>25 km/h)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Ask vehicle mode during high-speed travel to log emissions accurately', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _speedTransitPrompts,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _speedTransitPrompts = val);
                  setState(() => _speedTransitPrompts = val);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalForest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save Preferences', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacySecurity(BuildContext context, bool isDark, Color cardBg, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security_rounded, color: AppColors.emerald, size: 24),
                  const SizedBox(width: 10),
                  Text('Privacy & Security', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Manage device permissions, differential privacy, and stored sessions.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Biometric Fingerprint / Face Unlock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Require biometric prompt when launching Grevidea', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _biometricAuth,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _biometricAuth = val);
                  setState(() => _biometricAuth = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('High-Accuracy GPS Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Required for real-time AQI station matching and speed detection', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _locationTracking,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _locationTracking = val);
                  setState(() => _locationTracking = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Anonymize Civic Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                subtitle: const Text('Hide your name when sending waste & pollution tickets to TMC', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _anonymizeReports,
                activeColor: AppColors.champagneGold,
                activeTrackColor: AppColors.royalForest,
                onChanged: (val) {
                  setModalState(() => _anonymizeReports = val);
                  setState(() => _anonymizeReports = val);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.royalForest,
                      content: Text('✓ Local cache and offline tile data cleared successfully.', style: TextStyle(color: AppColors.champagneGold)),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 18),
                label: const Text('Clear Local Cache & Offline Data', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.coral),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalForest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConnectedApps(BuildContext context, bool isDark, Color cardBg, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.apps_rounded, color: AppColors.champagneGold, size: 24),
                  const SizedBox(width: 10),
                  Text('Connected Apps & Hardware', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Sync physical steps, smart home devices, and fitness sensors to automatically earn green points.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 18),

              // Google Fit / Health Connect
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: const Icon(Icons.directions_walk_rounded, color: Colors.blueAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Google Fit / Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            _googleFitConnected
                                ? '✓ Synced: $_syncedSteps steps today (+1.2 kg CO₂ saved)'
                                : 'Sync walking steps to earn green points automatically',
                            style: TextStyle(fontSize: 11, color: _googleFitConnected ? AppColors.emerald : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          _googleFitConnected = !_googleFitConnected;
                          if (_googleFitConnected) {
                            _syncedSteps = 7840;
                            widget.appState.logActivity(
                              title: '7,840 Walking Steps Synced',
                              category: 'Transport',
                              subtitle: 'Synced via Google Fit • Zero emissions commute',
                              co2Kg: -1.2,
                              icon: Icons.directions_walk_rounded,
                              pointsEarned: 35,
                            );
                          } else {
                            _syncedSteps = 0;
                          }
                        });
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _googleFitConnected ? AppColors.emerald : AppColors.royalForest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: Text(
                        _googleFitConnected ? 'Connected' : 'Connect',
                        style: TextStyle(fontSize: 11, color: _googleFitConnected ? Colors.white : AppColors.champagneGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Google Home / Smart Inverter
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: const Icon(Icons.home_rounded, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Google Home / Smart Meter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            _googleHomeConnected
                                ? '✓ Connected: Live MSEDCL Grid Net-Metering'
                                : 'Connect smart inverter to log clean energy generation',
                            style: TextStyle(fontSize: 11, color: _googleHomeConnected ? AppColors.emerald : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          _googleHomeConnected = !_googleHomeConnected;
                        });
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _googleHomeConnected ? AppColors.emerald : AppColors.royalForest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: Text(
                        _googleHomeConnected ? 'Linked' : 'Link',
                        style: TextStyle(fontSize: 11, color: _googleHomeConnected ? Colors.white : AppColors.champagneGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalForest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnitsModal(BuildContext context, bool isDark, Color cardBg, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten_rounded, color: AppColors.champagneGold, size: 24),
                  const SizedBox(width: 10),
                  Text('Unit System', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Select your preferred units of measurement for carbon, distance, and temperature.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.champagneGold,
                title: Text('Metric System (Recommended)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                subtitle: const Text('Kilograms of CO₂ (kg), Kilometers (km), Celsius (°C)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: true,
                groupValue: widget.appState.useMetricUnits,
                onChanged: (val) {
                  if (val != null) {
                    widget.appState.setUseMetricUnits(val);
                    setModalState(() {});
                    setState(() {});
                  }
                },
              ),
              const Divider(height: 12),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.champagneGold,
                title: Text('Imperial System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                subtitle: const Text('Pounds of CO₂ (lbs), Miles (mi), Fahrenheit (°F)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: false,
                groupValue: widget.appState.useMetricUnits,
                onChanged: (val) {
                  if (val != null) {
                    widget.appState.setUseMetricUnits(val);
                    setModalState(() {});
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalForest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply Units', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.royalForest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.champagneGold, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('About Grevidea', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Grevidea is an AI-powered ecological operating system that translates everyday citizen and civic choices into verified, measurable planetary impact.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            SizedBox(height: 12),
            Text(
              'Key Capabilities:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.champagneGold),
            ),
            SizedBox(height: 6),
            Text('• Hyperlocal AQI & street-level pollution monitoring across MMR and Indian wards', style: TextStyle(fontSize: 12, height: 1.35)),
            Text('• Statutory civic grievance reporting connected to TMC SWMD & MPCB', style: TextStyle(fontSize: 12, height: 1.35)),
            Text('• Multi-modal green commute carbon audits (Metro, Bus, EV, Cycling)', style: TextStyle(fontSize: 12, height: 1.35)),
            Text('• Circular economy rewards, verified tree stewardship & eco-merchandise', style: TextStyle(fontSize: 12, height: 1.35)),
            SizedBox(height: 12),
            Text(
              'Version 1.0.0 (Production Release) • Build 58\nBuilt with CPCB Open Data, TMC Citizen Governance & Google Cloud AI.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalForest),
            child: const Text('Close', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String get syncedStepsLabel => _syncedSteps > 0 ? '$_syncedSteps steps' : 'Linked';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Settings',
        subtitle: 'Preferences & System Controls',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Banner Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.royalForest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.champagneGold, width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.deepForest,
                  child: Text(
                    widget.appState.userName.isNotEmpty ? widget.appState.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.champagneGold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.appState.userName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.appState.userEmail,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Location: ${widget.appState.baseline.cityWard}',
                        style: const TextStyle(fontSize: 11, color: AppColors.champagneGold, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account & Preferences
          _buildSectionTitle('ACCOUNT & PREFERENCES'),
          _buildSettingTile(
            icon: Icons.person_outline_rounded,
            title: 'Personal Information & Baseline',
            subtitle: 'Dwelling, daily commute km, dietary profile',
            textColor: textColor,
            cardBg: cardBg,
            isDark: isDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BaselineSetupScreen(appState: widget.appState)),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notification Preferences',
            subtitle: 'AQI warnings, daily quests, TMC dispatch alerts',
            textColor: textColor,
            cardBg: cardBg,
            isDark: isDark,
            onTap: () => _showNotificationPreferences(context, isDark, cardBg, textColor),
          ),
          _buildSettingTile(
            icon: Icons.security_rounded,
            title: 'Privacy & Security',
            subtitle: 'Biometric lock, location tracking, clear cache',
            textColor: textColor,
            cardBg: cardBg,
            isDark: isDark,
            onTap: () => _showPrivacySecurity(context, isDark, cardBg, textColor),
          ),
          _buildSettingTile(
            icon: Icons.apps_rounded,
            title: 'Connected Apps & Hardware',
            subtitle: _googleFitConnected ? '✓ Google Fit synced ($syncedStepsLabel)' : 'Google Fit, Health Connect, Google Home',
            textColor: textColor,
            cardBg: cardBg,
            isDark: isDark,
            onTap: () => _showConnectedApps(context, isDark, cardBg, textColor),
          ),
          _buildSettingTile(
            icon: Icons.straighten_rounded,
            title: 'Units',
            subtitle: widget.appState.useMetricUnits ? 'Metric: kg CO₂, km, °C' : 'Imperial: lbs CO₂, mi, °F',
            trailing: Text(widget.appState.useMetricUnits ? 'Metric' : 'Imperial', style: const TextStyle(color: AppColors.champagneGold, fontSize: 13, fontWeight: FontWeight.bold)),
            textColor: textColor,
            cardBg: cardBg,
            isDark: isDark,
            onTap: () => _showUnitsModal(context, isDark, cardBg, textColor),
          ),

          const SizedBox(height: 16),
          _buildSectionTitle('APPEARANCE'),

          // Dark Mode Toggle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.dark_mode_outlined, color: AppColors.champagneGold, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                      Text(
                        isDark ? 'Velvet Forest Obsidian' : 'Crisp Warm Ivory',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widget.appState.isDarkMode,
                  activeThumbColor: AppColors.champagneGold,
                  activeTrackColor: AppColors.royalForest,
                  onChanged: (val) => widget.appState.toggleTheme(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _buildSectionTitle('ABOUT'),
          _buildSettingTile(
            icon: Icons.info_outline_rounded,
            title: 'About Grevidea',
            subtitle: 'v1.0.0 (Build 58) • Live green. Lead change.',
            textColor: textColor,
            cardBg: cardBg,
            isDark: isDark,
            onTap: () => _showAboutDialog(context, isDark),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.champagneGold,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required Color textColor,
    required Color cardBg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.royalForest.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.champagneGold, size: 20),
        ),
        title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
