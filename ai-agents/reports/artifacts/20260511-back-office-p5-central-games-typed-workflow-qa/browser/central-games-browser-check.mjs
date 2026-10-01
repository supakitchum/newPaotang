import fs from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const outDir = '/workspace/ai-agents/reports/artifacts/20260511-back-office-p5-central-games-typed-workflow-qa/browser';
const baseUrl = process.env.QA_BO_BASE || 'http://localhost:3100';
const apiBase = process.env.QA_API_BASE || 'http://platform-api:8000/api/v1';
const centralEmail = process.env.QA_CENTRAL_EMAIL || 'admin@newpaotang.test';
const centralPassword = process.env.QA_CENTRAL_PASSWORD;

if (!centralPassword) {
  throw new Error('Missing QA_CENTRAL_PASSWORD');
}

fs.mkdirSync(outDir, { recursive: true });

const run = Date.now().toString(36).slice(-6);
const gameCode = `p5_games_ui_${run}`;
const createdName = `P5 Games UI ${run}`;
const updatedName = `P5 Games UI ${run} Open`;
const drawAt = '2026-06-20T12:00';
const closeAt = '2026-06-19T12:00';
const updatedCloseAt = '2026-06-18T12:00';

const requests = [];
const responses = [];
const consoleMessages = [];
const summary = {
  generated_at: new Date().toISOString(),
  game_code: gameCode,
  checks: {},
  requests,
  responses,
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
page.setDefaultTimeout(30000);

page.on('console', (msg) => {
  if (['warning', 'error'].includes(msg.type())) {
    consoleMessages.push({ type: msg.type(), text: msg.text().slice(0, 500) });
  }
});

page.on('response', (res) => {
  const url = new URL(res.url());
  if (url.pathname.includes('/api/v1/admin/central/games')) {
    responses.push({
      method: res.request().method(),
      path: `${url.pathname}${url.search}`.replace('/api/v1', ''),
      status: res.status(),
    });
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

await directCentralSessionLogin();
await page.goto(`${baseUrl}/admin/central/dashboard`, { waitUntil: 'domcontentloaded' });
await waitForLoadedPage();

const href = '/admin/central/games';
const menuLinkCount = await page.locator(`a[href="${href}"]`).count();
if (menuLinkCount > 0) {
  await page.locator(`a[href="${href}"]`).first().click();
} else {
  await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
}
await page.waitForURL(`**${href}`);
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-list-before-create.png`, fullPage: true });
summary.checks.initial_list = {
  menu_link_count: menuLinkCount,
  route: page.url().replace(baseUrl, ''),
  row_count: await page.locator('table tbody tr').count(),
  has_error_alert: await hasErrorAlert(),
};

await page.getByRole('button', { name: 'Create game' }).click();
await visibleModal();
await page.screenshot({ path: `${outDir}/central-games-create-modal.png`, fullPage: true });
summary.checks.create_modal = await modalFormEvidence();

const modal = page.locator('.modal.show').last();
await modal.locator('#admin-confirm-code').fill(gameCode);
await modal.locator('#admin-confirm-name').fill(createdName);
await modal.locator('#admin-confirm-draw_at').fill(drawAt);
await modal.locator('#admin-confirm-close_at').fill(closeAt);
await modal.locator('#admin-confirm-status').selectOption('draft');
summary.checks.create_modal.confirm_disabled_after_required_fields = await modal.getByRole('button', { name: 'Confirm' }).isDisabled();
await Promise.all([
  page.waitForResponse((res) => res.request().method() === 'POST' && res.url().includes('/api/v1/admin/central/games')),
  modal.getByRole('button', { name: 'Confirm' }).click(),
]);
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-list-after-create.png`, fullPage: true });

const createdRow = page.locator('table tbody tr').filter({ hasText: gameCode }).first();
await createdRow.waitFor({ state: 'visible' });
summary.checks.after_create = {
  row_text: normalize(await createdRow.innerText()),
  has_created_row: await createdRow.count() > 0,
  has_error_alert: await hasErrorAlert(),
};

await createdRow.getByRole('link', { name: 'Detail' }).click();
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-detail-after-create.png`, fullPage: true });
summary.checks.detail_after_create = {
  route: page.url().replace(baseUrl, ''),
  text_sample: (await bodyText()).slice(0, 900),
  includes_created_code: (await bodyText()).includes(gameCode),
  includes_draft_status: (await bodyText()).toLowerCase().includes('draft'),
  has_error_alert: await hasErrorAlert(),
};

await page.getByRole('button', { name: 'Update' }).click();
await visibleModal();
await page.screenshot({ path: `${outDir}/central-games-update-modal.png`, fullPage: true });
summary.checks.update_modal = await modalFormEvidence();

const updateModal = page.locator('.modal.show').last();
await updateModal.locator('#admin-confirm-name').fill(updatedName);
await updateModal.locator('#admin-confirm-close_at').fill(updatedCloseAt);
await updateModal.locator('#admin-confirm-status').selectOption('open');
await Promise.all([
  page.waitForResponse((res) => res.request().method() === 'PATCH' && res.url().includes('/api/v1/admin/central/games/')),
  updateModal.getByRole('button', { name: 'Confirm' }).click(),
]);
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-detail-after-update.png`, fullPage: true });
summary.checks.after_update = {
  route: page.url().replace(baseUrl, ''),
  text_sample: (await bodyText()).slice(0, 900),
  includes_updated_name: (await bodyText()).includes(updatedName),
  includes_open_status: (await bodyText()).toLowerCase().includes('open'),
  has_error_alert: await hasErrorAlert(),
};

await page.getByRole('button', { name: 'Close' }).click();
await visibleModal();
const closeModal = page.locator('.modal.show').last();
const closeText = normalize(await closeModal.innerText());
summary.checks.close_modal = {
  has_reason: closeText.includes('Reason'),
  has_context_code: closeText.includes(gameCode),
  has_context_status: closeText.includes('open'),
  confirm_disabled_without_reason: await closeModal.getByRole('button', { name: 'Confirm' }).isDisabled(),
};
await page.screenshot({ path: `${outDir}/central-games-close-modal.png`, fullPage: true });
await closeModal.locator('textarea').last().fill('p5 games browser qa close');
await Promise.all([
  page.waitForResponse((res) => res.request().method() === 'POST' && res.url().includes('/close')),
  closeModal.getByRole('button', { name: 'Confirm' }).click(),
]);
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-detail-after-close.png`, fullPage: true });
summary.checks.after_close = {
  text_sample: (await bodyText()).slice(0, 900),
  includes_closed_status: (await bodyText()).toLowerCase().includes('closed'),
  has_error_alert: await hasErrorAlert(),
};

await page.getByRole('button', { name: 'Archive' }).click();
await visibleModal();
const archiveModal = page.locator('.modal.show').last();
const archiveText = normalize(await archiveModal.innerText());
summary.checks.archive_modal = {
  has_reason: archiveText.includes('Reason'),
  has_context_code: archiveText.includes(gameCode),
  has_context_status: archiveText.includes('closed'),
  confirm_disabled_without_reason: await archiveModal.getByRole('button', { name: 'Confirm' }).isDisabled(),
};
await page.screenshot({ path: `${outDir}/central-games-archive-modal.png`, fullPage: true });
await archiveModal.locator('textarea').last().fill('p5 games browser qa archive');
await Promise.all([
  page.waitForResponse((res) => res.request().method() === 'POST' && res.url().includes('/archive')),
  archiveModal.getByRole('button', { name: 'Confirm' }).click(),
]);
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-detail-after-archive.png`, fullPage: true });
summary.checks.after_archive = {
  route: page.url().replace(baseUrl, ''),
  text_sample: (await bodyText()).slice(0, 900),
  includes_archived_status: (await bodyText()).toLowerCase().includes('archived'),
  has_error_alert: await hasErrorAlert(),
};

await page.reload({ waitUntil: 'domcontentloaded' });
await waitForLoadedPage();
summary.checks.hard_refresh_detail = {
  route: page.url().replace(baseUrl, ''),
  login_visible: await page.getByText('Admin sign in', { exact: false }).count() > 0,
  includes_archived_status: (await bodyText()).toLowerCase().includes('archived'),
};

await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
await waitForLoadedPage();
await page.locator('select.form-select').first().selectOption('archived');
await page.getByRole('button', { name: /Apply filters/i }).click();
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-archived-filter.png`, fullPage: true });
summary.checks.archived_filter = {
  row_count: await page.locator('table tbody tr').count(),
  includes_game_code: (await bodyText()).includes(gameCode),
  has_error_alert: await hasErrorAlert(),
};

await page.locator('select.form-select').first().selectOption('reward_published');
await page.getByRole('button', { name: /Apply filters/i }).click();
await waitForLoadedPage();
await page.screenshot({ path: `${outDir}/central-games-reward-published-empty.png`, fullPage: true });
summary.checks.reward_published_empty = {
  row_count: await page.locator('table tbody tr').count(),
  coherent_empty_state: /No games|No records were returned/i.test(await bodyText()),
  has_error_alert: await hasErrorAlert(),
};

fs.writeFileSync(`${outDir}/browser-summary.json`, `${JSON.stringify(summary, null, 2)}\n`);
await browser.close();

async function directCentralSessionLogin() {
  const response = await fetch(`${apiBase}/auth/admin/login`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Admin-Scope': 'central',
    },
    body: JSON.stringify({
      email: centralEmail,
      password: centralPassword,
      scope: 'central',
    }),
  });
  if (!response.ok) {
    throw new Error(`Central login failed: ${response.status}`);
  }
  const auth = await response.json();
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
  await page.evaluate(({ auth }) => {
    sessionStorage.clear();
    localStorage.clear();
    sessionStorage.setItem('newpaotang.back-office.session.v1', JSON.stringify({
      accessToken: auth.access_token,
      refreshToken: auth.refresh_token,
      user: auth.user,
      scopes: Array.isArray(auth.scopes) ? auth.scopes : [],
      activeScope: 'central',
      activeTenantId: null,
    }));
    document.cookie = 'newpaotang_bo_session=1; Path=/; SameSite=Lax';
  }, { auth });
}

async function visibleModal() {
  const modal = page.locator('.modal.show').last();
  await modal.waitFor({ state: 'visible' });
  return modal;
}

async function modalFormEvidence() {
  const modal = page.locator('.modal.show').last();
  const fields = await modal.locator('label.form-label, label.form-check-label').evaluateAll((labels) => labels.map((label) => label.textContent?.replace(/\s+/g, ' ').trim() || '').filter(Boolean));
  const inputTypes = await modal.locator('input, select, textarea').evaluateAll((inputs) => inputs.map((input) => ({
    id: input.getAttribute('id') || '',
    tag: input.tagName.toLowerCase(),
    type: input.getAttribute('type') || '',
    value: input.tagName.toLowerCase() === 'select' ? '' : '',
    options: input.tagName.toLowerCase() === 'select'
      ? Array.from(input.querySelectorAll('option')).map((option) => option.getAttribute('value') || '')
      : [],
  })));
  return {
    fields,
    input_types: inputTypes,
    confirm_disabled_initially: await modal.getByRole('button', { name: 'Confirm' }).isDisabled(),
    text_sample: normalize(await modal.innerText()).slice(0, 1000),
  };
}

async function waitForLoadedPage() {
  await page.waitForLoadState('networkidle').catch(() => null);
  await page.locator('.spinner-border').first().waitFor({ state: 'detached', timeout: 10000 }).catch(() => null);
  await page.waitForTimeout(400);
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
