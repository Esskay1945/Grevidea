import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class QuizHistoryEntry {
  final DateTime date;
  final String theme;
  final int correctCount;
  final int totalQuestions;
  final int pointsEarned;

  QuizHistoryEntry({
    required this.date,
    required this.theme,
    required this.correctCount,
    required this.totalQuestions,
    required this.pointsEarned,
  });
}

class LearningScreen extends StatefulWidget {
  final AppState appState;
  const LearningScreen({super.key, required this.appState});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  String _selectedTheme = 'Urban Heat Islands & Hyperlocal AQI';

  final List<String> _themes = [
    'Urban Heat Islands & Hyperlocal AQI',
    'Mangrove Wetlands & Blue Carbon',
    'Rooftop Solar PV & Clean Grid',
    'Circular Economy & Zero Waste',
    'Biodiversity & Western Ghats Ecology',
  ];

  final Map<String, List<Map<String, dynamic>>> _questionBank = {
    'Urban Heat Islands & Hyperlocal AQI': [
      {
        'q': 'Which surface has the highest albedo, helping mitigate urban heat island effect in Thane?',
        'options': ['Black asphalt roads', 'Cool white reflective rooftop coatings', 'Dark concrete pavement', 'Metal corrugated sheets'],
        'correct': 1,
        'points': 15,
        'explanation': 'White reflective roofs reflect up to 85% of solar radiation back to space, lowering surface temperatures by up to 15°C.',
      },
      {
        'q': 'What is the primary particulate matter size that poses the highest respiratory health risk in Mumbai MMR?',
        'options': ['PM10 (coarse dust)', 'PM2.5 (fine respirable particles)', 'PM50 (visible pollen)', 'PM100 (sand grains)'],
        'correct': 1,
        'points': 10,
        'explanation': 'PM2.5 particles are small enough to penetrate deep into the alveoli of lungs and enter the bloodstream.',
      },
      {
        'q': 'At what AQI range does ambient air quality turn "Hazardous" under Indian CPCB standards?',
        'options': ['101 - 200', '201 - 300', '301 - 400', '401 - 500+'],
        'correct': 3,
        'points': 10,
        'explanation': 'CPCB designates AQI 401-500+ as Severe / Hazardous, requiring emergency industrial curbs and air purifiers.',
      },
      {
        'q': 'How do urban tree canopies effectively cool surrounding microclimates?',
        'options': ['Evapotranspiration and shade shading', 'Absorbing carbon monoxide', 'Reflecting UV rays into clouds', 'Increasing air friction'],
        'correct': 0,
        'points': 15,
        'explanation': 'Trees cool ambient air through evapotranspiration (water evaporation from leaves) and by providing direct physical shading.',
      },
      {
        'q': 'Which air pollutant is formed photochemically during peak afternoon sunlight in congested cities?',
        'options': ['Sulfur Dioxide', 'Ground-Level Tropospheric Ozone (O₃)', 'Lead aerosol', 'Methane'],
        'correct': 1,
        'points': 20,
        'explanation': 'Ground-level ozone is formed when nitrogen oxides from vehicle exhaust react with volatile organic compounds in intense sunlight.',
      },
    ],
    'Mangrove Wetlands & Blue Carbon': [
      {
        'q': 'How much more carbon per hectare can mangrove soils sequester compared to terrestrial tropical rainforests?',
        'options': ['2x to 4x more', 'Equal amount', 'Half as much', '10% more'],
        'correct': 0,
        'points': 20,
        'explanation': 'Thane Creek mangrove sediment stores blue carbon up to 4 times faster and for centuries due to oxygen-poor mud.',
      },
      {
        'q': 'Which bird species migrates in thousands to Thane Creek Flamingo Sanctuary each winter?',
        'options': ['Lesser and Greater Flamingos', 'Snowy Owls', 'Emperor Penguins', 'Bald Eagles'],
        'correct': 0,
        'points': 10,
        'explanation': 'Over 100,000 Lesser and Greater Flamingos feed on blue-green algae in Thane Creek between November and May.',
      },
      {
        'q': 'What critical ecosystem protection service did mangroves provide to Mumbai during the July 26 deluge?',
        'options': ['Attracting rain clouds', 'Absorbing tidal storm surges and wave energy', 'Purifying chemical solvents', 'Providing timber'],
        'correct': 1,
        'points': 15,
        'explanation': 'Mangrove root networks attenuate up to 66% of wave energy and absorb floodwater, protecting inland settlements.',
      },
      {
        'q': 'What specialized root adaptation allows Avicennia marina mangroves to breathe in waterlogged mud?',
        'options': ['Pneumatophores (vertical breathing roots)', 'Tap roots', 'Aerial climbing tendrils', 'Fibrous bulb roots'],
        'correct': 0,
        'points': 15,
        'explanation': 'Pneumatophores grow vertically above the water/mud level to exchange oxygen directly with the atmosphere.',
      },
      {
        'q': 'What international treaty protects Thane Creek as a Wetland of International Importance?',
        'options': ['Ramsar Convention', 'Kyoto Protocol', 'Basel Convention', 'Montreal Protocol'],
        'correct': 0,
        'points': 15,
        'explanation': 'Thane Creek Flamingo Sanctuary was designated as a Ramsar Wetland Site in August 2022.',
      },
    ],
    'Rooftop Solar PV & Clean Grid': [
      {
        'q': 'Under Maharashtra (MSEDCL) net-metering regulations, what happens to surplus solar energy generated during daytime?',
        'options': ['It is exported to the grid for electricity bill credits', 'It is burned off as heat', 'It shuts down the inverter', 'It is charged a fine'],
        'correct': 0,
        'points': 10,
        'explanation': 'Net meters spin backward, banking exported kilowatt-hours against evening consumption on the monthly MSEDCL bill.',
      },
      {
        'q': 'What is the average daily sunlight generation yield of a 3 kWp rooftop solar plant in the Mumbai/Thane latitude?',
        'options': ['2 - 3 units (kWh)', '12 - 15 units (kWh)', '45 - 60 units (kWh)', '100 units (kWh)'],
        'correct': 1,
        'points': 15,
        'explanation': 'At ~4.5 peak sun hours per day, a 3 kWp system produces approximately 12 to 14.5 kWh of clean electricity daily.',
      },
      {
        'q': 'What is the average payback period for a residential rooftop solar PV system under PM Surya Ghar Muft Bijli Yojana?',
        'options': ['3 - 4.5 years', '15 - 20 years', '25 years', 'Never pays back'],
        'correct': 0,
        'points': 15,
        'explanation': 'With government subsidies and 80% bill savings, residential rooftop solar recovers its capital cost in 3 to 4.5 years.',
      },
      {
        'q': 'Which component converts Direct Current (DC) from solar panels into Alternating Current (AC) for household appliances?',
        'options': ['Solar Inverter', 'Transformer', 'Capacitor bank', 'Step motor'],
        'correct': 0,
        'points': 10,
        'explanation': 'The grid-tied solar inverter safely synchronizes DC electricity into 230V AC matching the grid frequency.',
      },
      {
        'q': 'How much CO₂ emissions are avoided per 1,000 kWh (1 MWh) of solar electricity in India compared to coal power?',
        'options': ['~100 kg CO₂', '~820 kg CO₂', '~10 kg CO₂', '~2,500 kg CO₂'],
        'correct': 1,
        'points': 20,
        'explanation': 'India’s coal-dominated grid emission factor is ~0.82 kg CO₂/kWh, meaning 1 MWh of solar prevents ~820 kg of carbon pollution.',
      },
    ],
    'Circular Economy & Zero Waste': [
      {
        'q': 'Which type of plastic resin is commonly used in clear disposable water bottles and is 100% recyclable?',
        'options': ['PET (Resin code 1)', 'PVC (Resin code 3)', 'Polystyrene (Resin code 6)', 'Melamine'],
        'correct': 0,
        'points': 10,
        'explanation': 'Polyethylene Terephthalate (PET, Resin 1) can be mechanically shredded and spun into recycled polyester clothing or rPET bottles.',
      },
      {
        'q': 'What percentage of wet household kitchen waste can be processed into organic compost at home?',
        'options': ['Up to 100% of organic scraps', 'Only 10%', '0% (all goes to landfill)', '25%'],
        'correct': 0,
        'points': 10,
        'explanation': 'Fruit peels, vegetable ends, and tea grounds decompose into nutrient-rich compost in 45 days, diverting methane from dumps.',
      },
      {
        'q': 'What dangerous greenhouse gas is generated when organic waste decomposes anaerobically inside unsegregated landfills?',
        'options': ['Methane (CH₄)', 'Nitrous oxide', 'Argon', 'Helium'],
        'correct': 0,
        'points': 15,
        'explanation': 'Methane has a global warming potential 28 times higher than CO₂ over 100 years, making landfill waste segregation crucial.',
      },
      {
        'q': 'Under Extended Producer Responsibility (EPR) laws in India, who is legally obligated to recycle plastic packaging?',
        'options': ['Brand owners and producers', 'Only municipal street sweepers', 'The end consumer exclusively', 'Foreign exporters'],
        'correct': 0,
        'points': 15,
        'explanation': 'India’s EPR regulations require fast-moving consumer goods companies to collect and recycle 100% of their plastic packaging footprint.',
      },
      {
        'q': 'How many times can aluminum beverage cans be melted down and recycled without quality loss?',
        'options': ['Infinitely (100% circular)', 'Only 2 times', 'Max 5 times', 'Never recyclable'],
        'correct': 0,
        'points': 15,
        'explanation': 'Aluminum is infinitely recyclable and uses 95% less energy to recycle than smelting virgin bauxite ore.',
      },
    ],
    'Biodiversity & Western Ghats Ecology': [
      {
        'q': 'The Western Ghats mountain range bordering Maharashtra is recognized as one of the world’s top:',
        'options': ['Biodiversity Hotspots', 'Deserts', 'Glacial valleys', 'Tundra biomes'],
        'correct': 0,
        'points': 10,
        'explanation': 'The Western Ghats host over 7,400 species of flowering plants, 500+ bird species, and thousands of endemic amphibians.',
      },
      {
        'q': 'What is the state animal of Maharashtra that inhabits the canopy of dense Western Ghats forests?',
        'options': ['Indian Giant Squirrel (Shekru)', 'Bengal Tiger', 'One-horned Rhino', 'Snow Leopard'],
        'correct': 0,
        'points': 10,
        'explanation': 'The Shekru (Ratufa indica elphinstonei) lives in tree canopies and is a key seed disperser in Maharashtra evergreen forests.',
      },
      {
        'q': 'Why are sacred groves (Devrais) in Maharashtra crucial for biological conservation?',
        'options': ['They preserve ancient virgin flora protected by community taboos', 'They are used for timber logging', 'They are amusement parks', 'They are concrete reservoirs'],
        'correct': 0,
        'points': 15,
        'explanation': 'Devrais are patches of ancient forest traditionally protected by indigenous communities, serving as vital gene banks.',
      },
      {
        'q': 'Which endemic tree frog species of the Western Ghats was rediscovered in recent years and spends life in tree hollows?',
        'options': ['Malabar Gliding Frog', 'Poison Dart Frog', 'American Bullfrog', 'African Clawed Frog'],
        'correct': 0,
        'points': 15,
        'explanation': 'The Malabar Gliding Frog (Rhacophorus malabaricus) glides up to 10 meters between forest trees using webbed feet.',
      },
      {
        'q': 'What critical ecological role do fruit bats and hornbills play in Western Ghats forest regeneration?',
        'options': ['Long-distance seed dispersal for large canopy trees', 'Hunting invasive insects exclusively', 'Pollinating subterranean fungi', 'Consuming tree bark'],
        'correct': 0,
        'points': 15,
        'explanation': 'Great Pied Hornbills and fruit bats are "farmers of the forest", swallowing large fruits and dispersing seeds miles away.',
      },
    ],
  };

  // Active Quiz State (5 Questions per set)
  List<Map<String, dynamic>> _activeQuestions = [];
  int _currentQuestionIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _sessionScore = 0;
  int _sessionPointsEarned = 0;
  bool _quizFinished = false;

  // Persistent History
  static final List<QuizHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _startNewQuizSet();
  }

  void _startNewQuizSet() {
    final pool = List<Map<String, dynamic>>.from(_questionBank[_selectedTheme] ?? _questionBank.values.first);
    pool.shuffle();
    final fiveQuestions = pool.take(5).toList();

    setState(() {
      _activeQuestions = fiveQuestions;
      _currentQuestionIndex = 0;
      _selectedOption = null;
      _answered = false;
      _sessionScore = 0;
      _sessionPointsEarned = 0;
      _quizFinished = false;
    });
  }

  void _submitAnswer(int optionIndex) {
    if (_answered || _quizFinished || _activeQuestions.isEmpty) return;

    final currentQ = _activeQuestions[_currentQuestionIndex];
    final correctIdx = currentQ['correct'] as int;
    final points = currentQ['points'] as int;

    setState(() {
      _selectedOption = optionIndex;
      _answered = true;
      if (optionIndex == correctIdx) {
        _sessionScore++;
        _sessionPointsEarned += points;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _activeQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      // Quiz Finished!
      setState(() {
        _quizFinished = true;
      });

      // Log points in AppState
      if (_sessionPointsEarned > 0) {
        widget.appState.logActivity(
          title: 'Climate Quiz: $_selectedTheme',
          category: 'Education',
          subtitle: 'Scored $_sessionScore/5 • Earned +$_sessionPointsEarned Green Points',
          pointsEarned: _sessionPointsEarned,
          co2Kg: 0.0,
          icon: Icons.school_rounded,
        );
      }

      // Record in History
      _history.insert(
        0,
        QuizHistoryEntry(
          date: DateTime.now(),
          theme: _selectedTheme,
          correctCount: _sessionScore,
          totalQuestions: _activeQuestions.length,
          pointsEarned: _sessionPointsEarned,
        ),
      );
    }
  }

  void _openHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final totalHistoryPoints = _history.fold<int>(0, (sum, item) => sum + item.pointsEarned);

        return Padding(
          padding: const EdgeInsets.all(24),
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
                      const Text('Quiz & Points History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('${_history.length} completed sets • $totalHistoryPoints lifetime points', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.royalForest, borderRadius: BorderRadius.circular(12)),
                    child: Text('+$totalHistoryPoints pts', style: const TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No quizzes completed yet.\nComplete your first 5-question set above!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, idx) {
                      final item = _history[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.royalForest.withValues(alpha: 0.15),
                          child: const Icon(Icons.school_rounded, color: AppColors.champagneGold, size: 20),
                        ),
                        title: Text(item.theme, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${item.correctCount}/${item.totalQuestions} correct • ${item.date.hour.toString().padLeft(2, "0")}:${item.date.minute.toString().padLeft(2, "0")}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: Text('+${item.pointsEarned} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald, fontSize: 13)),
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
        title: 'Climate Quizzes',
        subtitle: '5 Questions per Set • Dynamic Points',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.champagneGold),
            tooltip: 'Quiz History',
            onPressed: _openHistoryModal,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Theme Selector Dropdown / Horizontal Scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _themes.map((theme) {
                  final isSel = _selectedTheme == theme;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(theme, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? AppColors.champagneGold : textColor)),
                      selected: isSel,
                      selectedColor: AppColors.royalForest,
                      backgroundColor: cardBg,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedTheme = theme);
                          _startNewQuizSet();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Progress & Points Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _quizFinished
                      ? 'Quiz Completed'
                      : 'Question ${_currentQuestionIndex + 1} of ${_activeQuestions.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.champagneGold),
                ),
                InkWell(
                  onTap: _openHistoryModal,
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, size: 16, color: AppColors.emerald),
                      const SizedBox(width: 4),
                      Text('+$_sessionPointsEarned pts earned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main Question Card or Summary View
            Expanded(
              child: _quizFinished
                  ? _buildSummaryCard(cardBg, isDark, textColor)
                  : _buildQuestionCard(cardBg, isDark, textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Color cardBg, bool isDark, Color textColor) {
    if (_activeQuestions.isEmpty) return const SizedBox.shrink();
    final q = _activeQuestions[_currentQuestionIndex];
    final options = (q['options'] as List<dynamic>?) ?? [];
    final correctIdx = q['correct'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.royalForest.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('+${q['points']} pts', style: const TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              Text(
                'Q${_currentQuestionIndex + 1}',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            q['q'] as String,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
          ),
          const SizedBox(height: 20),

          // Options List
          ...List.generate(options.length, (idx) {
            final opt = options[idx] as String;
            final isChosen = _selectedOption == idx;
            final isCorrect = idx == correctIdx;

            Color borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
            Color bgColor = Colors.transparent;
            Color optTextColor = textColor;

            if (_answered) {
              if (isCorrect) {
                borderColor = AppColors.emerald;
                bgColor = AppColors.emerald.withValues(alpha: 0.15);
                optTextColor = AppColors.emerald;
              } else if (isChosen) {
                borderColor = AppColors.coral;
                bgColor = AppColors.coral.withValues(alpha: 0.15);
                optTextColor = AppColors.coral;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: _answered ? null : () => _submitAnswer(idx),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: isChosen || (_answered && isCorrect) ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isChosen ? AppColors.champagneGold : Colors.grey.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          String.fromCharCode(65 + idx),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isChosen ? Colors.black : textColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: optTextColor)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Scientific Explanation
          if (_answered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.royalForest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.champagneGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scientific Fact:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.champagneGold)),
                  const SizedBox(height: 4),
                  Text(
                    q['explanation'] as String,
                    style: TextStyle(fontSize: 11, color: textColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.royalForest,
                  foregroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _nextQuestion,
                child: Text(
                  _currentQuestionIndex == _activeQuestions.length - 1 ? 'Finish Quiz' : 'Next Question →',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Color cardBg, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.champagneGold.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.royalForest.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.champagneGold, size: 54),
          ),
          const SizedBox(height: 18),
          Text('Quiz Set Completed!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: textColor)),
          const SizedBox(height: 8),
          Text(
            'Theme: $_selectedTheme',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatPill('Score', '$_sessionScore / 5', AppColors.emerald),
              const SizedBox(width: 12),
              _buildStatPill('Green Points', '+$_sessionPointsEarned pts', AppColors.champagneGold),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalForest,
                foregroundColor: AppColors.champagneGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _startNewQuizSet,
              child: const Text('Try Another 5 Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _openHistoryModal,
            child: const Text('View Quiz & Points History', style: TextStyle(color: AppColors.champagneGold, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color valColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.royalForest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: valColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valColor)),
        ],
      ),
    );
  }
}
