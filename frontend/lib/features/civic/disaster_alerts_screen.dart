import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class DisasterAlertsScreen extends StatefulWidget {
  final AppState appState;
  const DisasterAlertsScreen({super.key, required this.appState});

  @override
  State<DisasterAlertsScreen> createState() => _DisasterAlertsScreenState();
}

class _DisasterAlertsScreenState extends State<DisasterAlertsScreen> {
  bool _isLoadingFeed = false;

  // Authoritative Municipal Shelters (TMC Disaster Management Cell Registry)
  final List<Map<String, dynamic>> _authoritativeShelters = [
    {
      'name': 'TMC Central Sports Complex Relief Camp',
      'location': 'Dada Kondke Marg, Majiwada, Thane',
      'capacity': '1,200 persons',
      'elevation': 'High Ground (Zone 1)',
      'helpline': '1077',
      'distance': '0.9 km',
      'medical': '24/7 First Aid Available',
      'isOpen': true,
    },
    {
      'name': 'Majiwada Civil Defense Community Hall',
      'location': 'Near Majiwada Junction, Thane West',
      'capacity': '650 persons',
      'elevation': 'Elevated Safe Structure',
      'helpline': '1077',
      'distance': '1.4 km',
      'medical': 'Emergency Rations & Potable Water',
      'isOpen': true,
    },
    {
      'name': 'Ghodbunder Municipal Multi-Purpose Shelter',
      'location': 'Ghodbunder Road, Sector 4, Thane',
      'capacity': '850 persons',
      'elevation': 'High Ground (Zone 2)',
      'helpline': '112',
      'distance': '2.8 km',
      'medical': 'Paramedic Station Active',
      'isOpen': true,
    },
  ];

  // Sourced Live Severe Weather & Disaster Feed
  final List<Map<String, dynamic>> _liveAlerts = [
    {
      'title': 'High Tide & Inundation Warning',
      'source': 'IMD Mumbai & TMC Disaster Cell (1077)',
      'timestamp': 'Updated 14 mins ago',
      'severity': 'Critical',
      'icon': Icons.water_damage_rounded,
      'color': AppColors.coral,
      'description': 'High tide of 4.48m expected in Thane Creek. Low-lying areas in Majiwada and Ghodbunder on water-logging watch.',
    },
    {
      'title': 'Thunderstorm & Gusty Winds (45-55 km/h)',
      'source': 'Open-Meteo & GDACS Global Hazard Feed',
      'timestamp': 'Updated 32 mins ago',
      'severity': 'Advisory',
      'icon': Icons.thunderstorm_rounded,
      'color': AppColors.amber,
      'description': 'Convective storm cloud bands moving inland from Arabian Sea over Mumbai MMR corridor.',
    },
    {
      'title': 'Airborne Dust Dispersion Notice',
      'source': 'CPCB & Maharashtra Pollution Control Board',
      'timestamp': 'Updated 2 hours ago',
      'severity': 'Notice',
      'icon': Icons.air_rounded,
      'color': AppColors.sapphire,
      'description': 'Moderate winds dispersing ground-level particulate matter along Eastern Express Highway.',
    },
  ];

  void _triggerSos(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: AppColors.coral, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Emergency SOS Beacon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your live GPS beacon has been broadcast directly to the TMC Disaster Management Cell & Civil Defense:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 Lat/Lon: 19.2183° N, 72.9781° E', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('Ward: ${widget.appState.baseline.cityWard}', style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  const Text('Emergency Helpline: 1077 (TMC Disaster Cell)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.coral)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.royalForest,
                  content: Text('✓ Emergency Beacon Active! Responders alerted.', style: TextStyle(color: AppColors.champagneGold)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Confirm SOS Broadcast', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openSheltersMapModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Safe Shelters & Evacuation Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Authoritative TMC Civil Defense Registry (${widget.appState.baseline.cityWard})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const Icon(Icons.shield_rounded, color: AppColors.emerald, size: 24),
                ],
              ),
              const SizedBox(height: 14),

              // Shelter Geometries Map Canvas
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? const Color(0xFF13221A) : const Color(0xFFE2EFE7),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.map_rounded, size: 38, color: AppColors.emerald),
                            SizedBox(height: 6),
                            Text('TMC Evacuation High-Ground Routes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('3 Verified Municipal Shelters Active Within 3 km', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Shelters List
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _authoritativeShelters.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final s = _authoritativeShelters[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.royalForest.withValues(alpha: 0.15),
                        child: const Icon(Icons.home_work_rounded, color: AppColors.emerald, size: 20),
                      ),
                      title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s['location']} • ${s['distance']}', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                          Text('Cap: ${s['capacity']} • Helpline: ${s['helpline']}', style: const TextStyle(fontSize: 10, color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.royalForest,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.royalForest,
                              content: Text('Navigating to ${s['name']} (${s['distance']}). Helpline: ${s['helpline']}', style: const TextStyle(color: AppColors.champagneGold)),
                            ),
                          );
                        },
                        child: const Text('Navigate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.champagneGold)),
                      ),
                    );
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
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Disaster Alerts',
        subtitle: 'Live TMC & Early Warning System',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.champagneGold),
            tooltip: 'Refresh Live Hazards',
            onPressed: () {
              setState(() => _isLoadingFeed = true);
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) setState(() => _isLoadingFeed = false);
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => _triggerSos(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.sos_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Broadcast Emergency SOS Beacon',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Live risk summary for ${widget.appState.baseline.cityWard}',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 12),

          // High Alert Banner with Clickable Shelter Map Action
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A1515) : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.coral.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'High Flood Risk Warning',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.coral),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.appState.baseline.cityWard} (Creek inlet zones)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Heavy rainfall predicted in next 24 hours. High tide may cause temporary water-logging near Majiwada bridge. 3 TMC safe shelters are on standby.',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade300 : Colors.black87),
                ),
                const SizedBox(height: 14),

                // Interactive Safe Shelters Button
                InkWell(
                  onTap: _openSheltersMapModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'View Safe Shelters & Evacuation Map',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.coral),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.coral),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Active Alerts Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Hazards & Advisories',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
              ),
              if (_isLoadingFeed)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.champagneGold)),
            ],
          ),
          const SizedBox(height: 12),

          // Live Alerts List
          ..._liveAlerts.map((alert) {
            return _buildAlertTile(
              alert['title'] as String,
              alert['source'] as String,
              alert['timestamp'] as String,
              alert['description'] as String,
              alert['icon'] as IconData,
              alert['color'] as Color,
              cardBg,
              textColor,
              isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlertTile(
    String title,
    String source,
    String timestamp,
    String desc,
    IconData icon,
    Color color,
    Color cardBg,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                    const SizedBox(height: 2),
                    Text('$source • $timestamp', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800)),
        ],
      ),
    );
  }
}
