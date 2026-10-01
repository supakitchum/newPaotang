import fs from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const outDir = '/workspace/ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/browser';
const baseUrl = process.env.QA_BO_BASE || 'http://localhost:3100';
const apiBase = process.env.QA_API_BASE || 'http://platform-api:8000/api/v1';
const centralEmail = process.env.QA_CENTRAL_EMAIL || 'admin@newpaotang.test';
const centralPassword = process.env.QA_CENTRAL_PASSWORD;
const tenantEmail = process.env.QA_TENANT_EMAIL || 'owner@alpha.newpaotang.test';
const tenantPassword = process.env.QA_TENANT_PASSWORD;
const tenantId = process.env.QA_TENANT_ID || 'ten_demo_alpha';

if (!centralPassword || !tenantPassword) {
  throw new Error('Missing QA credential environment values');
}

fs.mkdirSync(outDir, { recursive: true });

const requests = [];
const consoleMessages = [];
const summary = {
  generated_at: new Date().toISOString(),
  tenant_id: tenantId,
  rows: {},
  mobile: {},
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

async function directSessionLogin(scope) {
  const payload = {
    email: scope === 'central' ? centralEmail : tenantEmail,
    password: scope === 'central' ? centralPassword : tenantPassword,
    scope,
    tenant_id: scope === 'tenant' ? tenantId : null,
  };
  const response = await fetch(`${apiBase}/auth/admin/login`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Admin-Scope': scope,
      ...(scope === 'tenant' ? { 'X-Tenant-Id': tenantId } : {}),
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(`${scope} login failed: ${response.status}`);
  }
  const auth = await response.json();
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
  await page.evaluate(({ auth, scope, tenantId }) => {
    sessionStorage.clear();
    localStorage.clear();
    sessionStorage.setItem('newpaotang.back-office.session.v1', JSON.stringify({
      accessToken: auth.access_token,
      refreshToken: auth.refresh_token,
      user: auth.user,
      scopes: Array.isArray(auth.scopes) ? auth.scopes : [],
      activeScope: scope,
      activeTenantId: scope === 'tenant' ? tenantId : null,
    }));
    document.cookie = 'newpaotang_bo_session=1; Path=/; SameSite=Lax';
  }, { auth, scope, tenantId });
}

async function openFromMenu(href, screenshotName) {
  const link = page.locator(`a[href="${href}"]`).first();
  const linkCount = await page.locator(`a[href="${href}"]`).count();
  if (linkCount > 0) {
    await link.click();
  } else {
    await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
  }
  await page.waitForURL(`**${href}`);
  await waitForLoadedPage();
  const text = await bodyText();
  await page.screenshot({ path: `${outDir}/${screenshotName}`, fullPage: true });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitForLoadedPage();
  const loginVisibleAfterReload = (await page.getByText('Admin sign in', { exact: false }).count()) > 0;
  return {
    route: page.url().replace(baseUrl, ''),
    menu_link_count: linkCount,
    hard_refresh_kept_session: !loginVisibleAfterReload,
    has_error_alert: (await page.locator('.alert-danger,.alert-warning').count()) > 0,
    text_sample: text.slice(0, 900),
  };
}

async function inspectDashboard(scope, href, key, screenshot) {
  await page.goto(`${baseUrl}/admin/${scope}/dashboard`, { waitUntil: 'domcontentloaded' });
  await waitForLoadedPage();
  const opened = await openFromMenu(href, screenshot);
  summary.rows[key] = {
    ...opened,
    kpi_card_count: await page.locator('.card').filter({ hasText: /Partners|Active tenants|Admin users|Roles|Orders|Audit logs/i }).count(),
    refresh_button_count: await page.getByRole('button', { name: /Refresh/i }).count(),
  };
}

async function inspectListDetail(href, key, listScreenshot, detailScreenshot) {
  const opened = await openFromMenu(href, listScreenshot);
  const rows = await page.locator('table tbody tr').count();
  const firstRowText = rows > 0 ? normalize(await page.locator('table tbody tr').first().innerText()) : '';
  const filterEvidence = await inspectStatusFilters(href, key);
  await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
  await waitForLoadedPage();
  const detailLinks = await page.getByRole('link', { name: 'Detail' }).count();
  if (detailLinks > 0) {
    await page.getByRole('link', { name: 'Detail' }).first().click();
    await waitForLoadedPage();
  }
  const detailText = await bodyText();
  await page.screenshot({ path: `${outDir}/${detailScreenshot}`, fullPage: true });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitForLoadedPage();
  summary.rows[key] = {
    ...opened,
    table_row_count: rows,
    first_row_text: firstRowText,
    filters: filterEvidence,
    detail_link_count: detailLinks,
    detail_route: page.url().replace(baseUrl, ''),
    detail_has_error_alert: (await page.locator('.alert-danger,.alert-warning').count()) > 0,
    detail_text_sample: detailText.slice(0, 1100),
    detail_hard_refresh_kept_session: (await page.getByText('Admin sign in', { exact: false }).count()) === 0,
  };
}

async function inspectStatusFilters(href, key) {
  const scenarios = key === 'tenant:tickets'
    ? [{ value: 'active', name: 'hit' }, { value: 'closed', name: 'empty' }]
    : [{ value: 'pending', name: 'hit' }, { value: 'completed', name: 'empty' }];
  const result = {};
  const select = page.locator('select.form-select').first();
  if ((await select.count()) === 0) return { supported: false };

  for (const scenario of scenarios) {
    const optionCount = await page.locator(`select.form-select option[value="${scenario.value}"]`).count();
    if (optionCount === 0) {
      result[scenario.name] = {
        status_value: scenario.value,
        option_present: false,
        row_count: null,
        coherent_empty_state: null,
        text_sample: (await bodyText()).slice(0, 600),
      };
      continue;
    }
    await select.selectOption(scenario.value);
    await page.getByRole('button', { name: /Apply filters/i }).click();
    await waitForLoadedPage();
    const rowCount = await page.locator('table tbody tr').count();
    const body = await bodyText();
    result[scenario.name] = {
      status_value: scenario.value,
      option_present: true,
      row_count: rowCount,
      coherent_empty_state: rowCount === 0 ? /No .*|No records were returned/i.test(body) : null,
      text_sample: body.slice(0, 600),
    };
    await page.screenshot({ path: `${outDir}/${key.replace(':', '-')}-filter-${scenario.name}.png`, fullPage: true });
    await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
    await waitForLoadedPage();
  }

  return { supported: true, ...result };
}

async function inspectSummary(href, key, screenshot, applyUsageFilters = false) {
  const opened = await openFromMenu(href, screenshot);
  if (applyUsageFilters) {
    const dateInputs = page.locator('input[type="date"]');
    if (await dateInputs.count() >= 2) {
      await dateInputs.nth(0).fill('2026-05-01');
      await dateInputs.nth(1).fill('2026-05-31');
      await page.getByRole('button', { name: /Apply filters/i }).click();
      await waitForLoadedPage();
      await page.screenshot({ path: `${outDir}/tenant-usage-filtered.png`, fullPage: true });
    }
  }
  const text = await bodyText();
  summary.rows[key] = {
    ...opened,
    definition_count: await page.locator('.card').count(),
    has_apply_filters: (await page.getByRole('button', { name: /Apply filters/i }).count()) > 0,
    text_sample_after_filters: text.slice(0, 1100),
  };
}

async function mobileCheck(href, key, screenshotName) {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
  await waitForLoadedPage();
  await page.screenshot({ path: `${outDir}/${screenshotName}`, fullPage: true });
  summary.mobile[key] = {
    route: page.url().replace(baseUrl, ''),
    login_visible: (await page.getByText('Admin sign in', { exact: false }).count()) > 0,
    text_sample: (await bodyText()).slice(0, 700),
  };
  await page.setViewportSize({ width: 1440, height: 1050 });
}

await directSessionLogin('central');
await inspectDashboard('central', '/admin/central/dashboard', 'central:dashboard', 'central-dashboard.png');
await mobileCheck('/admin/central/dashboard', 'central-dashboard', 'mobile-central-dashboard.png');

await directSessionLogin('tenant');
await inspectDashboard('tenant', '/admin/tenant/dashboard', 'tenant:dashboard', 'tenant-dashboard.png');
await inspectListDetail('/admin/tenant/tickets', 'tenant:tickets', 'tenant-tickets-list.png', 'tenant-ticket-detail.png');
await mobileCheck('/admin/tenant/tickets/tic_p5_read', 'tenant-ticket-detail', 'mobile-tenant-ticket-detail.png');
await inspectListDetail('/admin/tenant/growth/attributions', 'tenant:affiliate_attributions', 'tenant-attributions-list.png', 'tenant-attribution-detail.png');
await inspectSummary('/admin/tenant/monitoring', 'tenant:monitoring', 'tenant-monitoring.png');
await inspectSummary('/admin/tenant/usage', 'tenant:usage', 'tenant-usage.png', true);

fs.writeFileSync(`${outDir}/browser-summary.json`, `${JSON.stringify(summary, null, 2)}\n`);

await browser.close();

function safePostDataKeys(postData) {
  if (!postData) return [];
  try {
    return Object.keys(JSON.parse(postData)).filter((key) => !/password|token|secret/i.test(key));
  } catch {
    return ['non_json_body'];
  }
}

async function waitForLoadedPage() {
  await page.waitForLoadState('networkidle').catch(() => null);
  await page.locator('.spinner-border').first().waitFor({ state: 'detached', timeout: 10000 }).catch(() => null);
  await page.waitForTimeout(300);
}

async function bodyText() {
  return normalize(await page.locator('body').innerText());
}

function normalize(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}
