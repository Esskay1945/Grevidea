import 'dart:typed_data';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class ScanProductScreen extends StatefulWidget {
  final AppState appState;
  const ScanProductScreen({super.key, required this.appState});

  @override
  State<ScanProductScreen> createState() => _ScanProductScreenState();
}

class _ScanProductScreenState extends State<ScanProductScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  bool _isScanned = false;
  bool _isAnalyzing = false;
  Uint8List? _capturedImage;
  Map<String, dynamic>? _scannedProduct;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _showScanModeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightTextSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'EcoLens Scanner Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan a product barcode or packaging in real time',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.royalForest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: AppColors.champagneGold, size: 22),
                  ),
                  title: const Text('Open Camera to Scan',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      'Point your phone camera at product barcode or label'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureAndScan(ImageSource.camera);
                  },
                ),
                ListTile(
                    leading: const Icon(Icons.keyboard),
                    title: const Text('Enter barcode'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final input = TextEditingController();
                      final code = await showDialog<String>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                                  title: const Text('Product barcode'),
                                  content: TextField(
                                      controller: input,
                                      keyboardType: TextInputType.number),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(
                                            dialog, input.text.trim()),
                                        child: const Text('Search'))
                                  ]));
                      input.dispose();
                      if (code != null && code.isNotEmpty) {
                        try {
                          await _lookup(code);
                        } catch (error) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())));
                        }
                      }
                    }),
                const Divider(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: AppColors.champagneGold, size: 22),
                  ),
                  title: const Text('Upload Image from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      'Analyze a product photo or barcode screenshot'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureAndScan(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _captureAndScan(ImageSource source) async {
    String? barcode;
    try {
      if (source == ImageSource.camera) {
        if (!mounted) return;
        final controller = MobileScannerController();
        var detected = false;
        barcode = await Navigator.of(context).push<String>(MaterialPageRoute(
            builder: (ctx) => Scaffold(
                appBar: AppBar(title: const Text('Scan barcode')),
                body: MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      final code = capture.barcodes
                          .map((b) => b.rawValue)
                          .whereType<String>()
                          .firstOrNull;
                      if (!detected && code != null) {
                        detected = true;
                        Navigator.pop(ctx, code);
                      }
                    }))));
        await controller.dispose();
      } else {
        final file = await _picker.pickImage(source: source, imageQuality: 85);
        if (file == null) return;
        final controller = MobileScannerController(autoStart: false);
        final capture = await controller.analyzeImage(file.path);
        await controller.dispose();
        barcode = capture?.barcodes
            .map((b) => b.rawValue)
            .whereType<String>()
            .firstOrNull;
        _capturedImage = await file.readAsBytes();
      }
      if (barcode == null)
        throw StateError(
            'No readable barcode found. Try the camera or enter a barcode.');
      await _lookup(barcode);
    } catch (error) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _lookup(String barcode) async {
    if (!RegExp(r'^\d{8,14}$').hasMatch(barcode))
      throw StateError('Enter an 8–14 digit product barcode.');
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
      _isScanned = false;
    });
    final res = await widget.appState.api.scanProductBarcode(barcode);
    if (!mounted) return;
    setState(() {
      _scannedProduct = res;
      _isAnalyzing = false;
      _isScanned = true;
    });
    if (res['unavailable'] == true)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No verified product found or product service unavailable.')));
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Scan Product',
        subtitle: 'EcoLens Lifecycle Scanner',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Scan the barcode or label of any product to view its real-time carbon footprint.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),

          // Viewfinder Camera Simulation / Real Preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GestureDetector(
                onTap: _showScanModeDialog,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: AppColors.champagneGold.withValues(alpha: 0.5),
                        width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // If user took a photo, show their real photo
                        if (_capturedImage != null)
                          Positioned.fill(
                            child: Image.memory(
                              _capturedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 100,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Align barcode within frame',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),

                        // Scanning Laser Animation
                        if (_isAnalyzing || !_isScanned)
                          AnimatedBuilder(
                            animation: _laserController,
                            builder: (context, child) {
                              return Positioned(
                                top: 40 + (_laserController.value * 220),
                                left: 20,
                                right: 20,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.emerald
                                            .withValues(alpha: 0.8),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Four Corner Target Brackets
                        Positioned(
                          top: 24,
                          left: 24,
                          child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                  border: Border(
                                      top: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3),
                                      left: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3)))),
                        ),
                        Positioned(
                          top: 24,
                          right: 24,
                          child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                  border: Border(
                                      top: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3),
                                      right: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3)))),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 24,
                          child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3),
                                      left: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3)))),
                        ),
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3),
                                      right: BorderSide(
                                          color: AppColors.champagneGold,
                                          width: 3)))),
                        ),

                        // Status Overlay if analyzing
                        if (_isAnalyzing)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: AppColors.champagneGold),
                                  SizedBox(height: 12),
                                  Text('Analyzing packaging & barcode...',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Sheet: Scanned Product Results Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                  color: isDark
                      ? AppColors.darkCardBorder
                      : AppColors.lightCardBorder),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _scannedProduct?['product_name'] ??
                                'Scan a product to begin',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _scannedProduct?['brand'] ?? 'Unavailable',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _scannedProduct?['eco_score'] ??
                            'Eco-score unavailable',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3 Metric Tiles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScanMetric(
                        'CO₂ Footprint',
                        _scannedProduct?['co2_footprint'] ?? 'Unavailable',
                        AppColors.amber),
                    _buildScanMetric(
                        'Recyclable',
                        _scannedProduct?['recyclable'] ?? 'Unavailable',
                        AppColors.emerald),
                    _buildScanMetric(
                        'Eco-Score', 'B+ Good', AppColors.champagneGold),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  _scannedProduct?['packaging'] ?? 'Packaging data unavailable',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.lightTextSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Dual Camera / Upload Action Button
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Use Camera',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.royalForest,
                            foregroundColor: AppColors.champagneGold,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _captureAndScan(ImageSource.camera),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          icon:
                              const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text('Upload Photo',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(
                                color: isDark
                                    ? AppColors.darkCardBorder
                                    : AppColors.lightCardBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _captureAndScan(ImageSource.gallery),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanMetric(String label, String val, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.lightTextSecondary,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(val,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}
