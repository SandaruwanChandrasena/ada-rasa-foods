import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
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
          BlocBuilder<ReduceAnimationsCubit, bool>(
            builder: (context, reduce) => SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              secondary: const Icon(Icons.motion_photos_off_outlined),
              title: const Text('Reduce animations'),
              subtitle: const Text('Turns off most moving effects.'),
              value: reduce,
              onChanged: context.read<ReduceAnimationsCubit>().set,
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Test cards (demo)'),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              'Tap a number to copy it. Use any name, a future date, '
              'and any 3-digit CVV.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          for (final card in _testCards) _TestCardRow(card: card),
          const SizedBox(height: 16),
          const _SectionTitle('Notifications'),
          const ListTile(
            enabled: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(Icons.notifications_none_outlined),
            title: Text('Order notifications'),
            subtitle: Text('Coming soon'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('About'),
          const _AboutPart(),
        ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        Icons.credit_card,
        color: fails ? Colors.grey.shade500 : AppTheme.brandOrange,
      ),
      title: Text(
        card.number,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        card.note,
        style: TextStyle(
          color: fails ? Colors.red.shade700 : Colors.grey.shade600,
        ),
      ),
      trailing: const Icon(Icons.copy_rounded, size: 20),
      onTap: () => _copy(context),
    );
  }
}

class _AboutPart extends StatelessWidget {
  const _AboutPart();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grey = Colors.grey.shade600;
    final logo = Image.asset('assets/images/logo.png', height: 64);

    return Column(
      children: [
        const SizedBox(height: 8),
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
        Text(
          'Built with Flutter and Firebase.',
          textAlign: TextAlign.center,
          style: TextStyle(color: grey),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Ada Rasa',
            applicationVersion: appVersion,
            applicationIcon: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset('assets/images/logo.png', height: 48),
            ),
          ),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Open source licences'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}