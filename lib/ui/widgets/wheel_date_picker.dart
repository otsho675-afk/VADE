import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<DateTime?> showWheelDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Tarih seç',
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  var selected = DateTime(initialDate.year, initialDate.month, initialDate.day);
  if (selected.isBefore(first)) selected = first;
  if (selected.isAfter(last)) selected = last;
  return showModalBottomSheet<DateTime>(
    context: context, isScrollControlled: true, showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SizedBox(
        height: 330,
        child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              TextButton(onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Vazgeç')),
              Expanded(child: Text(helpText, textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleMedium)),
              TextButton(onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(sheetContext, selected);
              }, child: const Text('Tamam')),
            ])),
          Expanded(child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(sheetContext).brightness,
              primaryColor: Theme.of(sheetContext).colorScheme.primary,
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              dateOrder: DatePickerDateOrder.dmy,
              initialDateTime: selected,
              minimumDate: first, maximumDate: last,
              minimumYear: first.year, maximumYear: last.year,
              onDateTimeChanged: (value) {
                selected = DateTime(value.year, value.month, value.day);
              },
            ),
          )),
        ]),
      ),
    ),
  );
}

Future<int?> showWheelHourPicker(BuildContext context, int initialHour) {
  var hour = initialHour.clamp(0, 23);
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<int>(
    context: context, showDragHandle: true, useSafeArea: true,
    builder: (sheetContext) => SafeArea(top: false, child: SizedBox(
      height: 300,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Vazgeç')),
          const Text('Bildirim saati'),
          TextButton(onPressed: () => Navigator.pop(sheetContext, hour), child: const Text('Tamam')),
        ]),
        Expanded(child: CupertinoTheme(
          data: CupertinoThemeData(brightness: Theme.of(sheetContext).brightness),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time, use24hFormat: true, minuteInterval: 60,
            initialDateTime: DateTime(2026, 1, 1, hour),
            onDateTimeChanged: (value) => hour = value.hour,
          ),
        )),
      ]),
    )),
  );
}
