import 'package:material_ui/material_ui.dart';

// Top part of the sign in and sign up screens: a food photo in the top
// right corner that fades into white, with the title on top of it.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.imagePath,
    required this.child,
    this.topLeft,
    this.height = 280,
  });

  final String imagePath;
  final Widget child;
  final Widget? topLeft;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            width: width * 0.7,
            height: height * 0.85,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const RadialGradient(
                center: Alignment.topRight,
                radius: 1.1,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.45, 1],
              ).createShader(rect),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
          if (topLeft != null)
            Positioned(top: 8, left: 16, child: topLeft!),
          Positioned(left: 24, right: 24, bottom: 0, child: child),
        ],
      ),
    );
  }
}