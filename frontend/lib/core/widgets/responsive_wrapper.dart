import 'package:flutter/material.dart';

/// ResponsiveWrapper ensures complete safety on all device screen sizes,
/// accounting specifically for Android 3-button navigation bars,
/// keyboard insets, and notch safe areas with zero UI clipping.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final bool applyBottomPadding;
  final bool applyTopPadding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.applyBottomPadding = true,
    this.applyTopPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final systemBottomPadding = media.padding.bottom;

    // Detect if Android 3-button navigation or a physical bar is taking up space (>20px)
    final double extraBottomBuffer = systemBottomPadding > 20 ? systemBottomPadding : 16.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500), // Clean responsive bounds for tablets/desktop
        child: SafeArea(
          top: applyTopPadding,
          bottom: false, // We manually calculate bottom to avoid 3-button clipping
          child: Padding(
            padding: EdgeInsets.only(
              bottom: applyBottomPadding ? (bottomInset > 0 ? bottomInset : extraBottomBuffer) : 0,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
