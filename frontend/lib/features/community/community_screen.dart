import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class CommunityScreen extends StatefulWidget {
  final AppState appState;
  const CommunityScreen({super.key, required this.appState});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingFeed = false;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDynamicFeed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicFeed() async {
    setState(() => _isLoadingFeed = true);
    try {
      final backendPosts = await widget.appState.api.getFeed(page: 1, limit: 30);
      if (mounted) {
        setState(() {
          _posts.clear();
          if (backendPosts.isNotEmpty) {
            for (final p in backendPosts) {
              final authorName = p['display_name']?.toString() ?? 'Citizen';
              _posts.add({
                'author': authorName,
                'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'C',
                'time': p['created_at'] != null ? 'Recently' : 'Live',
                'location': widget.appState.baseline.cityWard,
                'text': p['description']?.toString() ?? 'Engaged in sustainable community climate action.',
                'tag': p['action_type']?.toString() ?? 'Eco Action',
                'likes': p['likes'] is int ? p['likes'] : int.tryParse(p['likes']?.toString() ?? '12') ?? 12,
                'comments': 2,
                'isLiked': false,
                'imageColor': AppColors.royalForest,
                'imageIcon': Icons.eco_rounded,
              });
            }
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingFeed = false);
  }

  void _openCreatePostDialog() {
    final textController = TextEditingController();
    String selectedTag = 'Tree Planting';
    String? attachedPhotoName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Share Eco Action', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your sustainable deed or progress...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['Tree Planting', 'Green Commute', 'Zero Waste', 'Solar Energy'].map((t) {
                      final isSel = selectedTag == t;
                      return ChoiceChip(
                        label: Text(t, style: TextStyle(fontSize: 11, color: isSel ? AppColors.champagneGold : null)),
                        selected: isSel,
                        selectedColor: AppColors.royalForest,
                        onSelected: (_) => setDialogState(() => selectedTag = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  if (attachedPhotoName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('Photo attached: $attachedPhotoName', style: const TextStyle(fontSize: 12, color: AppColors.emerald), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final XFile? file = await _picker.pickImage(source: ImageSource.camera);
                          if (file != null) {
                            setDialogState(() {
                              attachedPhotoName = file.name;
                            });
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalForest),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
                          if (file != null) {
                            setDialogState(() {
                              attachedPhotoName = file.name;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Gallery'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isNotEmpty) {
                            setState(() {
                              _posts.insert(0, {
                                'author': '${widget.appState.userName} (You)',
                                'avatar': widget.appState.userName.isNotEmpty ? widget.appState.userName[0].toUpperCase() : 'U',
                                'time': 'Just now',
                                'location': widget.appState.baseline.cityWard,
                                'text': text,
                                'tag': selectedTag,
                                'likes': 1,
                                'comments': 0,
                                'isLiked': true,
                                'imageColor': AppColors.royalForest,
                                'imageIcon': Icons.eco_rounded,
                              });
                            });

                            // Post directly to live backend
                            await widget.appState.api.createPost(
                              actionType: selectedTag,
                              description: text,
                              co2SavedKg: 2.1,
                            );

                            widget.appState.logActivity(
                              title: 'Shared Eco Post',
                              category: 'Community',
                              subtitle: text,
                              co2Kg: -0.2,
                              icon: Icons.people_rounded,
                              pointsEarned: 25,
                            );
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.champagneGold),
                        child: const Text('Post (+25 pts)', style: TextStyle(color: AppColors.royalForest, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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
        title: 'Community',
        subtitle: 'Social Proof & Collective Action',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.royalForest,
        onPressed: _openCreatePostDialog,
        child: const Icon(Icons.add_rounded, color: AppColors.champagneGold, size: 28),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.royalForest,
                borderRadius: BorderRadius.circular(16),
              ),
              labelColor: AppColors.champagneGold,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Feed'),
                Tab(text: 'Challenges'),
                Tab(text: 'Local Groups'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Live Community Feed Tab with Pull-To-Refresh
                RefreshIndicator(
                  color: AppColors.champagneGold,
                  backgroundColor: AppColors.royalForest,
                  onRefresh: _loadDynamicFeed,
                  child: _isLoadingFeed && _posts.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppColors.champagneGold))
                      : _posts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                const Icon(Icons.forum_outlined, size: 60, color: Colors.grey),
                                const SizedBox(height: 12),
                                Center(child: Text('Community Feed is Ready', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))),
                                const SizedBox(height: 6),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                    child: Text(
                                      'Be the first to share an eco-deed in ${widget.appState.baseline.cityWard}! Tap the + button to share.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _posts.length,
                              itemBuilder: (ctx, i) {
                            final post = _posts[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.royalForest,
                                        child: Text(
                                          post['avatar'],
                                          style: const TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(post['author'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                            Text('${post['time']} • ${post['location']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.royalForest.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          post['tag'],
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    post['text'],
                                    style: TextStyle(fontSize: 13, height: 1.4, color: textColor),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            post['isLiked'] = !post['isLiked'];
                                            post['likes'] += post['isLiked'] ? 1 : -1;
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            Icon(
                                              post['isLiked'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              size: 18,
                                              color: post['isLiked'] ? AppColors.coral : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text('${post['likes']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('${post['comments']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const Spacer(),
                                      const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Challenges Tab (Clean Ghost State - Zero Fake Data)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 54, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 14),
                        Text(
                          'No challenges added yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Community eco-challenges for ${widget.appState.baseline.cityWard} will appear here.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                // Local Groups Tab (Clean Ghost State - Zero Fake Data)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined, size: 54, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 14),
                        Text(
                          'No local groups in your ward yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Be the first to create an Eco Squad in ${widget.appState.baseline.cityWard}!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
