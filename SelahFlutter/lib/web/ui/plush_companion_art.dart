import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/selah_enums.dart';

enum PlushExpression { calm, attentive, happy, encouraging }

/// Fixed 1000 × 1200 artwork space, shared by every state and display size.
class PlushCompanionArt extends StatelessWidget {
  const PlushCompanionArt({
    super.key,
    required this.expression,
    required this.eyeOpen,
    required this.leafAngle,
    required this.stage,
  });

  static const asset = 'assets/sprites/SeedPlushAtlas.png';
  final PlushExpression expression;
  final double eyeOpen;
  final double leafAngle;
  final DecorationStage stage;
  static const _leafRoot = Alignment(-.853, .957);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1000,
    height: 1200,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 73,
          top: 260,
          width: 854,
          height: 873,
          child: _AtlasPiece(body: true),
        ),
        Positioned(
          left: 470,
          top: 22,
          width: 304.15,
          height: 250.25,
          child: Transform.rotate(
            angle: leafAngle,
            alignment: _leafRoot,
            child: Transform.scale(
              scale: stage == DecorationStage.leaf ? 1.04 : 1,
              alignment: _leafRoot,
              child: const _AtlasPiece(body: false),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _StitchesPainter(expression, eyeOpen, stage),
          ),
        ),
      ],
    ),
  );
}

class _AtlasPiece extends StatelessWidget {
  const _AtlasPiece({required this.body});
  final bool body;

  @override
  Widget build(BuildContext context) {
    final bounds = body
        ? const Rect.fromLTWH(77, 252, 854, 873)
        : const Rect.fromLTWH(838, 100, 395, 325);
    return FittedBox(
      child: ClipPath(
        clipper: _AtlasContour(bounds, body ? _bodyContour : _leafContour),
        child: SizedBox(
          width: bounds.width,
          height: bounds.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -bounds.left,
                top: -bounds.top,
                width: 1254,
                height: 1254,
                child: Image.asset(
                  PlushCompanionArt.asset,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                  gaplessPlayback: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The source atlas is RGB. Clip its measured silhouette at render time;
/// never display its printed checkerboard as if it were an alpha channel.
class _AtlasContour extends CustomClipper<Path> {
  const _AtlasContour(this.bounds, this.points);
  final Rect bounds;
  final List<(double, double)> points;

  @override
  Path getClip(Size size) => Path()
    ..addPolygon([
      for (final (x, y) in points)
        Offset(
          (x - bounds.left) * size.width / bounds.width,
          (y - bounds.top) * size.height / bounds.height,
        ),
    ], true);

  @override
  bool shouldReclip(_AtlasContour oldClipper) => bounds != oldClipper.bounds;
}

// Source-pixel coordinates, measured from SeedPlushAtlas.png, not pose variants.
const _bodyContour = <(double, double)>[
  (363, 278),
  (352, 285),
  (350, 290),
  (335, 297),
  (335, 300),
  (330, 300),
  (328, 304),
  (313, 311),
  (280, 340),
  (252, 370),
  (220, 411),
  (168, 495),
  (144, 545),
  (122, 601),
  (93, 700),
  (84, 746),
  (78, 809),
  (80, 881),
  (90, 930),
  (104, 970),
  (131, 1016),
  (150, 1037),
  (170, 1053),
  (219, 1076),
  (293, 1093),
  (304, 1109),
  (329, 1120),
  (359, 1124),
  (400, 1121),
  (422, 1110),
  (433, 1095),
  (553, 1093),
  (654, 1082),
  (675, 1097),
  (700, 1103),
  (739, 1102),
  (767, 1096),
  (785, 1081),
  (789, 1071),
  (789, 1059),
  (828, 1033),
  (861, 999),
  (882, 964),
  (890, 943),
  (903, 933),
  (915, 918),
  (929, 879),
  (930, 855),
  (926, 828),
  (907, 792),
  (902, 750),
  (889, 687),
  (866, 614),
  (834, 537),
  (798, 470),
  (744, 395),
  (685, 336),
  (617, 288),
  (562, 263),
  (528, 255),
  (496, 252),
  (464, 252),
  (426, 257),
];
const _leafContour = <(double, double)>[
  (1219, 157),
  (1196, 136),
  (1177, 124),
  (1133, 107),
  (1099, 101),
  (1075, 100),
  (1032, 105),
  (1011, 111),
  (1004, 117),
  (1003, 113),
  (990, 117),
  (987, 121),
  (957, 134),
  (921, 164),
  (901, 190),
  (883, 223),
  (871, 255),
  (864, 298),
  (866, 316),
  (860, 326),
  (838, 400),
  (840, 411),
  (852, 420),
  (868, 424),
  (892, 421),
  (896, 417),
  (912, 375),
  (923, 358),
  (961, 364),
  (1017, 361),
  (1056, 352),
  (1099, 332),
  (1138, 302),
  (1194, 239),
  (1225, 210),
  (1231, 199),
  (1232, 184),
];

class _StitchesPainter extends CustomPainter {
  const _StitchesPainter(this.expression, this.eyeOpen, this.stage);
  final PlushExpression expression;
  final double eyeOpen;
  final DecorationStage stage;
  static const _thread = Color(0xFF53341F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1000, size.height / 1200);
    _eye(canvas, const Offset(435, 708));
    _eye(canvas, const Offset(724, 695));
    final mouth = Path()
      ..moveTo(550, 758)
      ..quadraticBezierTo(
        589,
        expression == PlushExpression.happy ? 788 : 779,
        624,
        751,
      );
    canvas.drawPath(
      mouth,
      Paint()
        ..color = _thread
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8,
    );
    for (var i = 0; i < 7; i++) {
      final x = 558.0 + i * 9;
      canvas.drawLine(
        Offset(x, 761),
        Offset(x + 1, 767),
        Paint()
          ..color = const Color(0xFF805331).withValues(alpha: .45)
          ..strokeWidth = 1.4,
      );
    }
    _growth(canvas);
  }

  void _eye(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = _thread
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    if (expression == PlushExpression.happy || eyeOpen < .12) {
      final curve = expression == PlushExpression.happy ? -25.0 : 18.0;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - 22, center.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy + curve,
            center.dx + 22,
            center.dy,
          ),
        paint,
      );
      return;
    }
    final eye = Rect.fromCenter(
      center: center,
      width: 43,
      height: 57 * eyeOpen,
    );
    canvas.drawOval(eye, paint..style = PaintingStyle.fill);
    canvas.save();
    canvas.clipPath(Path()..addOval(eye.deflate(3)));
    for (var y = eye.top; y < eye.bottom; y += 5) {
      canvas.drawLine(
        Offset(eye.left, y + 3),
        Offset(eye.right, y - 3),
        Paint()
          ..color = const Color(0xFF966234).withValues(alpha: .43)
          ..strokeWidth = 1.8,
      );
    }
    canvas.restore();
  }

  void _growth(Canvas canvas) {
    if (stage == DecorationStage.none || stage == DecorationStage.sprout) {
      return;
    }
    final stem = Paint()
      ..color = const Color(0xFF7C865C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    if (stage == DecorationStage.leaf) {
      canvas.drawLine(
        const Offset(480, 261),
        const Offset(496, 270),
        stem..strokeWidth = 4,
      );
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(492, 269)
        ..quadraticBezierTo(472, 233, 437, 216),
      stem,
    );
    if (stage == DecorationStage.bud) {
      _petal(canvas, const Offset(437, 207), const Size(31, 43));
      return;
    }
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(437, 207);
      canvas.rotate(i * math.pi * 2 / 5);
      _petal(canvas, const Offset(0, -19), const Size(28, 36));
      canvas.restore();
    }
    canvas.drawCircle(
      const Offset(437, 207),
      10,
      Paint()..color = const Color(0xFFD5AA65),
    );
  }

  void _petal(Canvas canvas, Offset center, Size size) {
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.6),
          colors: [Color(0xFFE9B5A5), Color(0xFFC58E82)],
        ).createShader(rect),
    );
    canvas.drawLine(
      center + Offset(0, -size.height * .26),
      center + Offset(0, size.height * .25),
      Paint()
        ..color = const Color(0xFFF2D4C9)
        ..strokeWidth = 1.7,
    );
  }

  @override
  bool shouldRepaint(_StitchesPainter old) =>
      expression != old.expression ||
      eyeOpen != old.eyeOpen ||
      stage != old.stage;
}
