import { chromium } from 'playwright';
import assert from 'node:assert/strict';

const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
const page = await context.newPage();
page.setDefaultTimeout(60000);
const errors = [];
page.on('pageerror', error => errors.push(error.message));
try {
  await page.goto('http://127.0.0.1:8080');
  async function accessibility() {
    const placeholder = page.locator('flt-semantics-placeholder');
    await placeholder.waitFor({ state: 'attached', timeout: 120000 });
    await placeholder.dispatchEvent('click');
  }
  await accessibility();
  await page.getByText('Ödemeleriniz tek yerde', { exact: true }).waitFor();
  await page.getByRole('button', { name: 'Yeni ödeme ekle', exact: true }).click();
  await page.getByText('Tek seferlik', { exact: true }).click();
  await page.getByRole('textbox', { name: /Ödeme adı/ }).fill('Web doğrulama');
  await page.getByRole('textbox', { name: /Tutar/ }).fill('125,50');
  await page.getByRole('button', { name: 'Ödeme planını oluştur', exact: true }).click();
  await page.getByText('Web doğrulama', { exact: true }).waitFor();
  await page.reload();
  await accessibility();
  await page.getByText('Web doğrulama', { exact: true }).waitFor();
  await page.getByRole('button', { name: 'Ödendi', exact: true }).click();
  await page.getByText('Henüz ödeme yok', { exact: true }).waitFor();
  assert.deepEqual(errors, [], 'Unexpected browser exceptions');
  console.log('WEB_SMOKE_PASS: startup, payment creation, SQLite persistence after reload, payment completion');
} catch (error) {
  console.log((await page.locator('body').innerText()).slice(0,12000));
  await page.screenshot({ path: 'web-smoke-failure.png', fullPage: true });
  throw error;
} finally {
  await browser.close();
}
