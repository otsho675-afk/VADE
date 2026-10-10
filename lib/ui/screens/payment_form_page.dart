import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/payment.dart';
import '../../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/wheel_date_picker.dart';
import '../widgets/smart_keyboard.dart';

class PaymentFormPage extends StatefulWidget {
  final AppStore store;
  final PaymentPlan? editing;
  const PaymentFormPage({super.key, required this.store, this.editing});
  @override
  State<PaymentFormPage> createState() => _PaymentFormPageState();
}

class _PaymentFormPageState extends State<PaymentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _party = TextEditingController();
  final _iban = TextEditingController();
  final _amount = TextEditingController();
  final _count = TextEditingController(text: '6');
  final _notes = TextEditingController();
  PaymentKind _kind = PaymentKind.installment;
  PaymentDirection _direction = PaymentDirection.outgoing;
  InvoiceCategory _category = InvoiceCategory.electricity;
  DateTime _dueDate = dateOnly(DateTime.now().add(const Duration(days: 7)));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.editing;
    if (p != null) {
      _title.text = p.title;
      _party.text = p.party;
      _iban.text = p.iban;
      _amount.text = (p.amountCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      _count.text = p.count.toString();
      _notes.text = p.note;
      _kind = p.kind;
      _direction = p.direction;
      _category = p.category;
      _dueDate = p.startDate;
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _party, _iban, _amount, _count, _notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showWheelDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _dueDate,
      helpText: 'İlk ödeme tarihini seç',
    );
    if (date != null && mounted) setState(() => _dueDate = date);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final count = _kind == PaymentKind.installment ? int.parse(_count.text) : 1;
    final draft = PlanDraft(
      title: _title.text.trim(), party: _party.text.trim(),
      iban: _iban.text.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase(),
      note: _notes.text.trim(), kind: _kind, direction: _direction,
      category: _category, amountCents: parseMoneyToCents(_amount.text)!,
      count: count, startDate: _dueDate,
    );
    setState(() => _saving = true);
    try {
      if (widget.editing == null) {
        await widget.store.add(draft);
      } else {
        await widget.store.edit(widget.editing!, draft);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.editing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Ödemeyi düzenle' : 'Yeni ödeme ekle')),
      bottomNavigationBar: const KeyboardDoneBar(),
      body: SafeArea(child: Form(
        key: _formKey,
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.fromLTRB(18, 16, 18, 34), children: [
            Text('Ödeme türü', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final kind in PaymentKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  avatar: Icon(kind.icon, size: 17),
                  selected: _kind == kind,
                  onSelected: editing ? null : (_) => setState(() => _kind = kind),
                ),
            ]),
            const SizedBox(height: 16),
            if (!editing) ...[
              Text('İşlem yönü', style: theme.textTheme.titleMedium),
              const SizedBox(height: 7),
              SegmentedButton<PaymentDirection>(
                segments: const [
                  ButtonSegment(value: PaymentDirection.outgoing, icon: Icon(Icons.north_east), label: Text('Ödeyeceğim')),
                  ButtonSegment(value: PaymentDirection.incoming, icon: Icon(Icons.south_west), label: Text('Alacağım')),
                ],
                selected: {_direction},
                onSelectionChanged: (v) => setState(() => _direction = v.first),
              ),
              const SizedBox(height: 17),
            ],
            Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ödeme bilgileri', style: theme.textTheme.titleMedium),
                const SizedBox(height: 15),
                if (_kind == PaymentKind.invoice) ...[
                  DropdownButtonFormField<InvoiceCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Fatura kategorisi'),
                    items: [for (final c in InvoiceCategory.values) DropdownMenuItem(value: c,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(c.icon, size: 18), const SizedBox(width: 8), Text(c.label)]))],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Ödeme adı *',
                    hintText: _kind == PaymentKind.invoice ? 'Örn. Ev elektrik faturası' : 'Örn. Telefon taksiti'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Ödeme adı girin.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(controller: _party, maxLength: 200,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _direction == PaymentDirection.outgoing ? 'Kime / hangi kuruma?' : 'Kimden alacağım?',
                    hintText: 'Örn. Ahmet Yılmaz veya kurum adı')),
                const SizedBox(height: 14),
                TextFormField(controller: _amount,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')), LengthLimitingTextInputFormatter(20)],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tutar (TL) *', prefixText: '₺  ', hintText: '1.250,00'),
                  validator: (v) {
                    final cents = parseMoneyToCents(v ?? '');
                    return cents == null || cents <= 0 ? 'Geçerli, sıfırdan büyük bir tutar girin.' : null;
                  }),
                if (_kind == PaymentKind.installment) ...[
                  const SizedBox(height: 14),
                  TextFormField(controller: _count,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    enabled: !editing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    decoration: const InputDecoration(labelText: 'Toplam taksit sayısı *', hintText: 'Örn. 12'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 240 ? '1 ile 240 arasında taksit sayısı girin.' : null;
                    }),
                ],
                if (!editing) ...[
                  const SizedBox(height: 14),
                  Card(child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('İlk son ödeme tarihi'),
                    subtitle: Text(formatDate(_dueDate)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickDate,
                  )),
                  const SizedBox(height: 8),
                  Text(
                    _kind == PaymentKind.installment
                      ? 'Her ay aynı gün için ${_count.text} taksit planlanır. Ayda o gün yoksa ayın son günü kullanılır.'
                      : _kind.isRecurring
                        ? 'Ödendi olarak işaretlediğinizde gelecek ayın ödemesi otomatik oluşturulur.'
                        : 'Bu ödeme tek seferlik olarak oluşturulur.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ],
            ))),
            const SizedBox(height: 14),
            Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Havale bilgileri ve not', style: theme.textTheme.titleMedium),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _iban,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autocorrect: false, enableSuggestions: false,
                  inputFormatters: [IbanInputFormatter()],
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Alıcı IBAN (isteğe bağlı)', hintText: 'TR...'),
                  validator: (v) => isValidIban(v ?? '') ? null : 'Geçerli bir Türkiye IBAN bilgisi girin.',
                ),
                const SizedBox(height: 14),
                TextFormField(controller: _notes,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  maxLength: 5000,
                  decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)', hintText: 'Ödeme hakkında notlarınız')),
              ],
            ))),
            if (editing) ...[
              const SizedBox(height: 12),
              Text('Düzenleme sırasında mevcut taksit sayısı ve tarih planı korunur. Yeni tutar yalnızca ödenmemiş kayıtlara uygulanır.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
              label: Text(editing ? 'Değişiklikleri kaydet' : 'Ödeme planını oluştur')),
            const SizedBox(height: 8),
          ]),
        )),
      )),
    );
  }
}
