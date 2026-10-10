import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {getAuth, signInWithEmailAndPassword, signOut, deleteUser} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';
import {getFirestore, doc, deleteDoc} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-firestore.js';
import {getDatabase, ref, remove} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-database.js';
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
      const user = auth.currentUser;
      await deleteDoc(doc(getFirestore(app), 'users', user.uid, 'private', 'backup'));
      await deleteDoc(doc(getFirestore(app), 'users', user.uid));
      await remove(ref(getDatabase(app), 'presence/' + user.uid));
      await deleteUser(user);
      await signOut(auth);
      form.hidden = true; status.textContent = 'Hesabınız ve sunucudaki kullanıcı verileriniz silindi.';
    } catch { status.textContent = 'İşlem tamamlanamadı. Giriş bilgilerinizi ve bağlantınızı kontrol edip tekrar deneyin.'; }
    finally { button.disabled = false; }
  };
}
