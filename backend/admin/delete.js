import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {getAuth, signInWithEmailAndPassword, signOut} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';
import {getFunctions, httpsCallable} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-functions.js';
const form = document.getElementById('delete'), status = document.getElementById('status');
if (!window.VADESI_CONFIG?.apiKey) {
  form.hidden = true; status.textContent = 'Hesap hizmeti henüz yapılandırılmamış.';
} else {
  const app = initializeApp(window.VADESI_CONFIG), auth = getAuth(app);
  form.onsubmit = async event => {
    event.preventDefault();
    if (!confirm('Hesabınız ve bulut yedeğiniz kalıcı olarak silinsin mi?')) return;
    const button = form.querySelector('button');
    button.disabled = true;
    try {
      await signInWithEmailAndPassword(auth, document.getElementById('email').value.trim(),
        document.getElementById('password').value);
      document.getElementById('password').value = '';
      await httpsCallable(getFunctions(app, window.VADESI_CONFIG.region ?? 'europe-west1'),'deleteMyAccount')();
      await signOut(auth);
      form.hidden = true; status.textContent = 'Hesabınız silindi. Mağaza aboneliğini ayrıca iptal etmeyi unutmayın.';
    } catch { status.textContent = 'İşlem tamamlanamadı. Giriş bilgilerinizi ve bağlantınızı kontrol edip tekrar deneyin.'; }
    finally { button.disabled = false; }
  };
}
