import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/premium_service.dart';

/// Unlock screen: ONE-TIME \$3.99. No monthly subscription, no hidden
/// charges — the price is stated plainly, as the plan requires.
///
/// Phase 1: the purchase button is a placeholder — Phase 2 wires it to
/// Google Play in-app purchase. The restore button already exists and is
/// wired to [PremiumService.restorePurchases].
class UnlockScreen extends StatelessWidget {
  const UnlockScreen({super.key});

  static const String priceLabel = '\$3.99';

  static const List<String> benefits = [
    'All 8 breathing patterns, including Triangle, Coherent and Energizing',
    'Custom pattern — set your own timings',
    'All background sounds, including Ocean',
    'Sleep mode — session continues with the screen off',
    'Home-screen widget — one tap starts your favourite session',
    'Bedtime reminder at your chosen time',
    'Full streak history, day by day',
    'No ads, ever (when ads arrive in Phase 2)',
  ];

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Premium')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Unlock everything',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              priceLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent),
            ),
            const Text(
              'One-time payment. Yours forever.\nNo monthly subscription. No hidden charges.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ...benefits.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, color: Colors.tealAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(b, style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                )),
            const Spacer(),
            if (premium.isPremium)
              const FilledButton(
                onPressed: null,
                child: Text('Premium already unlocked — thank you!'),
              )
            else
              FilledButton(
                onPressed: () {
                  // TODO(phase-2): launch Google Play one-time purchase
                  // via in_app_purchase, then premium.unlock() on success.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Purchase arrives in Phase 2 with Google Play billing.'),
                    ),
                  );
                },
                child: Text('Unlock for $priceLabel — one time'),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final restored = await premium.restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(restored
                          ? 'Premium restored. Thank you!'
                          : 'No purchase found yet. In-app purchase arrives in Phase 2.'),
                    ),
                  );
                }
              },
              child: const Text('Restore purchase'),
            ),
          ],
        ),
      ),
    );
  }
}
