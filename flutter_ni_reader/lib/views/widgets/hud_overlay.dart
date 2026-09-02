import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Accurate, high-precision HUD overlay matching horizontal standard ID-1 card (85.60mm x 53.98mm)
class HudOverlay extends StatelessWidget {
  final String title;
  final String hint;
  final bool isBackScanning;
  final bool isAutoCapturing;
  final bool isTorchOn;
  final int countdownSeconds; // 3, 2, 1, 0
  final double stabilityProgress; // 0.0 to 1.0
  final VoidCallback? onToggleTorch;
  final VoidCallback? onManualInput;
  final VoidCallback? onClose;
  final VoidCallback? onShare;

  const HudOverlay({
    super.key,
    required this.title,
    required this.hint,
    this.isBackScanning = true,
    this.isAutoCapturing = false,
    this.isTorchOn = false,
    this.countdownSeconds = 0,
    this.stabilityProgress = 0.0,
    this.onToggleTorch,
    this.onManualInput,
    this.onClose,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Standard ID-1 Horizontal Card Aspect Ratio (85.60mm / 53.98mm = ~1.5858)
    final double cardWidth = isLandscape
        ? math.min(size.width * 0.62, 480.0)
        : math.min(size.width * 0.90, 360.0);
    final double cardHeight = cardWidth / (85.60 / 53.98);

    final bool isCountingDown = countdownSeconds > 0;

    return Stack(
      children: [
        // 1. Semi-transparent darkened vignette overlay with clear rounded rectangle cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.72),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Top Instruction Pill Badge ("Align back of identity card here")
        Positioned(
          top: math.max((size.height - cardHeight) / 2 - 56, 40),
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              decoration: BoxDecoration(
                color: isCountingDown ? const Color(0xE60F2A1D) : const Color(0xE61E1E1E),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isCountingDown ? const Color(0xFF10B981) : Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                isBackScanning
                    ? "Align back of identity card here"
                    : "Align front of identity card here",
                style: TextStyle(
                  color: isCountingDown ? const Color(0xFF10B981) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),

        // 3. Crisp White/Green Rounded Rectangle Border Frame & Internal Guides
        Center(
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Stack(
              children: [
                // Solid Border (Turns emerald green with glow when locked & counting down)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCountingDown ? const Color(0xFF10B981) : Colors.white,
                      width: isCountingDown ? 3.0 : 2.2,
                    ),
                    boxShadow: isCountingDown
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.65),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),

                // 3 Horizontal Rows of MRZ Guide Symbols `>>>>` positioned at the bottom of the card
                if (isBackScanning)
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHorizontalChevronRow(),
                        const SizedBox(height: 3),
                        _buildHorizontalChevronRow(),
                        const SizedBox(height: 3),
                        _buildHorizontalChevronRow(),
                      ],
                    ),
                  ),

                // 3-Second Stability Circular Countdown Badge in Center
                if (isCountingDown)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 16,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: CircularProgressIndicator(
                                  value: stabilityProgress,
                                  strokeWidth: 4,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                              Text(
                                "$countdownSeconds",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "ثبّت البطاقة...",
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Scanning laser bar
                if (isAutoCapturing && !isCountingDown) const _LiveScanBar(),
              ],
            ),
          ),
        ),

        // 4. Top Action Buttons (Share & Dismiss)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(
                  icon: Icons.ios_share_rounded,
                  onTap: onShare ?? () {},
                ),
                _buildCircularButton(
                  icon: Icons.close_rounded,
                  onTap: onClose ?? () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),

        // 5. Action Controls (Manual Input & Torch)
        SafeArea(
          child: Align(
            alignment: isLandscape ? Alignment.centerRight : Alignment.bottomCenter,
            child: Padding(
              padding: isLandscape
                  ? const EdgeInsets.only(right: 20)
                  : const EdgeInsets.only(bottom: 28, left: 24, right: 24),
              child: isLandscape
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBottomActionButton(
                          icon: Icons.keyboard_alt_outlined,
                          label: "Manual input",
                          subLabel: "إدخال يدوي",
                          onTap: onManualInput,
                        ),
                        const SizedBox(height: 20),
                        _buildBottomActionButton(
                          icon: isTorchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                          label: "Torch",
                          subLabel: isTorchOn ? "مفعل" : "الفلاش",
                          iconColor: isTorchOn ? const Color(0xFFFFD700) : Colors.white,
                          onTap: onToggleTorch,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBottomActionButton(
                          icon: Icons.keyboard_alt_outlined,
                          label: "Manual input",
                          subLabel: "إدخال يدوي",
                          onTap: onManualInput,
                        ),
                        _buildBottomActionButton(
                          icon: isTorchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                          label: "Torch",
                          subLabel: isTorchOn ? "مفعل" : "الفلاش",
                          iconColor: isTorchOn ? const Color(0xFFFFD700) : Colors.white,
                          onTap: onToggleTorch,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a single horizontal row of chevron guide symbols `> > > > > > > > > > > > > > > > > > > > > > > > > > > > > >`
  Widget _buildHorizontalChevronRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        30,
        (index) => const Text(
          ">",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            height: 0.9,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0x80222222),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required String subLabel,
    Color iconColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x99252525),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveScanBar extends StatefulWidget {
  const _LiveScanBar();

  @override
  State<_LiveScanBar> createState() => _LiveScanBarState();
}

class _LiveScanBarState extends State<_LiveScanBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment(0, (_controller.value * 2) - 1),
          child: Container(
            height: 2.5,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.0),
                  const Color(0xFF10B981),
                  const Color(0xFF00E5FF),
                  const Color(0xFF10B981).withOpacity(0.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.85),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
