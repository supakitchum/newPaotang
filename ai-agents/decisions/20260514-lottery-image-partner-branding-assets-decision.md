# Lottery Image Partner Branding Assets Decision

Date: 2026-05-14
Owner: Coordinator
Task: `lottery-image-partner-branding-assets`

## Context

The user added a required rule for partner-branded lottery image assets:

```text
central ต้องสามารถแก้ไขรูป logo_qr,right_sidebar,logo_bottom ของ partner ได้
partner ห้ามแก้ไขเองเด็ดขาด
logo_qr,right_sidebar,logo_bottom จะเปลี่ยนได้ก็ต่อเมื่อยังไม่มีการผลิตรูปของ partner นั้นๆเลยสักชิ้น
ทำ form สำหรับอัพโหลดรูปพวกนี้ด้วย
```

This extends the existing lottery image generation design. Central base images remain unbranded. Partner-branded images apply partner-specific `logo_qr`, `right_sidebar`, and `logo_bottom` only after stock is allocated/synced to that partner.

## Decision

Partner branding assets are central-owned operational assets.

Central BO must provide a form for managing:

```text
logo_qr
right_sidebar
logo_bottom
```

Partner/tenant users must not have any UI route or API capability to upload, edit, delete, or activate these assets.

## Lock Rule

The assets are editable only while the partner has no produced partner-branded lottery images.

```text
editable = partner_generated_image_count == 0
locked = partner_generated_image_count > 0
```

The backend must enforce the lock. BO disabled states are only UX, not the source of truth.

If a future production case requires changing partner branding after images already exist, open a separate Coordinator decision covering regeneration/version migration.

## Backend Requirements

Backend Develop must add or expose:

```text
central-only asset upload/update API
partner branding asset metadata and storage paths
asset preview/read response for central BO
lock status and generated image count
authorization that rejects partner/tenant edits
business guard that rejects central edits after first produced partner image
tests for central-only access and lock behavior
```

Suggested private object keys:

```text
lottery-image-assets/partners/{partner_id}/branding/{version}/logo_qr.webp
lottery-image-assets/partners/{partner_id}/branding/{version}/right_sidebar.webp
lottery-image-assets/partners/{partner_id}/branding/{version}/logo_bottom.webp
```

## BO Requirements

BO Develop must add a central-only upload/edit form on the central partner management surface.

Suggested route:

```text
/admin/central/partners/{partner_id}/lottery-branding
```

The form must:

```text
upload logo_qr, right_sidebar, and logo_bottom
show current previews
show lock status
show generated image count
disable save/replace while locked
display backend rejection clearly if a race locks the partner before save
call only central admin APIs
not add any tenant/partner-side editing route
```

## Source Of Truth

```text
docs/lottery-image-generation.md
ai-agents/tasks/20260513-lottery-image-generation-s3-backend.md
ai-agents/tasks/20260514-lottery-image-partner-branding-assets-bo.md
```

## Next Agent

```text
Orchestrator
```
