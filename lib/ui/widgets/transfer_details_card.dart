import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common.dart';

/// Keeps transfer details together and makes each value a full-size copy target.
class TransferDetailsCard extends StatelessWidget {
  final String party;
  final String iban;

  const TransferDetailsCard({
    super.key,
    required this.party,
    required this.iban,
  });

  Future<void> _copy(BuildContext context, String value, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {
        // Clipboard success must not depend on haptic support.
      }
      if (context.mounted) showSuccess(context, message);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = party.trim();
    final account = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (name.isEmpty && account.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final groupedIban = account
        .replaceAllMapped(RegExp(r'.{1,4}'), (match) => '${match.group(0)} ')
        .trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.account_balance_outlined,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Havale bilgileri',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kopyalamak için bilgiye dokunun',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (name.isNotEmpty) ...[
              _CopyTile(
                label: 'KİŞİ / KURUM',
                value: name,
                semanticsLabel: 'Kişi veya kurum adını kopyala',
                onTap: () => _copy(context, name, 'İsim kopyalandı.'),
              ),
              if (account.isNotEmpty) const SizedBox(height: 9),
            ],
            if (account.isNotEmpty)
              _CopyTile(
                label: 'IBAN',
                value: groupedIban,
                semanticsLabel: 'IBAN kopyala',
                onTap: () => _copy(context, account, 'IBAN kopyalandı.'),
              ),
            if (name.isNotEmpty && account.isNotEmpty) ...[
              const SizedBox(height: 13),
              OutlinedButton.icon(
                onPressed: () => _copy(
                  context,
                  'Kişi / Kurum: $name\nIBAN: $account',
                  'İsim ve IBAN birlikte kopyalandı.',
                ),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('İsim ve IBAN’ı birlikte kopyala'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyTile extends StatelessWidget {
  final String label;
  final String value;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _CopyTile({
    required this.label,
    required this.value,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: scheme.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              height: 1.4,
                              letterSpacing: label == 'IBAN' ? .4 : 0,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.copy_rounded, color: scheme.primary, size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
