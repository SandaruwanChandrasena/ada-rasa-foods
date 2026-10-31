import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/fade_slide_in.dart';

// Shown while AuthCubit checks for a saved login.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The logo fades in and grows a little, then the spinner shows.
            FadeSlideIn(
              duration: const Duration(milliseconds: 700),
              offset: Offset.zero,
              scaleFrom: 0.85,
              child: Image.asset(
                'assets/images/logo.png',
                width: 160,
                height: 160,
              ),
            ),
            const SizedBox(height: 32),
            const FadeSlideIn(
              delay: Duration(milliseconds: 400),
              child: CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}