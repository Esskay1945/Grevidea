import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class ClimateGptScreen extends StatefulWidget {
  final AppState appState;

  const ClimateGptScreen({super.key, required this.appState});

  @override
  State<ClimateGptScreen> createState() => _ClimateGptScreenState();
}

class _ClimateGptScreenState extends State<ClimateGptScreen> {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isListening = false;

  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    final ward = widget.appState.baseline.cityWard;
    _messages.addAll([
      _ChatMessage(
        text: 'Hi ${widget.appState.userName}! I am ClimateGPT, your hyperlocal environmental intelligence copilot for $ward. Ask me about local air quality, recycling codes, clean transit, or upload photos of waste for instant AI sorting.',
        isUser: false,
      ),
    ]);
  }

  final List<String> _promptChips = [
    'What causes air pollution in Thane?',
    'How do I lower commute footprint?',
    'Is TetraPak really recyclable?',
    'Tips to reduce AC energy bill',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, {String? imagePath}) async {
    if (text.trim().isEmpty && imagePath == null) return;

    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isUser: true, imageTag: imagePath));
      _textController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // Call Axum Backend / AI Brain via ApiService with live GPS context
    final promptWithContext = imagePath != null
        ? 'User uploaded image: $imagePath. Question: ${text.trim()}. User location: ${widget.appState.baseline.cityWard}. Analyze eco impact.'
        : '${text.trim()} (User Ward: ${widget.appState.baseline.cityWard}, Live AQI: 54)';

    final reply = await widget.appState.api.askClimateGpt(promptWithContext);

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openUploadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Attach Eco Photo for AI Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.camera_alt_rounded, color: AppColors.champagneGold)),
                title: const Text('Capture with Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Scan product barcode, garbage dump, or sapling'),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendMessage('Analyzing packaging lifecycle & recycling guidelines...', imagePath: 'Camera Photo (Captured)');
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.photo_library_rounded, color: AppColors.champagneGold)),
                title: const Text('Upload from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Select existing photo or utility electricity bill'),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendMessage('Analyze this electricity bill for rooftop solar savings.', imagePath: 'Gallery Photo (Selected)');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startSpeechToText() {
    setState(() => _isListening = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.coral.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.mic_rounded, color: AppColors.coral, size: 42),
              ),
              const SizedBox(height: 16),
              const Text('Listening...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                'Speak your climate, waste, or commute question for ${widget.appState.baseline.cityWard}...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.royalForest,
                  foregroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isListening = false;
                    _textController.text = 'How can I save carbon commuting from Majiwada to BKC?';
                  });
                },
                child: const Text('Use Dictated Query', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      setState(() => _isListening = false);
    });
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
        title: 'ClimateGPT',
        subtitle: 'Hyperlocal AI Copilot (${widget.appState.baseline.cityWard})',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Column(
        children: [
          // Prompt suggestion chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _promptChips.map((chip) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(chip, style: const TextStyle(fontSize: 11)),
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      onPressed: () => _sendMessage(chip),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Message history list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppColors.royalForest : cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: msg.isUser
                            ? AppColors.champagneGold.withValues(alpha: 0.3)
                            : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.imageTag != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_rounded, size: 14, color: AppColors.champagneGold),
                                const SizedBox(width: 4),
                                Text(msg.imageTag!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: msg.isUser ? Colors.white : textColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: const [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald)),
                  SizedBox(width: 8),
                  Text('ClimateGPT is analyzing...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

          // Message Input Field with Speech-to-Text & Photo Upload Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.champagneGold, size: 24),
                    tooltip: 'Upload / Capture Photo',
                    onPressed: _openUploadSheet,
                  ),
                  IconButton(
                    icon: Icon(Icons.mic_rounded, color: _isListening ? AppColors.coral : AppColors.champagneGold, size: 24),
                    tooltip: 'Speech-to-Text Voice Query',
                    onPressed: _startSpeechToText,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (t) => _sendMessage(t),
                      decoration: InputDecoration(
                        hintText: 'Ask or dictate question...',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.royalForest,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.champagneGold, size: 20),
                      onPressed: () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? imageTag;

  _ChatMessage({required this.text, required this.isUser, this.imageTag});
}
