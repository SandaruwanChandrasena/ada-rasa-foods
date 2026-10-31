import 'package:material_ui/material_ui.dart';

import '../domain/card_brand.dart';

// Card pictures drawn in code, so they work offline with no image files.

// Dark card with a soft orange glow, in the Ada Rasa colors.
class CardBackground extends StatelessWidget {
  const CardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2C3A), Color(0xFF16171F)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Orange glow at the top right.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1.0, -1.1),
                radius: 1.1,
                colors: [Color(0x8CFF5000), Color(0x00FF5000)],
              ),
            ),
          ),
          // A softer glow at the bottom left.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1.1, 1.2),
                radius: 0.9,
                colors: [Color(0x40FF8A3D), Color(0x00FF8A3D)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A small gold chip.
class CardChip extends StatelessWidget {
  const CardChip({super.key, this.width = 52});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.75),
      painter: _ChipPainter(),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height * 0.2),
    );

    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6DD8E), Color(0xFFC79A3E)],
        ).createShader(rect),
    );

    // The thin lines of a real chip.
    final line = Paint()
      ..color = const Color(0x99916A1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), line);
    canvas.drawLine(Offset(0, h * 2 / 3), Offset(w, h * 2 / 3), line);
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h / 3), line);
    canvas.drawLine(Offset(w / 2, h * 2 / 3), Offset(w / 2, h), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, h * 0.25, w * 0.4, h * 0.5),
        Radius.circular(h * 0.12),
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) => false;
}

// Visa or Mastercard logo. Nothing for an unknown card.
class CardBrandLogo extends StatelessWidget {
  const CardBrandLogo({
    super.key,
    required this.brand,
    this.height = 40,
    this.visaColor = Colors.white,
  });

  final CardBrand? brand;
  final double height;

  // White on the dark card. A list on white can pass a dark color.
  final Color visaColor;

  @override
  Widget build(BuildContext context) {
    return switch (brand) {
      CardBrand.visa => Text(
          'VISA',
          softWrap: false,
          style: TextStyle(
            color: visaColor,
            fontSize: height * 0.72,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
            height: 1,
          ),
        ),
      CardBrand.mastercard => CustomPaint(
          size: Size(height * 1.6, height),
          painter: _MastercardPainter(),
        ),
      null => const SizedBox.shrink(),
    };
  }
}

// Two circles: red, yellow, and orange where they cross.
class _MastercardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final left = Rect.fromCircle(center: Offset(r, r), radius: r);
    final right = Rect.fromCircle(
      center: Offset(size.width - r, r),
      radius: r,
    );

    canvas.drawOval(left, Paint()..color = const Color(0xFFEB001B));
    canvas.drawOval(right, Paint()..color = const Color(0xFFF79E1B));

    final middle = Path.combine(
      PathOperation.intersect,
      Path()..addOval(left),
      Path()..addOval(right),
    );
    canvas.drawPath(middle, Paint()..color = const Color(0xFFFF5F00));
  }

  @override
  bool shouldRepaint(_MastercardPainter oldDelegate) => false;
}