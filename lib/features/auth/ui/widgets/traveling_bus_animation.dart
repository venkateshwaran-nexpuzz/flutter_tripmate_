import 'dart:math' as math;
import 'package:flutter/material.dart';

class TravelingBusBanner extends StatefulWidget {
  final double height;
  const TravelingBusBanner({super.key, this.height = 95});

  @override
  State<TravelingBusBanner> createState() => _TravelingBusBannerState();
}

class _TravelingBusBannerState extends State<TravelingBusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final screenWidth = MediaQuery.of(context).size.width;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Soft Day Sky Clouds Drifting
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 38,
                child: CustomPaint(
                  painter: _DayCloudsPainter(offset: progress),
                ),
              ),

              // 2. Parallax Green Campus Trees & Street Poles
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                height: 40,
                child: CustomPaint(
                  painter: _CampusSceneryPainter(offset: progress),
                ),
              ),

              // 3. Clean Asphalt Road with Moving Yellow Dashes
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 20,
                child: CustomPaint(
                  painter: _DayRoadPainter(offset: progress),
                ),
              ),

              // 4. Smooth Traveling College Bus with Suspension Bounce
              Positioned(
                bottom: 9 + (math.sin(progress * math.pi * 18).abs() * 1.5),
                left: _calculateBusPosition(progress, screenWidth),
                child: const _CollegeBusWidget(),
              ),

              // 5. Subtle Live Tracking Dot & Road Tag
              Positioned(
                bottom: 23,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _calculateBusPosition(double progress, double screenWidth) {
    const busWidth = 92.0;
    final maxW = screenWidth > 440 ? 440.0 : screenWidth;
    final totalSpan = maxW + busWidth + 24;
    return (progress * totalSpan) - busWidth;
  }
}

// ============================================================
// DAYTIME COLLEGE BUS GRAPHIC
// ============================================================

class _CollegeBusWidget extends StatelessWidget {
  const _CollegeBusWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft Shadow on the Asphalt
          Positioned(
            left: 6,
            right: 6,
            bottom: 0,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Bus Main Chassis (Golden Yellow with Royal Blue Accent)
          Positioned(
            left: 2,
            right: 2,
            top: 4,
            bottom: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFBBF24), // College Bus Yellow
                    Color(0xFFF59E0B),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(5),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withOpacity(0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Upper Windows Glass Row
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Row(
                      children: [
                        _buildGlassWindow(),
                        const SizedBox(width: 2),
                        _buildGlassWindow(),
                        const SizedBox(width: 2),
                        _buildGlassWindow(),
                        const SizedBox(width: 2),
                        _buildGlassWindow(),
                        const SizedBox(width: 3),
                        // Driver Windshield
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Royal Blue VET Fleet Livery Band
                  Container(
                    height: 6,
                    width: double.infinity,
                    color: const Color(0xFF1E40AF),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const Center(
                      child: Text(
                        'VET CAMPUS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 4.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),

          // Headlight
          Positioned(
            right: 2,
            bottom: 9,
            child: Container(
              width: 3,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF08A),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withOpacity(0.8),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),

          // Taillight
          Positioned(
            left: 1,
            bottom: 9,
            child: Container(
              width: 2.5,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),

          // Front & Rear Wheels
          const Positioned(
            left: 13,
            bottom: 1,
            child: _DayBusWheel(),
          ),
          const Positioned(
            right: 14,
            bottom: 1,
            child: _DayBusWheel(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassWindow() {
    return Container(
      width: 10,
      height: 11,
      decoration: BoxDecoration(
        color: const Color(0xFF7DD3FC),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF0284C7), width: 0.5),
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0xFF0369A1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _DayBusWheel extends StatelessWidget {
  const _DayBusWheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0xFFCBD5E1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CLEAN LIGHT-THEME ROAD & SCENERY PAINTERS
// ============================================================

class _DayRoadPainter extends CustomPainter {
  final double offset;
  _DayRoadPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // Road Asphalt
    final roadPaint = Paint()..color = const Color(0xFF475569);
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rRect, roadPaint);

    // Top Curb Line
    final curbPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), curbPaint);

    // Moving Dashed Center Line
    final dashPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 1.8;

    const dashWidth = 12.0;
    const dashSpace = 10.0;
    const totalStep = dashWidth + dashSpace;
    final startShift = -(offset * totalStep * 4) % totalStep;

    double x = startShift;
    final y = size.height / 2;

    while (x < size.width) {
      if (x + dashWidth > 0) {
        canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), dashPaint);
      }
      x += totalStep;
    }
  }

  @override
  bool shouldRepaint(covariant _DayRoadPainter oldDelegate) => oldDelegate.offset != offset;
}

class _CampusSceneryPainter extends CustomPainter {
  final double offset;
  _CampusSceneryPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final foliagePaint1 = Paint()..color = const Color(0xFF10B981).withOpacity(0.85);
    final foliagePaint2 = Paint()..color = const Color(0xFF059669).withOpacity(0.9);
    final trunkPaint = Paint()..color = const Color(0xFF92400E);
    final lampPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.4;

    const spacing = 100.0;
    final shift = (offset * spacing * 3) % spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      final actualX = x - shift;

      // Tree 1
      canvas.drawRect(Rect.fromLTWH(actualX + 18, size.height - 8, 3.5, 8), trunkPaint);
      canvas.drawCircle(Offset(actualX + 20, size.height - 14), 10, foliagePaint1);
      canvas.drawCircle(Offset(actualX + 25, size.height - 16), 7, foliagePaint2);

      // Campus Street Lamp
      canvas.drawLine(Offset(actualX + 68, size.height), Offset(actualX + 68, size.height - 24), lampPaint);
      canvas.drawLine(Offset(actualX + 68, size.height - 24), Offset(actualX + 74, size.height - 24), lampPaint);
      canvas.drawCircle(Offset(actualX + 74, size.height - 22), 2.2, Paint()..color = const Color(0xFFFBBF24));
    }
  }

  @override
  bool shouldRepaint(covariant _CampusSceneryPainter oldDelegate) => oldDelegate.offset != offset;
}

class _DayCloudsPainter extends CustomPainter {
  final double offset;
  _DayCloudsPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = const Color(0xFFE2E8F0).withOpacity(0.65);
    const spacing = 160.0;
    final shift = (offset * spacing * 0.8) % spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      final actualX = x - shift;
      _drawCloud(canvas, Offset(actualX + 30, 14), cloudPaint);
    }
  }

  void _drawCloud(Canvas canvas, Offset center, Paint paint) {
    canvas.drawCircle(center, 9, paint);
    canvas.drawCircle(Offset(center.dx + 8, center.dy + 2), 7, paint);
    canvas.drawCircle(Offset(center.dx - 8, center.dy + 2), 6, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 4), width: 22, height: 7),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DayCloudsPainter oldDelegate) => oldDelegate.offset != offset;
}
