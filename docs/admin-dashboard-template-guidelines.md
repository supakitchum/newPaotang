# Admin Dashboard Template Frontend Guidelines

เอกสารนี้เป็นแนวทางให้ `back-office` frontend ใช้ `admin_dashboard_template` เป็น source of truth สำหรับหน้าหลังบ้านของ NewPaotang

## Template Source

ใช้ template หลักจาก:

```text
admin_dashboard_template/Meno_esbuild
```

เหตุผล:

```text
มี source HTML, SCSS, JS และ dist assets ครบ
ใช้ Bootstrap 5.3.3
มี partial layout พร้อมใช้
มีหน้า dashboard, table, form, auth, error, maintenance และ ecommerce/admin examples จำนวนมาก
```

มี `Meno_gulp` ด้วย แต่ให้ถือว่า `Meno_esbuild` เป็น reference หลักเพื่อหลีกเลี่ยง source ซ้ำหลายชุด

## License Requirement

Template เป็น product ของ Spruko Technologies และมี license notice อยู่ที่:

```text
admin_dashboard_template/Legal Agreement & Copyright Notice.txt
```

ก่อนนำ template ไปใช้จริงใน product, staging, production หรือส่งมอบลูกค้า ต้องยืนยันว่า project มี license ที่ถูกต้องแล้ว ห้ามลบ license notice จาก template source โดยไม่ตรวจสิทธิ์

## Frontend Rule

ทุกหน้า admin ใน `apps/back-office` ต้องยึด Meno template ก่อนเสมอ

```text
ถ้า template มี layout/component/page pattern อยู่แล้ว ให้ดึงมาใช้หรือแปลงเป็น Nuxt/Vue component
ถ้า template ไม่มีจริง ๆ ถึงค่อยสร้าง component ใหม่
component ใหม่ต้องใช้ class, spacing, card, table, form, button, badge, dropdown, modal และ icon style ตาม template
ห้ามออกแบบ admin UI style ใหม่ที่ไม่เข้ากับ Meno โดยไม่มี approval
```

## Template Partials To Convert First

ให้แปลง partials เหล่านี้เป็น Nuxt/Vue components ก่อนทำหน้า admin:

| Template File | Nuxt Component | Purpose |
| --- | --- | --- |
| `src/html/partials/mainhead.html` | `AdminHtmlHead` or Nuxt head/plugin mapping | CSS/JS dependency contract |
| `src/html/partials/header.html` | `AdminHeader.vue` | top navigation, search, theme toggle, user menu |
| `src/html/partials/sidebar.html` | `AdminSidebar.vue` | dynamic RBAC menu |
| `src/html/partials/footer.html` | `AdminFooter.vue` | admin footer |
| `src/html/partials/loader.html` | `AdminLoader.vue` | initial/loading state |
| `src/html/partials/switcher.html` | `AdminThemeSwitcher.vue` | theme/layout switcher if enabled |
| `src/html/partials/responsive-search-modal.html` | `AdminSearchModal.vue` | mobile search |
| `src/html/partials/commonjs.html` | Nuxt plugin/import list | common JS behavior |

Layout target:

```text
apps/back-office/app/layouts/admin.vue
```

Suggested layout shape:

```text
<div class="page">
  <AdminHeader />
  <AdminSidebar :menus="menus" />
  <main class="main-content app-content">
    <div class="container-fluid">
      <slot />
    </div>
  </main>
  <AdminFooter />
</div>
```

## Assets To Reuse

Source assets:

```text
admin_dashboard_template/Meno_esbuild/src/assets/scss/styles.scss
admin_dashboard_template/Meno_esbuild/src/assets/scss/icons.scss
admin_dashboard_template/Meno_esbuild/src/assets/scss/_variables.scss
admin_dashboard_template/Meno_esbuild/src/assets/scss/_switcher.scss
admin_dashboard_template/Meno_esbuild/src/assets/js/main.js
admin_dashboard_template/Meno_esbuild/src/assets/js/custom.js
admin_dashboard_template/Meno_esbuild/src/assets/js/defaultmenu.min.js
admin_dashboard_template/Meno_esbuild/src/assets/images
admin_dashboard_template/Meno_esbuild/src/assets/icon-fonts
```

Compiled assets are available in:

```text
admin_dashboard_template/Meno_esbuild/dist/assets
```

Implementation options:

```text
Option A: copy required compiled CSS/JS/assets into Nuxt public/admin-template and load them from admin layout
Option B: import SCSS and selected JS into Nuxt build after adding required dependencies
```

เริ่มต้นแนะนำ Option A เพื่อให้หน้าหลังบ้านใกล้ template ที่สุดและลดเวลาปรับ theme จากนั้นค่อย refactor เป็น SCSS import เมื่อ layout stable แล้ว

## Required Dependencies

Template dependency list อยู่ที่:

```text
admin_dashboard_template/Dependencies.txt
```

Core dependencies ที่ back-office ควรเริ่มใช้:

```text
bootstrap 5.3.3
@popperjs/core
simplebar
node-waves
choices.js
flatpickr
apexcharts
sweetalert2
toastify-js
datatables.net-bs5 or a Vue-compatible table wrapper that preserves Meno table styling
```

ห้ามติดตั้ง dependency ทั้งหมดใน template โดยอัตโนมัติ ให้เพิ่มเฉพาะที่หน้าปัจจุบันใช้จริง

## Page Pattern Mapping

หากหน้า NewPaotang ตรงกับหน้าใน template ให้ใช้ template page นั้นเป็นฐาน

| NewPaotang Admin Page | Template Reference | Notes |
| --- | --- | --- |
| Central dashboard | `index.html`, `index2.html`, `widgets.html` | KPI cards, charts, recent activity |
| Tenant dashboard | `index.html`, `ecommerce-dashboard.js`, `widgets.html` | sales/order/stock widgets |
| Stock list | `products-list.html`, `data-tables.html`, `tables.html` | table, filter, status badge, bulk action |
| Stock generation/import | `add-products.html`, `form-file-uploads.html`, `form-wizards.html` | upload/import wizard |
| Allocation/quota form | `form-layout.html`, `form-validation.html`, `form-advanced.html` | validated admin form |
| Partner list | `crm-companies.html`, `data-tables.html` | partner cards/table |
| Partner detail | `crm-contacts.html`, `profile.html`, `projects-overview.html` | overview, tabs, activity |
| Orders | `orders.html`, `order-details.html` | order table/detail |
| Checkout/payment admin | `checkout.html`, `invoice-details.html`, `invoice-list.html` | payment detail and invoice pattern |
| Wallet/topup | `crypto-wallet.html`, `crypto-transactions.html` | ledger and transaction list |
| Customers | `crm-contacts.html`, `profile.html` | customer profile/list |
| Agents/affiliate | `team.html`, `crm-leads.html`, `crm-deals.html` | account, attribution, commission pipeline |
| SEO settings | `form-layout.html`, `form-inputs.html`, `form-validation.html` | metadata form |
| Domain/white label settings | `domains-admin.js` related pages if used, otherwise `form-layout.html` | domain status cards/forms |
| Maintenance | `under-maintenance.html`, `form-layout.html`, `alerts.html` | branded preview and mode form |
| Support access | `profile.html`, `timeline.html`, `modals-closes.html` | request detail, approval, audit timeline |
| Audit logs | `timeline.html`, `data-tables.html` | immutable log list/detail |
| Reports | `apex-*.html`, `chartjs-charts.html`, `data-tables.html` | charts and export actions |
| Login | `sign-in-basic.html` or `sign-in-cover.html` | admin auth page |
| Create/reset password | `create-password-basic.html`, `reset-password-basic.html` | auth flows |
| 2FA | `two-step-verification-basic.html` | verification UI |
| Errors | `401-error.html`, `404-error.html`, `500-error.html` | admin error pages |

## Component Inventory To Reuse

ให้สร้าง Vue components จาก pattern ที่ template มีอยู่แล้ว:

```text
AdminPageHeader
AdminKpiCard
AdminChartCard
AdminDataTable
AdminFilterBar
AdminStatusBadge
AdminActionDropdown
AdminFormSection
AdminFormWizard
AdminModal
AdminToast
AdminAlert
AdminEmptyState
AdminTimeline
AdminProfileHeader
AdminTabs
AdminPagination
AdminFileUpload
AdminDateRangePicker
AdminPermissionGuard
```

Component เหล่านี้ต้องใช้ class ของ Meno เช่น:

```text
card custom-card
card-header
card-title
btn btn-primary btn-wave
btn-icon
badge
avatar
main-content app-content
page-header-breadcrumb
table text-nowrap
dropdown-menu
modal
alert
```

## Menu And Permission Integration

Sidebar ต้องไม่ hardcode menu จริงใน frontend

```text
AdminSidebar รับ menu จาก backend `GET /api/v1/admin/tenant/menu` หรือ central menu endpoint
Frontend ซ่อนเมนูตาม backend response เท่านั้น
Backend permission ยังเป็น source of truth เสมอ
ทุก admin API ต้อง handle 403 ด้วย Meno alert/toast/error pattern
```

Back-office API ที่ frontend ต้องผูกกับ OpenAPI ปัจจุบัน:

| Page Area | API |
| --- | --- |
| Admin auth | `POST /api/v1/auth/admin/login`, `POST /api/v1/auth/admin/refresh`, `POST /api/v1/auth/admin/logout`, `GET /api/v1/auth/admin/me`, password endpoints, and `/api/v1/auth/admin/2fa*` |
| Tenant admin users | `GET/POST /api/v1/admin/tenant/admin-users`, `GET/PATCH/DELETE /api/v1/admin/tenant/admin-users/{admin_user_id}`, and `POST .../{admin_user_id}/invitation`; create uses username and returns a copy/share link instead of sending email |
| Tenant roles/permissions | `GET/POST /api/v1/admin/tenant/roles`, `PATCH/DELETE /api/v1/admin/tenant/roles/{role_id}` |
| Tenant members/customers | `GET/POST /api/v1/admin/tenant/members`, `GET/PATCH /api/v1/admin/tenant/members/{member_id}`, `POST /api/v1/admin/tenant/members/{member_id}/status` |
| Tenant orders | `GET /api/v1/admin/tenant/orders`, `GET/PATCH /api/v1/admin/tenant/orders/{order_id}`, `POST /api/v1/admin/tenant/orders/{order_id}/cancel`, `POST /api/v1/admin/tenant/orders/{order_id}/refund` |
| Tenant tickets | `GET /api/v1/admin/tenant/tickets`, `GET /api/v1/admin/tenant/tickets/{ticket_id}` |
| Tenant topups | `GET /api/v1/admin/tenant/topups`, `GET /api/v1/admin/tenant/topups/{topup_id}`, `POST /api/v1/admin/tenant/topups/{topup_id}/approve`, `POST /api/v1/admin/tenant/topups/{topup_id}/reject`, `POST /api/v1/admin/tenant/topups/{topup_id}/cancel` |
| Tenant reward cashout | `GET /api/v1/admin/tenant/reward-claims`, `GET /api/v1/admin/tenant/reward-claims/{claim_id}`, `POST /api/v1/admin/tenant/reward-claims/{claim_id}/approve`, `POST /api/v1/admin/tenant/reward-claims/{claim_id}/reject`, `POST /api/v1/admin/tenant/reward-claims/{claim_id}/pay` |
| Tenant operations | dashboard, stock list/detail/export, stock-sync, price rules, reservations, wallets/ledger, agents, affiliate programs/links/attributions/accounts, commission rules/transactions, payouts, audit logs, sync logs, export job status/download under `/api/v1/admin/tenant/*` |
| Tenant site config | settings, theme, asset upload/commit, payment settings/channels, SEO, SEO pages, redirects, domains CRUD/verify, maintenance events/bypasses, menu management under `/api/v1/admin/tenant/*` |
| Tenant support access | `GET/POST /api/v1/admin/tenant/support-access`, detail, approve/revoke, impersonate, elevated-actions, and end-session endpoints |
| Central operations | dashboard, central admin users, roles, partner provisioning, partner quotas, partner API clients, game lifecycle, stock import/generate/export/recall, allocation list/detail/cancel, reward operations, settlement, monitoring, usage, billing plans/bindings, alert policies/events, asset upload/commit, export job status/download, system settings, webhook logs, audit logs, sync logs under `/api/v1/admin/central/*` |
| Realtime auth | `POST /api/v1/admin/central/realtime/auth`, `POST /api/v1/admin/tenant/realtime/auth` |
| Provider callbacks | payment/topup callbacks under `/api/v1/webhooks/*` are backend-only; back-office reads them from central webhook logs |
| Central reports | `GET /api/v1/admin/central/reports/{report_key}`, `POST /api/v1/admin/central/reports/{report_key}/exports` |
| Tenant reports | `GET /api/v1/admin/tenant/reports/{report_key}`, `POST /api/v1/admin/tenant/reports/{report_key}/exports` |

Tenant pages must send `X-Admin-Scope: tenant` and `X-Tenant-Id`. Central report pages must send `X-Admin-Scope: central`.

Menu item จาก backend ควร map เข้า structure ของ Meno:

```text
category -> slide__category
group with children -> li.slide.has-sub
leaf item -> li.slide > NuxtLink.side-menu__item
icon -> side-menu__icon
label -> side-menu__label
```

## Admin Layout Behavior

ต้องรักษา behavior ของ template:

```text
vertical sidebar
sticky header
responsive sidebar toggle
mobile search modal
light/dark theme support if enabled
simplebar sidebar scroll
dropdown and tooltip behavior via Bootstrap
btn-wave interaction
```

ถ้าใช้ template JS ตรง ๆ ใน Nuxt ต้อง initialize เฉพาะ client-side เท่านั้น เพื่อไม่ให้ SSR error

## Charts, Tables, Forms

Charts:

```text
ใช้ ApexCharts pattern จาก `apex-*.html` และ dashboard JS files
อย่า hand-roll chart style ใหม่
dashboard cards ต้องใช้ `card custom-card`
```

Tables:

```text
ใช้ table structure จาก `data-tables.html`, `tables.html`, `grid-tables.html`
ทุก table ต้องมี loading, empty, error, pagination, filter state
status ใช้ badge style จาก template
row actions ใช้ dropdown/button icon style จาก template
```

Forms:

```text
ใช้ pattern จาก `form-layout.html`, `form-inputs.html`, `form-select.html`, `form-validation.html`
multi-step flows ใช้ `form-wizards.html`
date/time ใช้ `form-datetime-pickers.html`
file upload ใช้ `form-file-uploads.html`
validation error ต้องแสดงใน Bootstrap/Meno invalid feedback style
```

## Admin Page States

ทุกหน้า admin ต้องมี state เหล่านี้โดยใช้ template component:

```text
loading -> AdminLoader or skeleton card matching Meno
empty -> pattern from `empty.html`
error -> alert/toast plus error page for fatal errors
403 -> `401-error.html` pattern adjusted to permission denied
404 -> `404-error.html`
500 -> `500-error.html`
maintenance -> `under-maintenance.html` pattern
confirm destructive action -> SweetAlert2 pattern from `sweet-alerts.html`
```

## Implementation Ownership

Frontend-owned files:

```text
apps/back-office/app/layouts/admin.vue
apps/back-office/app/components/admin/*
apps/back-office/app/pages/**
apps/back-office/app/plugins/admin-template.client.ts
apps/back-office/public/admin-template/**
docs/admin-dashboard-template-guidelines.md
```

Do not edit backend logic from frontend template work. If an API or menu field is missing, add a contract note or coordinate OpenAPI changes.

## Import Plan

Recommended implementation sequence:

```text
1. Copy Meno compiled assets needed by back-office into `apps/back-office/public/admin-template`.
2. Add Bootstrap/client plugin initialization for dropdown, tooltip, sidebar toggle, and simplebar.
3. Build `layouts/admin.vue` from Meno page structure.
4. Convert `header.html` and `sidebar.html` into Vue components.
5. Replace static sidebar items with backend menu response shape.
6. Convert shared components: page header, card, table, form section, badge, modal, toast.
7. Implement admin dashboard using `index.html`/`widgets.html` patterns.
8. Implement each admin page by mapping to an existing template page before creating new layout.
9. Verify responsive desktop/mobile and dark/light behavior.
```

## Review Checklist

ก่อนส่งงาน frontend admin ให้ตรวจ:

```text
uses Meno layout/classes/assets
does not introduce a separate admin design system
reuses existing template page when available
sidebar menu is dynamic and permission-driven
403/404/500/loading/empty states exist
forms show validation using template style
tables have pagination/filter/loading/error states
charts use template chart style
admin JS runs client-side only
license notice remains available
```
