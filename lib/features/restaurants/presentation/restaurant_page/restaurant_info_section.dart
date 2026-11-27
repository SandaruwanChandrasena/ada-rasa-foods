import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/open_status_chip.dart';
import '../../../auth/domain/phone_checks.dart';
import '../../domain/restaurant.dart';

// Opens the phone app. Gives false if it could not open.
Future<bool> dialShop(String phone) async {
  try {
    return await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    return false;
  }
}

// The shop name, open chip, description, cuisine, address and phone
// on the customer restaurant page (CUS-2).
class RestaurantInfoSection extends StatelessWidget {
  const RestaurantInfoSection({
    super.key,
    required this.restaurant,
    this.callPhone = dialShop,
  });

  static const closedText = 'Closed now. You can still see the menu.';

  final Restaurant restaurant;

  // Tests give a fake, so no real phone app opens.
  final Future<bool> Function(String phone) callPhone;

  @override
  Widget build(BuildContext context) {
    final open = restaurant.canTakeOrders;
    final description = restaurant.description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OpenStatusChip(isOpen: open),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.restaurant_menu_rounded,
            text: restaurant.cuisine,
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.location_on_rounded,
            text: restaurant.address,
          ),
          // Shown even when closed, so a customer can ask when it opens.
          if (restaurant.hasPhone) ...[
            const SizedBox(height: 6),
            _InfoLine(
              icon: Icons.phone_rounded,
              text: PhoneChecks.format(restaurant.phone),
              trailing: _CallPill(onTap: () => _call(context)),
            ),
          ],
          if (!open) ...[
            const SizedBox(height: 12),
            const Text(
              closedText,
              style: TextStyle(
                color: AppTheme.dangerRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Divider(height: 28),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await callPhone(restaurant.phone);
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the phone app.')),
        );
    }
  }
}

// An orange icon with grey text, like on the Home cards.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final end = trailing;

    return Row(
      crossAxisAlignment:
          end == null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.brandOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppTheme.textMuted)),
        ),
        if (end != null) ...[
          const SizedBox(width: 8),
          end,
        ],
      ],
    );
  }
}

// A soft orange "Call" pill that opens the phone app.
class _CallPill extends StatelessWidget {
  const _CallPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('call-shop-button'),
      color: AppTheme.softOrange,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_rounded,
                size: 18,
                color: AppTheme.deepOrange,
              ),
              SizedBox(width: 6),
              Text(
                'Call',
                style: TextStyle(
                  color: AppTheme.deepOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}