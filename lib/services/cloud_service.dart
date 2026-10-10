import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'cloud_config.dart';

class CloudService extends ChangeNotifier with WidgetsBindingObserver {
  bool ready = false;
  bool _disposed = false;
  bool _foreground = true;
  String? error;
  User? user;
  int premiumUntilMillis = 0;
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _entitlement;
  StreamSubscription<DatabaseEvent>? _connected;
  DatabaseReference? _connection;
  int _session = 0;
  bool get premium => premiumUntilMillis > DateTime.now().millisecondsSinceEpoch;
  FirebaseFunctions get functions => FirebaseFunctions.instanceFor(region: CloudConfig.region);

  Future<void> initialize() async {
    if (!CloudConfig.configured) {
      error = 'Bu sürümde hesap bağlantısı yapılandırılmamış. Firebase ayarlarıyla hazırlanmış güncel sürümü yükleyin.';
      _notify();
      return;
    }
    try {
      await Firebase.initializeApp(options: CloudConfig.options);
      ready = true;
      WidgetsBinding.instance.addObserver(this);
      _auth = FirebaseAuth.instance.authStateChanges().listen((value) {
        unawaited(_sessionChanged(value));
      });
    } catch (_) {
      error = 'Bulut bağlantısı açılamadı. Yerel kayıtlarınız kullanılabilir.';
    }
    _notify();
  }

  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> _sessionChanged(User? value) async {
    final session = ++_session;
    await _entitlement?.cancel();
    await _stopPresence();
    if (_disposed || session != _session) return;
    user = value;
    premiumUntilMillis = 0;
    _notify();
    if (value == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(value.uid).set({
        'email': value.email ?? '',
        'displayName': value.displayName ?? '',
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (_disposed || session != _session) return;
      _entitlement = FirebaseFirestore.instance.collection('entitlements').doc(value.uid)
          .snapshots().listen((snapshot) {
        premiumUntilMillis = (snapshot.data()?['premiumUntilMillis'] as num?)?.toInt() ?? 0;
        _notify();
      }, onError: (Object _) {
        error = 'Üyelik bilgisi alınamadı. Yeniden bağlanmayı deneyin.';
        _notify();
      });
      await _startPresence();
    } catch (_) {
      error = 'Hesap bağlantısı tamamlanamadı. Yerel kayıtlarınız korunuyor.';
      _notify();
    }
  }

  Future<void> signIn(String email, String password, {bool register = false}) async {
    if (!ready) throw StateError('Bulut bağlantısı yapılandırılmamış.');
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw const FormatException('Geçerli bir e-posta adresi girin.');
    }
    if (password.isEmpty || (register && password.length < 6)) {
      throw const FormatException('Şifreniz en az 6 karakter olmalı.');
    }
    error = null;
    if (register) {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
      try {
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      } catch (_) {
        error = 'Hesabınız oluşturuldu ancak doğrulama e-postası gönderilemedi. Daha sonra tekrar deneyin.';
        _notify();
      }
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
    }
  }

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    await _stopPresence();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> deleteAccount(String password) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.email == null) throw StateError('Önce giriş yapın.');
    await current.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: current.email!, password: password));
    await _stopPresence();
    if (CloudConfig.premiumEnabled) {
      await functions.httpsCallable('deleteMyAccount').call<void>();
    } else {
      await FirebaseFirestore.instance.doc('users/' + current.uid + '/private/backup').delete();
      await FirebaseFirestore.instance.doc('users/' + current.uid).delete();
      if (CloudConfig.databaseUrl.isNotEmpty) {
        await FirebaseDatabase.instance.ref('presence/' + current.uid).remove();
      }
      await current.delete();
    }
    await FirebaseAuth.instance.signOut();
  }

  Future<void> uploadBackup(String source) async {
    final uid = user?.uid;
    if (uid == null) throw StateError('Önce giriş yapın.');
    if (utf8.encode(source).length > 700000) {
      throw StateError('Bulut yedeği sınırı 700 KB. Daha büyük kayıtları dosya olarak yedekleyin.');
    }
    await FirebaseFirestore.instance.doc('users/$uid/private/backup').set({
      'payload': source, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> downloadBackup() async {
    final uid = user?.uid;
    if (uid == null) throw StateError('Önce giriş yapın.');
    final data = await FirebaseFirestore.instance.doc('users/$uid/private/backup').get(
      const GetOptions(source: Source.server));
    final payload = data.data()?['payload'];
    if (payload is! String) throw StateError('Bu hesapta bulut yedeği bulunamadı.');
    return payload;
  }

  Future<void> _startPresence() async {
    final uid = user?.uid;
    if (uid == null || !_foreground || CloudConfig.databaseUrl.isEmpty || _disposed) return;
    final session = _session;
    _connected = FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value != true || !_foreground || session != _session) return;
      try {
        final connection = FirebaseDatabase.instance.ref('presence/$uid/connections').push();
        _connection = connection;
        await connection.onDisconnect().remove();
        await FirebaseDatabase.instance.ref('presence/$uid/lastSeen').onDisconnect()
            .set(ServerValue.timestamp);
        if (_foreground && session == _session) await connection.set(true);
      } catch (_) {
        // Presence must never prevent access to the local ledger.
      }
    });
  }

  Future<void> _stopPresence() async {
    await _connected?.cancel();
    _connected = null;
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try { await connection.remove(); await connection.parent!.parent!.child('lastSeen').set(ServerValue.timestamp); await connection.onDisconnect().cancel(); } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_resumePresence());
  }

  Future<void> _resumePresence() async {
    await _stopPresence();
    if (_foreground) await _startPresence();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_session;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_auth?.cancel());
    unawaited(_entitlement?.cancel());
    unawaited(_stopPresence());
    super.dispose();
  }
}
