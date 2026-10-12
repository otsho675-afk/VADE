import { chromium } from 'playwright';
import assert from 'node:assert/strict';

const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--enable-unsafe-swiftshader'] });
const context = await browser.newContext({ locale: 'tr-TR', viewport: { width: 390, height: 844 } });
const page = await context.newPage();
page.setDefaultTimeout(60000);
const errors = [];
page.on('pageerror', error => { errors.push(error.message); console.log('PAGE_ERROR', error.stack); });
page.on('console', message => { if (message.type() === 'error') console.log('CONSOLE_ERROR', message.text()); });
page.on('requestfailed', request => console.log('REQUEST_FAILED', request.url(), request.failure()?.errorText));
try {
  await page.goto('http://127.0.0.1:8080');
  console.log('BROWSER_LANGUAGES', await page.evaluate(() => navigator.languages));
  await page.getByRole('button', { name: 'Üye ol', exact: true }).waitFor();
  await page.screenshot({ path: 'web-welcome.png', fullPage: true });
  await page.getByRole('button', { name: 'Misafir olarak devam et', exact: true }).click();
  await page.getByText('Finansın kontrol altında', { exact: true }).waitFor();
  await page.screenshot({ path: 'web-dashboard.png', fullPage: true });
  await page.getByRole('button', { name: 'Yeni ödeme ekle', exact: true }).click();
  await page.getByRole('button', { name: 'Tek seferlik', exact: true }).click();
  await page.getByRole('textbox', { name: 'Örn. Telefon taksiti' }).fill('Web doğrulama');
  await page.getByRole('textbox', { name: '1.250,00' }).fill('125,50');
  await page.getByRole('button', { name: 'Ödeme planını oluştur', exact: true }).click();
  await page.getByRole('group', { name: /^Web doğrulama/ }).waitFor();
  await page.reload();
  await page.getByRole('group', { name: /^Web doğrulama/ }).waitFor();
  await page.getByRole('button', { name: 'Ödendi', exact: true }).click();
  await page.getByText('Henüz ödeme yok', { exact: false }).waitFor();
  assert.deepEqual(errors, [], 'Unexpected browser exceptions');
  console.log('WEB_SMOKE_PASS: startup, payment creation, SQLite persistence after reload, payment completion');
} catch (error) {
  console.log('PAGE_ERRORS', errors);
  console.log((await page.content()).slice(0,16000));
  console.log((await page.locator('body').innerText()).slice(0,12000));
  await page.screenshot({ path: 'web-smoke-failure.png', fullPage: true });
  throw error;
} finally {
  await browser.close();
}
