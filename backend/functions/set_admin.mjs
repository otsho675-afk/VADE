import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
const [projectId, email] = process.argv.slice(2);
if (!projectId || !email) throw new Error('node set_admin.mjs PROJECT_ID ADMIN_EMAIL');
initializeApp({credential: applicationDefault(), projectId});
const user = await getAuth().getUserByEmail(email);
await getAuth().setCustomUserClaims(user.uid, {...user.customClaims, admin: true});
console.log('Yönetici yetkisi verildi. Çıkış yapıp tekrar giriş yapın.');
