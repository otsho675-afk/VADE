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

  Widget _sectionHeading(BuildContext context, IconData icon,
    String title, String subtitle) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Container(width: 43, height: 43,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, size: 23, color: scheme.primary)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      ])),
    ]);
  }

  Widget _formLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700)),
  );

  Widget _formHint(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: scheme.primary.withValues(alpha: .07)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: scheme.primary, size: 19),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: TextStyle(
          color: scheme.onSurfaceVariant, fontSize: 12, height: 1.45))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.editing != null;
    final scheme = theme.colorScheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Ödemeyi düzenle' : 'Yeni ödeme ekle',
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const KeyboardDoneBar(),
        if (!keyboardOpen) SafeArea(top: false, child: Container(
          decoration: BoxDecoration(color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant))),
          padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: SizedBox(width: double.infinity, height: 54,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                  : const Icon(Icons.check_rounded),
                label: Text(editing ? 'Değişiklikleri kaydet' : 'Ödeme planını oluştur'),
              ),
            ),
          )),
        )),
      ]),
      body: SafeArea(bottom: false, child: Form(
        key: _formKey,
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.fromLTRB(16, 16, 16, 26), children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF163B47), Color(0xFF0D766F)]),
                borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                const Icon(Icons.add_card_rounded, color: Colors.white, size: 29),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(editing ? 'Planını güncelle' : 'Yeni bir plan oluştur',
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Tutarı ve vadeyi ekle; ödemelerini tek yerden takip et.',
                    style: TextStyle(color: Color(0xFFD4F3EB), fontSize: 12, height: 1.4)),
                ])),
              ]),
            ),
            const SizedBox(height: 22),
            Text('Ödeme türü', style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Oluşturmak istediğiniz ödeme planını seçin.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth >= 610 ? 4 : 2;
              const gap = 9.0;
              final width = (box.maxWidth - (columns - 1) * gap) / columns;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final kind in PaymentKind.values)
                  SizedBox(width: width, child: Semantics(
                    selected: _kind == kind, button: true,
                    child: Material(color: Colors.transparent, child: InkWell(
                      onTap: editing ? null : () => setState(() => _kind = kind),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 55,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: _kind == kind ? scheme.primary.withValues(alpha: .12) : scheme.surface,
                          border: Border.all(color: _kind == kind
                            ? scheme.primary.withValues(alpha: .45) : scheme.outlineVariant),
                        ),
                        child: Row(children: [
                          Icon(kind.icon, size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(kind.label, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5,
                              fontWeight: _kind == kind ? FontWeight.w800 : FontWeight.w600))),
                        ]),
                      ),
                    )),
                  )),
              ]);
            }),
            const SizedBox(height: 24),
            if (!editing) ...[
              Text('İşlem yönü', style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Bu kayıt borç mu, alacak mı?',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 11),
              Container(padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                  color: scheme.surface, border: Border.all(color: scheme.outlineVariant)),
                child: Row(children: [
                  for (final direction in PaymentDirection.values)
                    Expanded(child: Material(color: Colors.transparent, child: InkWell(
                      onTap: () => setState(() => _direction = direction),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _direction == direction ? scheme.primary : Colors.transparent),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_direction == direction ? Icons.check_circle_rounded
                            : direction == PaymentDirection.outgoing
                              ? Icons.north_east_rounded : Icons.south_west_rounded,
                            size: 17, color: _direction == direction
                              ? scheme.onPrimary : scheme.onSurfaceVariant),
                          const SizedBox(width: 7),
                          Flexible(child: Text(direction == PaymentDirection.outgoing
                            ? 'Ödeyeceğim' : 'Alacağım', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700,
                              color: _direction == direction ? scheme.onPrimary : scheme.onSurface))),
                        ]),
                      ),
                    ))),
                ]),
              ),
              const SizedBox(height: 23),
            ],
            Card(child: Padding(padding: const EdgeInsets.all(19), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionHeading(context, Icons.receipt_long_outlined,
                  'Ödeme bilgileri', 'Planınızın temel bilgilerini girin.'),
                const SizedBox(height: 22),
                if (_kind == PaymentKind.invoice) ...[
                  DropdownButtonFormField<InvoiceCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Fatura kategorisi',
                      prefixIcon: Icon(Icons.category_outlined)),
                    items: [for (final c in InvoiceCategory.values) DropdownMenuItem(value: c,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(c.icon, size: 18), const SizedBox(width: 8), Text(c.label)]))],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 14),
                ],
                _formLabel(context, 'Ödeme adı *'),
                TextFormField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.description_outlined),
                    hintText: _kind == PaymentKind.invoice
                      ? 'Örn. Ev elektrik faturası' : 'Örn. Telefon taksiti'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Ödeme adı girin.' : null,
                ),
                const SizedBox(height: 14),
                _formLabel(context, 'Tutar (TL) *'),
                TextFormField(controller: _amount,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')), LengthLimitingTextInputFormatter(20)],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.currency_lira_rounded),
                    hintText: '1.250,00'),
                  validator: (v) {
                    final cents = parseMoneyToCents(v ?? '');
                    return cents == null || cents <= 0 ? 'Geçerli, sıfırdan büyük bir tutar girin.' : null;
                  }),
                if (_kind == PaymentKind.installment) ...[
                  const SizedBox(height: 14),
                  _formLabel(context, 'Toplam taksit sayısı *'),
                  TextFormField(controller: _count,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    enabled: !editing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.layers_outlined), hintText: 'Örn. 12'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 240 ? '1 ile 240 arasında taksit sayısı girin.' : null;
                    }),
                ],
                if (!editing) ...[
                  const SizedBox(height: 14),
                  _formLabel(context, 'İlk son ödeme tarihi'),
                  Material(
                    color: scheme.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      key: const Key('payment-date-picker'),
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [
                        Icon(Icons.calendar_month_outlined, color: scheme.primary, size: 23),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('İlk son ödeme tarihi', style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 3),
                          Text(formatDate(_dueDate), style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: scheme.primary),
                      ])),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _formHint(context,
                    _kind == PaymentKind.installment
                      ? 'Her ay aynı gün için ${_count.text} taksit planlanır. Ayda o gün yoksa ayın son günü kullanılır.'
                      : _kind.isRecurring
                        ? 'Ödendi olarak işaretlediğinizde gelecek ayın ödemesi otomatik oluşturulur.'
                        : 'Bu ödeme tek seferlik olarak oluşturulur.',
                  ),
                ],
              ],
            ))),
            const SizedBox(height: 14),
            Card(child: Padding(padding: const EdgeInsets.all(19), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionHeading(context, Icons.account_balance_outlined,
                  'Kişi ve havale bilgileri', 'Ödeme detayında tek dokunuşla kopyalayın.'),
                const SizedBox(height: 22),
                _formLabel(context, _direction == PaymentDirection.outgoing
                  ? 'Alıcı / kurum adı (isteğe bağlı)'
                  : 'Kişi / kurum adı (isteğe bağlı)'),
                TextFormField(controller: _party, maxLength: 200,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    hintText: 'Örn. Ahmet Yılmaz veya kurum adı')),
                const SizedBox(height: 14),
                _formLabel(context, 'Alıcı IBAN (isteğe bağlı)'),
                TextFormField(
                  controller: _iban,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autocorrect: false, enableSuggestions: false,
                  inputFormatters: [IbanInputFormatter()],
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_outlined),
                    hintText: 'TR00 0000 0000 0000 0000 0000 00'),
                  validator: (v) => isValidIban(v ?? '') ? null : 'Geçerli bir Türkiye IBAN bilgisi girin.',
                ),
                const SizedBox(height: 10),
                _formHint(context, 'İsim ve IBAN ödeme detayında ayrı ayrı veya birlikte kopyalanabilir.'),
                const SizedBox(height: 14),
                _formLabel(context, 'Açıklama (isteğe bağlı)'),
                TextFormField(controller: _notes,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.notes_outlined),
                    hintText: 'Ödeme hakkında notlarınız')),
              ],
            ))),
            if (editing) ...[
              const SizedBox(height: 12),
              Text('Düzenleme sırasında mevcut taksit sayısı ve tarih planı korunur. Yeni tutar yalnızca ödenmemiş kayıtlara uygulanır.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
            const SizedBox(height: 16),
          ]),
        )),
      )),
    );
  }
}
