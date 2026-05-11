import fs from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const outDir = '/workspace/ai-agents/reports/artifacts/20260511-back-office-p5-ticket-status-filter-remediation-qa/browser';
const baseUrl = process.env.QA_BO_BASE || 'http://localhost:3100';
const apiBase = process.env.QA_API_BASE || 'http://platform-api:8000/api/v1';
const tenantEmail = process.env.QA_TENANT_EMAIL || 'owner@alpha.newpaotang.test';
const tenantPassword = process.env.QA_TENANT_PASSWORD;
const tenantId = process.env.QA_TENANT_ID || 'ten_demo_alpha';

if (!tenantPassword) {
  throw new Error('Missing QA_TENANT_PASSWORD');
}

fs.mkdirSync(outDir, { recursive: true });

const requests = [];
const consoleMessages = [];
const summary = {
  generated_at: new Date().toISOString(),
  tenant_id: tenantId,
  route: '/admin/tenant/tickets',
  checks: {},
  requests,
  console_messages: consoleMessages,
};

const browser = await chromium.launch({
  headless: true,
  args: process.env.QA_HOST_RESOLVER_RULES ? [`--host-resolver-rules=${process.env.QA_HOST_RESOLVER_RULES}`] : [],
});
const context = await browser.newContext({
  viewport: { width: 1440, height: 1050 },
  ignoreHTTPSErrors: true,
});
const page = await context.newPage();
page.setDefaultTimeout(25000);

page.on('console', (msg) => {
  if (['warning', 'error'].includes(msg.type())) {
    consoleMessages.push({ type: msg.type(), text: msg.text().slice(0, 500) });
  }
});

await page.route('**/api/v1/**', async (route) => {
  const req = route.request();
  const url = new URL(req.url());
  const apiUrl = `${apiBase}${url.pathname.replace('/api/v1', '')}${url.search}`;
  const headers = req.headers();
  requests.push({
    method: req.method(),
    path: `${url.pathname}${url.search}`,
    headers: {
      'x-admin-scope': headers['x-admin-scope'] || null,
      'x-tenant-id': headers['x-tenant-id'] || null,
      'idempotency-key-present': Boolean(headers['idempotency-key']),
    },
    post_data_keys: safePostDataKeys(req.postData()),
  });
  await route.continue({ url: apiUrl });
});

await directTenantSessionLogin();
await page.goto(`${baseUrl}/admin/tenant/dashboard`, { waitUntil: 'domcontentloaded' });
await waitForLoadedPage();

const href = '/admin/tenant/tickets';
const menuLinkCount = await page.locator(`a[href="${href}"]`).count();
if (menuLinkCount > 0) {
  await page.locator(`a[href="${href}"]`).first().click();
} else {
  await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
}
await page.waitForURL(`**${href}`);
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/tenant-tickets-menu-list.png`, fullPage: true });

const optionValues = await page.locator('select.form-select').first().locator('option').evaluateAll((options) => options.map((option) => ({
  value: option.getAttribute('value') || '',
  label: option.textContent?.trim() || '',
})));
const initialRowCount = await page.locator('table tbody tr').count();
const initialFirstRowText = initialRowCount > 0 ? normalize(await page.locator('table tbody tr').first().innerText()) : '';

summary.checks.initial = {
  menu_link_count: menuLinkCount,
  option_values: optionValues,
  has_active_option: optionValues.some((option) => option.value === 'active'),
  preserves_existing_options: ['open', 'pending', 'resolved', 'closed'].every((value) => optionValues.some((option) => option.value === value)),
  row_count: initialRowCount,
  first_row_text: initialFirstRowText,
  has_error_alert: await hasErrorAlert(),
};

await page.locator('select.form-select').first().selectOption('active');
await page.getByRole('button', { name: /Apply filters/i }).click();
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/tenant-tickets-active-filter.png`, fullPage: true });

const activeRows = await page.locator('table tbody tr').count();
const activeFirstRowText = activeRows > 0 ? normalize(await page.locator('table tbody tr').first().innerText()) : '';
summary.checks.active_filter = {
  row_count: activeRows,
  first_row_text: activeFirstRowText,
  includes_fixture_ticket: activeFirstRowText.includes('tic_p5_read'),
  includes_active_status: activeFirstRowText.toLowerCase().includes('active'),
  has_error_alert: await hasErrorAlert(),
};

const detailLinkCount = await page.getByRole('link', { name: 'Detail' }).count();
if (detailLinkCount > 0) {
  await page.getByRole('link', { name: 'Detail' }).first().click();
  await waitForLoadedPage();
}
await page.screenshot({ path: `${outDir}/tenant-tickets-active-detail.png`, fullPage: true });
summary.checks.detail = {
  detail_link_count: detailLinkCount,
  route: page.url().replace(baseUrl, ''),
  text_sample: (await bodyText()).slice(0, 900),
  includes_fixture_ticket: (await bodyText()).includes('tic_p5_read'),
  includes_active_status: (await bodyText()).toLowerCase().includes('active'),
  has_error_alert: await hasErrorAlert(),
};

await page.reload({ waitUntil: 'domcontentloaded' });
await waitForLoadedPage();
summary.checks.detail_hard_refresh = {
  route: page.url().replace(baseUrl, ''),
  login_visible: await page.getByText('Admin sign in', { exact: false }).count() > 0,
};

await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
await waitForLoadedPage();
await page.locator('select.form-select').first().selectOption('closed');
await page.getByRole('button', { name: /Apply filters/i }).click();
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/tenant-tickets-closed-empty.png`, fullPage: true });
summary.checks.closed_empty = {
  row_count: await page.locator('table tbody tr').count(),
  coherent_empty_state: /No tickets|No records were returned/i.test(await bodyText()),
  has_error_alert: await hasErrorAlert(),
};

await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
await waitForLoadedPage();
await page.locator('select.form-select').first().selectOption('active');
await page.locator('input.form-control').first().fill('tic_p5_read');
await page.getByRole('button', { name: /Apply filters/i }).click();
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/tenant-tickets-active-cursor-empty.png`, fullPage: true });
summary.checks.cursor_empty = {
  route: page.url().replace(baseUrl, ''),
  row_count: await page.locator('table tbody tr').count(),
  coherent_empty_state: /No tickets|No records were returned/i.test(await bodyText()),
  has_error_alert: await hasErrorAlert(),
};

await page.setViewportSize({ width: 390, height: 844 });
await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
await waitForLoadedPage();
await page.locator('select.form-select').first().selectOption('active');
await page.getByRole('button', { name: /Apply filters/i }).click();
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/mobile-tenant-tickets-active-filter.png`, fullPage: true });
summary.checks.mobile_active_filter = {
  route: page.url().replace(baseUrl, ''),
  login_visible: await page.getByText('Admin sign in', { exact: false }).count() > 0,
  row_count: await page.locator('table tbody tr').count(),
  text_sample: (await bodyText()).slice(0, 650),
};

fs.writeFileSync(`${outDir}/browser-summary.json`, `${JSON.stringify(summary, null, 2)}\n`);
await browser.close();

async function directTenantSessionLogin() {
  const response = await fetch(`${apiBase}/auth/admin/login`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Admin-Scope': 'tenant',
      'X-Tenant-Id': tenantId,
    },
    body: JSON.stringify({
      email: tenantEmail,
      password: tenantPassword,
      scope: 'tenant',
      tenant_id: tenantId,
    }),
  });
  if (!response.ok) {
    throw new Error(`Tenant login failed: ${response.status}`);
  }
  const auth = await response.json();
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
  await page.evaluate(({ auth, tenantId }) => {
    sessionStorage.clear();
    localStorage.clear();
    sessionStorage.setItem('newpaotang.back-office.session.v1', JSON.stringify({
      accessToken: auth.access_token,
      refreshToken: auth.refresh_token,
      user: auth.user,
      scopes: Array.isArray(auth.scopes) ? auth.scopes : [],
      activeScope: 'tenant',
      activeTenantId: tenantId,
    }));
    document.cookie = 'newpaotang_bo_session=1; Path=/; SameSite=Lax';
  }, { auth, tenantId });
}

async function waitForLoadedPage() {
  await page.waitForLoadState('networkidle').catch(() => null);
  await page.locator('.spinner-border').first().waitFor({ state: 'detached', timeout: 10000 }).catch(() => null);
  await page.waitForTimeout(300);
}

async function bodyText() {
  return normalize(await page.locator('body').innerText());
}

async function hasErrorAlert() {
  return (await page.locator('.alert-danger,.alert-warning').count()) > 0;
}

function normalize(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function safePostDataKeys(postData) {
  if (!postData) return [];
  try {
    return Object.keys(JSON.parse(postData)).filter((key) => !/password|token|secret/i.test(key));
  } catch {
    return ['non_json_body'];
  }
}
