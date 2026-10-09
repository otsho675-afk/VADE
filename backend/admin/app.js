import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';
import {getFirestore, collection, query, orderBy, limit, startAfter, getDocs, getDoc, doc, getCountFromServer, where} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-firestore.js';
import {getDatabase, ref, onValue} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-database.js';
import {getFunctions, httpsCallable} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-functions.js';
const $ = id => document.getElementById(id);
const config = window.VADESI_CONFIG;
let cursor, presence = {}, visibleUsers = [], disconnect, session = 0;
const date = value => value ? new Date(value.toMillis ? value.toMillis() : value).toLocaleString('tr-TR') : '—';
function row(target, values) {
  const tr = document.createElement('tr');
  for (const value of values) { const td = document.createElement('td'); td.textContent = value; tr.append(td); }
  $(target).append(tr);
}
function renderUsers() {
  $('users').replaceChildren();
  for (const user of visibleUsers) {
    const p = presence[user.id] ?? {};
    row('users', [user.email, date(p.lastSeen ?? user.lastSeenAt),
      Object.keys(p.connections ?? {}).length ? 'Çevrimiçi' : 'Çevrimdışı',
      date(user.premiumUntilMillis)]);
  }
}
if (!config?.apiKey) {
  $('status').textContent = 'config.example.js dosyasını config.js olarak kopyalayıp Firebase web ayarlarını girin.';
  $('login').hidden = true;
} else {
  const app = initializeApp(config), auth = getAuth(app), db = getFirestore(app);
  const functions = getFunctions(app, config.region ?? 'europe-west1');
  const fail = error => { $('status').textContent = 'İşlem başarısız: ' + (error.code ?? error.message); };
  async function loadUsers(next = false) {
    const currentSession = session;
    const constraints = [orderBy('lastSeenAt', 'desc'), limit(50)];
    if (next && cursor) constraints.push(startAfter(cursor));
    const page = await getDocs(query(collection(db, 'users'), ...constraints));
    const users = await Promise.all(page.docs.map(async user => {
      const entitlement = await getDoc(doc(db, 'entitlements', user.id));
      return {id: user.id, ...user.data(), ...entitlement.data()};
    }));
    if (currentSession !== session) return;
    cursor = page.docs.at(-1);
    visibleUsers = users;
    $('next').disabled = page.size < 50;
    renderUsers();
  }
  async function refresh() {
    await loadUsers();
    const [total, premium, orders] = await Promise.all([
      getCountFromServer(collection(db,'users')),
      getCountFromServer(query(collection(db,'entitlements'), where('premiumUntilMillis','>',Date.now()))),
      getDocs(query(collection(db,'orders'), orderBy('verifiedAt','desc'), limit(50)))
    ]);
    $('counts').textContent = 'Kayıtlı üye: ' + total.data().count + ' · Aktif Premium: ' + premium.data().count;
    $('orders').replaceChildren();
    for (const order of orders.docs) {
      const data = order.data();
      row('orders', [data.uid, data.store, data.productId, date(data.premiumUntilMillis)]);
    }
  }
  $('login').onsubmit = async event => {
    event.preventDefault();
    try { await signInWithEmailAndPassword(auth, $('email').value.trim(), $('password').value); $('password').value = ''; }
    catch(error) { fail(error); }
  };
  $('logout').onclick = () => signOut(auth).catch(fail);
  $('refresh').onclick = () => refresh().catch(fail);
  $('next').onclick = () => loadUsers(true).catch(fail);
  $('announcement').onsubmit = async event => {
    event.preventDefault();
    if (!confirm('Bu duyuru izin veren bütün cihazlara gönderilecek. Devam edilsin mi?')) return;
    const button = event.target.querySelector('button');
    button.disabled = true;
    try {
      const response = await httpsCallable(functions,'sendAnnouncement')({title:$('title').value,body:$('body').value});
      $('status').textContent = 'Bildirim sağlayıcısına iletildi: ' + response.data.id;
    } catch(error) { fail(error); }
    finally { button.disabled = false; }
  };
  onAuthStateChanged(auth, async user => {
    ++session; disconnect?.(); presence = {}; visibleUsers = []; cursor = null;
    $('panel').hidden = true; $('login').hidden = false;
    $('users').replaceChildren(); $('orders').replaceChildren();
    if (!user) { $('status').textContent = 'Yönetici hesabınızla giriş yapın.'; return; }
    try {
      const token = await user.getIdTokenResult(true);
      if (token.claims.admin !== true) { await signOut(auth); throw new Error('Yönetici yetkisi yok.'); }
      $('panel').hidden = false; $('login').hidden = true;
      $('status').textContent = 'Yönetici oturumu açık.';
      disconnect = onValue(ref(getDatabase(app),'presence'), snapshot => {
        presence = snapshot.val() ?? {}; renderUsers();
      }, fail);
      await refresh();
    } catch(error) { fail(error); }
  });
}
