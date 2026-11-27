import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../payments/domain/card_brand.dart';
import '../../payments/domain/card_checks.dart';
import '../../payments/domain/payment_card.dart';
import '../../payments/presentation/cards/mini_card.dart';
import 'reduce_animations_cubit.dart';

// Keep in step with "version" in pubspec.yaml.
const String appVersion = '1.0.0';

// Turns animations off for the whole app when the in-app switch is on.
// The phone setting still works too: either one turns them off.
class ReduceAnimationsScope extends StatelessWidget {
  const ReduceAnimationsScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReduceAnimationsCubit, bool>(
      builder: (context, reduce) {
        if (!reduce) return child;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child,
        );
      },
    );
  }
}

// A demo card number and what it does.
class _TestCard {
  const _TestCard(this.number, this.note);

  final String number;
  final String note;

  // Only for the mini card picture. It is never saved.
  PaymentCard get asPaymentCard => PaymentCard(
        brand: CardChecks.brandOf(number) ?? CardBrand.visa,
        last4: CardChecks.last4Of(number),
        holderName: '',
        expMonth: 1,
        expYear: 2030,
      );
}

const _testCards = [
  _TestCard('4242 4242 4242 4242', 'Visa, works'),
  _TestCard('4111 1111 1111 1111', 'Visa, works'),
  _TestCard('5555 5555 5555 4444', 'Mastercard, works'),
  _TestCard('5105 1051 0510 5100', 'Mastercard, works'),
  _TestCard('4000 0000 0000 0002', 'Visa, always fails'),
];

// App settings: Reduce animations, demo test cards, and About.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionTitle('Display'),
          _SettingsCard(
            child: BlocBuilder<ReduceAnimationsCubit, bool>(
              builder: (context, reduce) => SwitchListTile(
                contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                secondary: const SectionIcon(
                  icon: Icons.motion_photos_off_rounded,
                ),
                title: const Text(
                  'Reduce animations',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Turns off most moving effects.'),
                value: reduce,
                onChanged: context.read<ReduceAnimationsCubit>().set,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Test cards (demo)'),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Text(
                    'Tap a number to copy it. Use any name, a future date, '
                    'and any 3-digit CVV.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                for (final card in _testCards) _TestCardRow(card: card),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Notifications'),
          const _SettingsCard(
            child: ListTile(
              enabled: false,
              contentPadding: EdgeInsets.fromLTRB(14, 4, 14, 4),
              leading: _SoftIcon(icon: Icons.notifications_rounded),
              title: Text('Order notifications'),
              trailing: _ComingSoon(),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('About'),
          const _SettingsCard(child: _AboutPart()),
        ],
      ),
    );
  }
}

// A white card with a thin border that holds one part of the page.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

// A soft orange icon square, for a part that is not ready yet.
class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppTheme.softOrange,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: AppTheme.brandOrange, size: 18),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Coming soon',
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TestCardRow extends StatelessWidget {
  const _TestCardRow({required this.card});

  final _TestCard card;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: card.number));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Copied ${card.number}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final fails = card.number.endsWith('0002');

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      leading: MiniCard(card: card.asPaymentCard),
      title: Text(
        card.number,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        card.note,
        style: TextStyle(
          color: fails ? AppTheme.dangerRed : AppTheme.textMuted,
        ),
      ),
      trailing: const Icon(
        Icons.copy_rounded,
        size: 20,
        color: AppTheme.brandOrange,
      ),
      onTap: () => _copy(context),
    );
  }
}

class _AboutPart extends StatelessWidget {
  const _AboutPart();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const grey = AppTheme.textMuted;
    final logo = Image.asset('assets/images/logo.png', height: 64);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          logo,
          const SizedBox(height: 8),
          Text(
            'Ada Rasa',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'Version $appVersion',
            style: textTheme.bodyMedium?.copyWith(color: grey),
          ),
          const SizedBox(height: 12),
          const Text(
            'A food delivery app prototype. Demo only, no real payments.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Built with Flutter and Firebase.',
            textAlign: TextAlign.center,
            style: TextStyle(color: grey),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.deepOrange,
              backgroundColor: AppTheme.softOrange,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Ada Rasa',
              applicationVersion: appVersion,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/images/logo.png', height: 48),
              ),
            ),
            icon: const Icon(Icons.description_rounded),
            label: const Text('Open source licences'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}