import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../state/app_state.dart';

class ClimateGptScreen extends StatefulWidget {
  final AppState appState;

  const ClimateGptScreen({super.key, required this.appState});

  @override
  State<ClimateGptScreen> createState() => _ClimateGptScreenState();
}

class _ClimateGptScreenState extends State<ClimateGptScreen> {
  final _textController = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Hello Yash! I am ClimateGPT, your GCI Brain environmental assistant. How can I assist your climate actions today?',
      isUser: false,
    ),
  ];

  final List<String> _promptChips = [
    'How do I lower my commute footprint?',
    'What causes high PM2.5 in Thane?',
    'Check if paper bags are really greener',
    'Tips to compost at home',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isUser: true));
      _textController.clear();
    });

    // Intelligent simulated response
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      String response = 'Great question! According to verified IPCC and CPCB data for ${widget.appState.baseline.cityWard}, switching your daily commute from petrol vehicle to the Metro reduces your weekly emissions by approximately 24.2 kg CO₂ while saving on fuel costs.';
      if (text.toLowerCase().contains('pm2.5') || text.toLowerCase().contains('aqi')) {
        response = 'Current AQI in Thane is 38 (Good). The predominant factors in the MMR region are vehicular exhaust and construction dust, which are currently dispersed by coastal sea-breezes.';
      } else if (text.toLowerCase().contains('paper') || text.toLowerCase().contains('bag')) {
        response = 'IPCC Life Cycle Analysis shows a single cotton or canvas bag must be reused at least 50–100 times to have a lower carbon footprint than a standard bag. Reusability is the key!';
      }

      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ClimateGPT Assistant'),
      ),
      body: ResponsiveWrapper(
        child: Column(
          children: [
            // Prompt Chips
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _promptChips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ActionChip(
                    label: Text(_promptChips[index], style: const TextStyle(fontSize: 12)),
                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    side: BorderSide(color: AppColors.champagneGold.withOpacity(0.5)),
                    onPressed: () => _sendMessage(_promptChips[index]),
                  );
                },
              ),
            ),
            const Divider(height: 16),

            // Chat Messages
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? AppColors.royalForest
                            : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: msg.isUser ? AppColors.champagneGold : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: msg.isUser
                              ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Text Input Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(top: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Ask climate or lifestyle questions...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.champagneGold),
                    onPressed: () => _sendMessage(_textController.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}
