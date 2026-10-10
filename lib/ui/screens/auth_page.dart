import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/cloud_config.dart';
import '../../state/app_store.dart';
import '../widgets/brand_mark.dart';
import '../widgets/smart_keyboard.dart';

class AuthPage extends StatefulWidget {
  final AppStore store;
  final bool register;
  const AuthPage({super.key, required this.store, this.register = false});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  late bool _register = widget.register;
  bool _hidden = true, _busy = false, _consent = false;
  String? _message;
  bool _messageIsError = true;

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'E-posta adresini kontrol et.',
        'weak-password' => 'Daha güçlü bir şifre seç. En az 6 karakter kullan.',
        'email-already-in-use' => 'Bu e-posta zaten kayıtlı. Giriş yapabilir veya şifreni yenileyebilirsin.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'E-posta veya şifre doğru değil.',
        'network-request-failed' => 'İnternet bağlantını kontrol edip tekrar dene.',
        'too-many-requests' => 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.',
        'operation-not-allowed' => 'E-posta ile giriş şu anda kullanılamıyor.',
        'user-disabled' => 'Bu hesabın erişimi kapatılmış.',
        _ => 'Hesap işlemi tamamlanamadı. Lütfen tekrar dene.',
      };
    }
    return 'Hesap hizmetine ulaşılamadı. Biraz sonra tekrar dene.';
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return 'Geçerli bir e-posta adresi gir.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_register && !_consent) {
      setState(() { _message = 'Devam etmek için hesap verileri bilgilendirmesini onayla.'; _messageIsError = true; });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _busy = true; _message = null; });
    try {
      await widget.store.cloud.signIn(_email.text, _password.text, register: _register);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() { _message = _friendlyError(error); _messageIsError = true; });
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _reset() async {
    final error = _validateEmail(_email.text);
    if (error != null) {
      setState(() { _message = 'Şifreni yenilemek için önce e-posta adresini gir.'; _messageIsError = true; });
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await widget.store.cloud.resetPassword(_email.text);
      if (mounted) setState(() {
        _message = 'Adresin uygunsa şifre yenileme e-postası gönderilir. Gelen kutunu ve spam klasörünü kontrol et.';
        _messageIsError = false;
      });
    } catch (error) {
      if (mounted) setState(() { _message = _friendlyError(error); _messageIsError = true; });
    } finally { if (mounted) setState(() => _busy = false); }
  }

  void _privacy() => showDialog<void>(context: context, builder: (dialogContext) =>
    AlertDialog(title: const Text('Hesap verileri hakkında'),
      content: const SingleChildScrollView(child: Text(
        'Hesap açtığında e-posta adresin, kullanıcı kimliğin ve son görülme bilgin Firebase üzerinde tutulur. '
        'Uygulama açıkken çevrimiçi durumun yetkili yöneticiye görünür. '
        'Ödeme kayıtların cihazda kalır; yalnızca sen bulut yedeği istediğinde sunucuya aktarılır. '
        'Bulut yedekleri uçtan uca şifrelenmez. Duyuru bildirimleri ayrıca izin ister. '
        'Hesabını Hesabım bölümünden silebilirsin. Hesap silmek mağaza aboneliğini iptal etmez.')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Anladım'))],
    ));

  @override
  void dispose() { _email.dispose(); _password.dispose(); _repeat.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store.cloud,
    builder: (context, _) {
      final ready = widget.store.cloud.ready;
      return Scaffold(
        appBar: AppBar(title: const Text('VADESİ hesabı')),
        body: Column(children: [
          Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
            child: AutofillGroup(child: Form(key: _form,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 64)),
                  const SizedBox(height: 24),
                  Text(_register ? 'Birlikte başlayalım.' : 'Tekrar hoş geldin.',
                    style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(_register ? 'Hesabını oluştur, ödemelerini güvenle takip et.' :
                    'Hesabına giriş yap ve kaldığın yerden devam et.'),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Giriş yap')),
                      ButtonSegment(value: true, label: Text('Üye ol')),
                    ],
                    selected: {_register}, onSelectionChanged: _busy ? null : (selection) {
                      setState(() { _register = selection.first; _message = null; _repeat.clear(); });
                    },
                  ),
                  const SizedBox(height: 24),
                  if (!ready) ...[
                    Container(padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16)),
                      child: const Text('Hesap hizmetine şu anda bağlanılamıyor. Yerel ödeme takibini misafir olarak kullanabilirsin.')),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(controller: _email, enabled: !_busy,
                    keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false, enableSuggestions: false,
                    validator: _validateEmail,
                    decoration: const InputDecoration(labelText: 'E-posta', hintText: 'ornek@mail.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded))),
                  const SizedBox(height: 16),
                  TextFormField(controller: _password, enabled: !_busy,
                    obscureText: _hidden, autocorrect: false, enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                    autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                    onFieldSubmitted: (_) { if (!_register && ready) _submit(); },
                    validator: (value) => (value?.length ?? 0) < 6 ? 'En az 6 karakter gir.' : null,
                    decoration: InputDecoration(labelText: 'Şifre', prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(tooltip: _hidden ? 'Şifreyi göster' : 'Şifreyi gizle',
                        onPressed: () => setState(() => _hidden = !_hidden),
                        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                  if (_register) ...[
                    const SizedBox(height: 16),
                    TextFormField(controller: _repeat, enabled: !_busy,
                      obscureText: _hidden, autocorrect: false, enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword, textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) { if (ready) _submit(); },
                      validator: (value) => value != _password.text ? 'Şifreler eşleşmiyor.' : null,
                      decoration: const InputDecoration(labelText: 'Şifre tekrar',
                        prefixIcon: Icon(Icons.lock_reset_rounded))),
                    CheckboxListTile(contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Hesap verileri bilgilendirmesini okudum.'),
                      value: _consent, onChanged: _busy ? null : (value) => setState(() => _consent = value ?? false)),
                    Align(alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: _privacy, child: const Text('Bilgilendirmeyi oku'))),
                  ] else Align(alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _busy || !ready ? null : _reset, child: const Text('Şifremi unuttum'))),
                  if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(liveRegion: true, child: Text(_message!,
                      style: TextStyle(color: _messageIsError ? Theme.of(context).colorScheme.error :
                        Theme.of(context).colorScheme.primary)))),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _busy || !ready ? null : _submit,
                    child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) :
                      Text(_register ? 'Hesabımı oluştur' : 'Hesabıma giriş yap')),
                  if (CloudConfig.privacyUrl.startsWith('https://'))
                    TextButton(onPressed: () => launchUrl(Uri.parse(CloudConfig.privacyUrl)),
                      child: const Text('Gizlilik politikası')),
                  if (CloudConfig.termsUrl.startsWith('https://'))
                    TextButton(onPressed: () => launchUrl(Uri.parse(CloudConfig.termsUrl)),
                      child: const Text('Kullanım koşulları')),
                ]),
              ),
            )),
          ))),
          const KeyboardDoneBar(),
        ]),
      );
    },
  );
}
