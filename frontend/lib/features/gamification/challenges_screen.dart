import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class ChallengesScreen extends StatefulWidget {
  final AppState appState;
  const ChallengesScreen({super.key, required this.appState});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    final list = await widget.appState.api.getDailyChallenges();
    if (mounted) {
      setState(() {
        _challenges = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.inkOf(context);

    final filtered = _challenges.where((c) {
      final matchesFilter =
          _selectedFilter == 'All' || c['difficulty'] == _selectedFilter;
      final query = _searchController.text.toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          (c['title'] as String).toLowerCase().contains(query) ||
          (c['description'] as String).toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Explore Challenges',
        subtitle: 'Habit Formation & Gamified Quests',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Column(
        children: [
          // Search Field (Matching Screen 16)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search challenges...',
                prefixIcon:  Icon(
                  Icons.search_rounded,
                  color: AppColors.mutedOf(context),
                ),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder,
                  ),
                ),
              ),
            ),
          ),

          // Filter Pills (All / Easy / Medium / Hard) (Matching Screen 16)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: ['All', 'Easy', 'Medium', 'Hard'].map((diff) {
                final isSel = _selectedFilter == diff;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      diff,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSel ? AppColors.accentOf(context) : null,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: AppColors.royalForest,
                    backgroundColor: cardBg,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = diff);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Challenges List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentOf(context),
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 56,
                          color: AppColors.mutedOf(context).withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No challenges added yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Official civic and community eco-challenges for ${widget.appState.baseline.cityWard} will appear here.',
                            textAlign: TextAlign.center,
                            style:  TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isCompleted = item['completed'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted
                                ? AppColors.leafOf(context)
                                : (isDark
                                      ? AppColors.darkCardBorder
                                      : AppColors.lightCardBorder),
                            width: isCompleted ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.royalForest.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.task_alt_rounded,
                                color: isCompleted
                                    ? AppColors.leafOf(context)
                                    : AppColors.accentOf(context),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item['description'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.mutedOf(context),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                       Icon(
                                        Icons.timer_outlined,
                                        size: 12,
                                        color: AppColors.mutedOf(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${item['days_left']} days left',
                                        style:  TextStyle(
                                          fontSize: 10,
                                          color: AppColors.mutedOf(context),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        item['difficulty'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: item['difficulty'] == 'Easy'
                                              ? AppColors.leafOf(context)
                                              : AppColors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.royalForest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.champagneGold.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '+${item['points']} pts',
                                    style: const TextStyle(
                                      color: AppColors.champagneGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: isCompleted
                                      ? null
                                      : () {
                                          setState(
                                            () => item['completed'] = true,
                                          );
                                          widget.appState.acceptChallenge(
                                            bonusPoints: item['points'] as int,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              backgroundColor:
                                                  AppColors.royalForest,
                                              content: Text(
                                                '✓ Completed "${item['title']}"! +${item['points']} points claimed.',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.champagneGold,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide(
                                      color: isCompleted
                                          ? AppColors.mutedOf(context)
                                          : AppColors.leafOf(context),
                                    ),
                                  ),
                                  child: Text(
                                    isCompleted ? 'Done' : 'Claim',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted
                                          ? AppColors.mutedOf(context)
                                          : AppColors.leafOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
