import fs from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const outDir = '/workspace/ai-agents/reports/artifacts/20260511-back-office-p4-remaining-admin-security-settings-workflow-qa-closure-qa/browser';
const apiEvidence = JSON.parse(fs.readFileSync(`${outDir.replace('/browser', '/api')}/focused-api-evidence.json`, 'utf8'));
const baseUrl = process.env.QA_BO_BASE || 'http://localhost:3100';
const apiBase = process.env.QA_API_BASE || 'http://platform-api:8000/api/v1';
const centralEmail = process.env.QA_CENTRAL_EMAIL || 'admin@newpaotang.test';
const centralPassword = process.env.QA_CENTRAL_PASSWORD;
const tenantEmail = process.env.QA_TENANT_EMAIL || 'owner@alpha.newpaotang.test';
const tenantPassword = process.env.QA_TENANT_PASSWORD;
const tenantId = process.env.QA_TENANT_ID || 'ten_demo_alpha';
const runId = `browser-p4-${Date.now().toString(36)}`;

if (!centralPassword || !tenantPassword) {
  throw new Error('Missing QA_CENTRAL_PASSWORD or QA_TENANT_PASSWORD');
}

fs.mkdirSync(outDir, { recursive: true });

const requests = [];
const consoleWarnings = [];

const browser = await chromium.launch({
  headless: true,
  args: process.env.QA_HOST_RESOLVER_RULES ? [`--host-resolver-rules=${process.env.QA_HOST_RESOLVER_RULES}`] : [],
});

const context = await browser.newContext({
  viewport: { width: 1440, height: 1100 },
  ignoreHTTPSErrors: true,
});
const page = await context.newPage();
page.setDefaultTimeout(20000);
page.on('console', (msg) => {
  if (['warning', 'error'].includes(msg.type())) {
    consoleWarnings.push({ type: msg.type(), text: msg.text().slice(0, 500) });
  }
});

await page.route('**/api/v1/**', async (route) => {
  const req = route.request();
  const url = new URL(req.url());
  const apiUrl = `${apiBase}${url.pathname.replace('/api/v1', '')}${url.search}`;
  requests.push({
    method: req.method(),
    url: `${url.pathname}${url.search}`,
    headers: {
      'x-admin-scope': req.headers()['x-admin-scope'] || null,
      'x-tenant-id': req.headers()['x-tenant-id'] || null,
      'idempotency-key': req.headers()['idempotency-key'] || null,
    },
    post_data_keys: safePostDataKeys(req.postData()),
  });
  await route.continue({ url: apiUrl });
});

const summary = {
  run_id: runId,
  tenant_id: tenantId,
  rows: {},
  requests,
  console_warnings: consoleWarnings,
  mobile: {},
};

async function login(scope) {
  await context.clearCookies();
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
  await page.evaluate(() => {
    sessionStorage.clear();
    localStorage.clear();
  }).catch(() => null);
  await page.goto(`${baseUrl}/login`, { waitUntil: 'domcontentloaded' });
  await page.locator('input[type="email"]').fill(scope === 'central' ? centralEmail : tenantEmail);
  await page.locator('input[type="password"]').fill(scope === 'central' ? centralPassword : tenantPassword);
  await page.locator('select').selectOption(scope);
  if (scope === 'tenant') {
    await page.locator('input[placeholder="Required for tenant login"]').fill(tenantId);
  }
  try {
    await Promise.all([
      page.waitForURL(`**/admin/${scope}/dashboard`, { timeout: 30000 }),
      page.getByRole('button', { name: 'Sign in' }).click(),
    ]);
    await page.waitForLoadState('networkidle');
  } catch (error) {
    if (scope !== 'tenant') throw error;
    await directSessionLogin(scope);
  }
}

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
    throw new Error(`Direct ${scope} login failed: ${response.status}`);
  }
  const auth = await response.json();
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
  await page.evaluate(({ auth, scope, tenantId }) => {
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
  await page.goto(`${baseUrl}/admin/${scope}/dashboard`, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle');
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
  await page.waitForLoadState('networkidle');
  await page.screenshot({ path: `${outDir}/${screenshotName}`, fullPage: true });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle');
  const loginVisibleAfterReload = await page.locator('text=Admin sign in').count();
  return {
    route: page.url().replace(baseUrl, ''),
    menu_link_count: linkCount,
    hard_refresh_kept_session: loginVisibleAfterReload === 0,
  };
}

async function modalText() {
  return (await page.locator('.modal.show').last().innerText()).replace(/\s+/g, ' ').trim();
}

async function openButton(name) {
  await page.getByRole('button', { name }).first().click();
  await page.locator('.modal.show').last().waitFor({ state: 'visible' });
}

async function cancelModal() {
  const cancel = page.getByRole('button', { name: 'Cancel' }).last();
  if (await cancel.count()) {
    await cancel.click();
  } else {
    await page.getByRole('button', { name: 'Close' }).last().click();
  }
  await page.waitForTimeout(250);
}

async function formPresence(labels) {
  const result = {};
  for (const label of labels) {
    result[label] = await page.getByText(label, { exact: false }).count();
  }
  const confirm = page.getByRole('button', { name: 'Confirm' }).last();
  result.confirm_disabled_initially = await confirm.isDisabled().catch(() => null);
  return result;
}

async function inspectOperationsRow(scope, rowKey, href, labels, updateLabel, deleteLabel) {
  const opened = await openFromMenu(href, `${rowKey}-list.png`);
  const row = { ...opened };
  row.real_api_rows_visible = await page.locator('table tbody tr').count();

  await openButton(labels.createButton);
  row.create_modal = {
    text_has_reason: (await modalText()).includes('Reason'),
    fields: await formPresence(labels.createFields),
  };
  await page.screenshot({ path: `${outDir}/${rowKey}-create-modal.png`, fullPage: true });
  await cancelModal();

  await openButton(updateLabel);
  const updateText = await modalText();
  row.update_modal = {
    has_context: /Record|Status|Role|Email|Permission|Id|Name/i.test(updateText),
    text: updateText.slice(0, 600),
    fields: await formPresence(labels.updateFields),
  };
  await page.screenshot({ path: `${outDir}/${rowKey}-update-modal.png`, fullPage: true });
  await cancelModal();

  await openButton(deleteLabel);
  const deleteText = await modalText();
  row.delete_or_archive_modal = {
    has_reason: deleteText.includes('Reason'),
    has_context: /Record|Status|Role|Email|Permission|Id|Name|Tenant/i.test(deleteText),
    confirm_disabled_without_reason: await page.getByRole('button', { name: 'Confirm' }).last().isDisabled(),
    text: deleteText.slice(0, 600),
  };
  await page.screenshot({ path: `${outDir}/${rowKey}-danger-modal.png`, fullPage: true });
  await cancelModal();

  summary.rows[`${scope}:${rowKey}`] = row;
}

async function inspectCentralSettings() {
  const opened = await openFromMenu('/admin/central/system-settings', 'central-system-settings.png');
  const labels = ['Platform name', 'Admin API version', 'Release gate note', 'BO backend gap status'];
  const fields = {};
  for (const label of labels) fields[label] = await page.getByText(label, { exact: false }).count();
  summary.rows['central:system_settings'] = {
    ...opened,
    typed_field_counts: fields,
    json_editor_count: await page.locator('.np-admin-json-editor').count(),
    save_button_visible: await page.getByRole('button', { name: 'Save' }).count(),
  };
  await page.screenshot({ path: `${outDir}/central-system-settings-fields.png`, fullPage: true });
}

async function inspectTenantSettings() {
  const opened = await openFromMenu('/admin/tenant/settings', 'tenant-settings.png');
  const labels = ['Site name', 'SEO title', 'Maintenance active', 'API base URL', 'Logo URL', 'Primary color'];
  const fields = {};
  for (const label of labels) fields[label] = await page.getByText(label, { exact: false }).count();

  await openButton('Add domain');
  const addDomainText = await modalText();
  const addDomain = {
    has_host: addDomainText.includes('Host'),
    has_status: addDomainText.includes('Status'),
    has_primary: addDomainText.includes('Primary domain'),
    has_reason: addDomainText.includes('Reason'),
    confirm_disabled_without_reason_or_host: await page.getByRole('button', { name: 'Confirm' }).last().isDisabled(),
  };
  await page.screenshot({ path: `${outDir}/tenant-settings-add-domain-modal.png`, fullPage: true });
  await cancelModal();

  await page.getByRole('button', { name: 'Detail' }).first().click();
  await page.locator('.modal.show').last().waitFor({ state: 'visible' });
  const detailText = await modalText();
  const detail = {
    has_host_context: /Host|Domain|Status|Primary/i.test(detailText),
  };
  await page.screenshot({ path: `${outDir}/tenant-settings-domain-detail.png`, fullPage: true });
  await cancelModal();

  await openButton('Verify');
  const verifyText = await modalText();
  const verify = {
    has_domain_context: /Host|Domain|Status|Readiness|Tenant/i.test(verifyText),
    has_reason: verifyText.includes('Reason'),
    confirm_disabled_without_reason: await page.getByRole('button', { name: 'Confirm' }).last().isDisabled(),
  };
  await page.screenshot({ path: `${outDir}/tenant-settings-domain-verify-modal.png`, fullPage: true });
  await cancelModal();

  await openButton('Delete');
  const deleteText = await modalText();
  const deleteModal = {
    has_domain_context: /Host|Domain|Status|Tenant/i.test(deleteText),
    has_reason: deleteText.includes('Reason'),
    confirm_disabled_without_reason: await page.getByRole('button', { name: 'Confirm' }).last().isDisabled(),
  };
  await page.screenshot({ path: `${outDir}/tenant-settings-domain-delete-modal.png`, fullPage: true });
  await cancelModal();

  summary.rows['tenant:settings'] = {
    ...opened,
    typed_field_counts: fields,
    add_domain: addDomain,
    domain_detail: detail,
    verify_modal: verify,
    delete_modal: deleteModal,
  };
}

async function inspectSupportAccess() {
  const opened = await openFromMenu('/admin/tenant/support-access', 'tenant-support-access-list.png');
  await page.getByRole('button', { name: 'New request' }).click();
  await page.locator('.modal.show').last().waitFor({ state: 'visible' });
  const createText = await modalText();
  const create = {
    has_contract_scopes: createText.includes('Customer Read') && createText.includes('Elevated Action'),
    has_allowed_target_types: createText.includes('Customer') && createText.includes('Tenant Admin'),
    has_ticket_and_reason: createText.includes('Ticket ID') && createText.includes('Reason'),
  };
  const modal = page.locator('.modal.show').last();
  await modal.locator('input').nth(0).fill(apiEvidence.tenant_support_access_logs.customer_fixture_id);
  await modal.locator('input').nth(1).fill(`SUP-BROWSER-${runId}`);
  await modal.locator('textarea').fill(`Browser support request ${runId}`);
  const createResponse = page.waitForResponse((res) => res.url().includes('/api/v1/admin/tenant/support-access') && res.request().method() === 'POST');
  await page.getByRole('button', { name: 'Create request' }).click();
  const createStatus = (await createResponse).status();
  await page.waitForURL('**/admin/tenant/support-access/**');
  await page.waitForLoadState('networkidle');
  await page.screenshot({ path: `${outDir}/tenant-support-access-detail.png`, fullPage: true });

  const buttonsDisabled = {};
  for (const name of ['Approve', 'Revoke', 'Start impersonation', 'Log elevated action', 'End session']) {
    buttonsDisabled[name] = await page.getByRole('button', { name }).isDisabled().catch(() => null);
  }
  await page.locator('input[placeholder="Required for write actions"]').fill(`Browser support action ${runId}`);
  const buttonsEnabledWithReason = {};
  for (const name of ['Approve', 'Revoke', 'Start impersonation', 'Log elevated action', 'End session']) {
    buttonsEnabledWithReason[name] = !(await page.getByRole('button', { name }).isDisabled().catch(() => true));
  }
  const approveResponse = page.waitForResponse((res) => res.url().includes('/approve') && res.request().method() === 'POST');
  await page.getByRole('button', { name: 'Approve' }).click();
  const approveStatus = (await approveResponse).status();
  await page.waitForLoadState('networkidle');

  summary.rows['tenant:support_access_logs'] = {
    ...opened,
    create_modal: create,
    create_status: createStatus,
    reason_guard_disabled_initially: buttonsDisabled,
    actions_enabled_with_reason: buttonsEnabledWithReason,
    approve_status: approveStatus,
    token_text_visible_after_approve: await page.locator('.np-support-token').count(),
  };
}

async function mobileSanity(scope, href, fileName) {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${baseUrl}${href}`, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle');
  await page.screenshot({ path: `${outDir}/${fileName}`, fullPage: true });
  summary.mobile[`${scope}:${href}`] = {
    url: page.url().replace(baseUrl, ''),
    login_visible: await page.locator('text=Admin sign in').count(),
    body_width: await page.evaluate(() => document.documentElement.scrollWidth),
    viewport_width: 390,
  };
  await page.setViewportSize({ width: 1440, height: 1100 });
}

await login('central');
await inspectOperationsRow('central', 'admin_users', '/admin/central/admin-users', {
  createButton: 'Create admin user',
  createFields: ['Name', 'Email', 'Temporary password', 'Status', 'Role IDs', 'Reason'],
  updateFields: ['Name', 'Email', 'Phone', 'Status', 'Temporary password', 'Role IDs', 'Reason'],
}, 'Update', 'Disable');
await inspectOperationsRow('central', 'roles_permissions', '/admin/central/roles', {
  createButton: 'Create role',
  createFields: ['Role name', 'Role code', 'Status', 'Permission codes', 'Reason'],
  updateFields: ['Role name', 'Role code', 'Status', 'Permission codes', 'Reason'],
}, 'Update', 'Archive');
await inspectCentralSettings();
await mobileSanity('central', '/admin/central/admin-users', 'mobile-central-admin-users.png');

await login('tenant');
await inspectOperationsRow('tenant', 'admin_users', '/admin/tenant/admin-users', {
  createButton: 'Create admin user',
  createFields: ['Name', 'Email', 'Send invitation', 'Role IDs', 'Reason'],
  updateFields: ['Name', 'Email', 'Phone', 'Status', 'Temporary password', 'Role IDs', 'Reason'],
}, 'Update', 'Disable');
await inspectOperationsRow('tenant', 'roles_permissions', '/admin/tenant/roles', {
  createButton: 'Create role',
  createFields: ['Role name', 'Role code', 'Status', 'Permission codes', 'Reason'],
  updateFields: ['Role name', 'Role code', 'Status', 'Permission codes', 'Reason'],
}, 'Update', 'Archive');
await inspectSupportAccess();
await inspectTenantSettings();
await mobileSanity('tenant', '/admin/tenant/settings', 'mobile-tenant-settings.png');

fs.writeFileSync(`${outDir}/browser-summary.json`, JSON.stringify(summary, null, 2));
await browser.close();

function safePostDataKeys(raw) {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return Object.keys(parsed).filter((key) => !/password|token|secret/i.test(key)).sort();
  } catch {
    return ['unparseable'];
  }
}
