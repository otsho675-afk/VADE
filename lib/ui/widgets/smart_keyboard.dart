import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom == 0) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(height: 44, child: Row(children: [
        const SizedBox(width: 12),
        IconButton(tooltip: 'Önceki alan', onPressed: () => FocusScope.of(context).previousFocus(),
          icon: const Icon(Icons.keyboard_arrow_up)),
        IconButton(tooltip: 'Sonraki alan', onPressed: () => FocusScope.of(context).nextFocus(),
          icon: const Icon(Icons.keyboard_arrow_down)),
        const Spacer(),
        TextButton(onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: const Text('Bitti')),
        const SizedBox(width: 12),
      ])),
    );
  }
}

class IbanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) return newValue;
    final raw = newValue.text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (raw.length > 26) return oldValue;
    final prefix = newValue.text.substring(0, newValue.selection.extentOffset.clamp(0, newValue.text.length))
        .toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    final formatted = [for (var i = 0; i < raw.length; i += 4)
      raw.substring(i, (i + 4).clamp(0, raw.length))].join(' ');
    final cursor = prefix.isEmpty ? 0 : (prefix.length + (prefix.length - 1) ~/ 4).clamp(0, formatted.length);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: cursor));
  }
}
