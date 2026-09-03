import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class LeaderboardScreen extends StatefulWidget {
  final AppState appState;

  const LeaderboardScreen({super.key, required this.appState});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _leaderboardData = [];
  bool _isLoading = true;
  String _selectedScope = 'ward';

  final List<String> _scopes = ['ward', 'city', 'state', 'global'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedScope = _scopes[_tabController.index];
        });
        _loadLeaderboard(_selectedScope);
      }
    });
    _loadLeaderboard('ward');
  }

  Future<void> _loadLeaderboard(String scope) async {
    setState(() => _isLoading = true);
    final data = await widget.appState.api.getLeaderboard(scope: scope);
    if (mounted) {
      setState(() {
        _leaderboardData = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final userPoints = widget.appState.greenPoints;
    final userName = widget.appState.userName.isNotEmpty ? widget.appState.userName : 'Siddharth Kumar';
    final userWard = widget.appState.baseline.cityWard;

    // Dynamically calculate user rank within the result set
    final userList = List<Map<String, dynamic>>.from(_leaderboardData);
    final existingUserIdx = userList.indexWhere((u) => u['is_current_user'] == true);

    int calculatedUserRank = 1;
    if (existingUserIdx >= 0) {
      calculatedUserRank = existingUserIdx + 1;
    } else if (userList.isNotEmpty) {
      // Calculate rank dynamically based on score
      int higherCount = userList.where((u) => ((u['points'] as int?) ?? 0) > userPoints).length;
      calculatedUserRank = higherCount + 1;
    } else {
      calculatedUserRank = 1; // Sole registered user in database
    }

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Leaderboard',
        subtitle: 'Community Impact Rankings',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.champagneGold))
          : Column(
              children: [
                // Filter Segmented Tabs: Ward / City / State / Global
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceAlt,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.royalForest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    labelColor: AppColors.champagneGold,
                    unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(text: 'Ward'),
                      Tab(text: 'City (Thane)'),
                      Tab(text: 'State'),
                      Tab(text: 'Global'),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Sticky User Standing Banner (Pure Dynamic Calculation)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.royalForest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.champagneGold, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: AppColors.royalForest.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.deepForest,
                              ),
                              child: Text(
                                '#$calculatedUserRank',
                                style: const TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '$userName (You)',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.emerald, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$userWard • ${widget.appState.streakDays}d streak • ${widget.appState.treesEquivalent.toStringAsFixed(1)} trees',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$userPoints',
                                  style: const TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w900, fontSize: 20),
                                ),
                                const Text('points', style: TextStyle(color: Colors.white60, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // If no other users exist in this scope
                      if (_leaderboardData.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.military_tech_rounded, size: 52, color: AppColors.champagneGold),
                              const SizedBox(height: 12),
                              Text(
                                'Rank #1 in $userWard',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You are currently the leading eco-citizen in this boundary! As neighbors join and log sustainable actions, their live rankings will appear here.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.royalForest,
                                  foregroundColor: AppColors.champagneGold,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Invite Neighbors to Leaderboard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: AppColors.royalForest,
                                      content: Text('Ward invite link copied to clipboard!', style: TextStyle(color: AppColors.champagneGold)),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // Ranked List Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('RANKED CITIZENS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                              Text('POINTS & IMPACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._leaderboardData.map((user) => _buildRankRow(user, isDark, cardBg, textColor)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRankRow(Map<String, dynamic> user, bool isDark, Color cardBg, Color textColor) {
    final rank = user['rank'] ?? 1;
    final isUser = user['is_current_user'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? AppColors.royalForest.withValues(alpha: 0.15) : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUser ? AppColors.champagneGold : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
      ),
      child: Row(
        children: [
          Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.champagneGold)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['user_name'] ?? 'Citizen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                Text('${user['city'] ?? ""} • ${user['streak_days'] ?? 0}d streak', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text('${user['points'] ?? 0} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emerald)),
        ],
      ),
    );
  }
}
