# Backend Request Validation

## Conventions

Dedicated request validators live with their owning backend modules. Cross-cutting payload primitives remain shared.

```text
App\Shared\Validation\RequestPayloadValidator shared JSON, Laravel validator, money/date helpers
App\Modules\Growth\Http\Requests\ReportRequestValidator report query/export validation
App\Modules\Commerce\Http\Requests\CommerceRequestValidator checkout, reservation, topup, wallet/admin commerce validation
App\Modules\Growth\Http\Requests\GrowthRequestValidator affiliate payout and approval action validation
App\Modules\Reward\Http\Requests\RewardClaimRequestValidator customer and tenant reward claim validation
App\Modules\Maintenance\Http\Requests\MaintenanceRequestValidator maintenance and bypass validation
App\Modules\SupportAccess\Http\Requests\SupportAccessRequestValidator support access and impersonation action validation
App\Shared\Http\RequestHeaderValidator centralized Idempotency-Key validation
```

Controllers call these validators before service mutation. Idempotent write helpers check `Idempotency-Key`, then payload/query validation, then call services. Services still keep domain integrity checks where they need locks, database state, or aggregate context.

## Error Envelope

Validation failures continue to use `ApiErrorResponse::validationFailed`:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "The request payload is invalid.",
    "details": {
      "fields": {}
    },
    "request_id": null
  }
}
```

No default Laravel validation redirect or raw exception detail is exposed.

## Endpoint Coverage

| Endpoint Group | Validation Coverage |
| --- | --- |
| customer reservation create/release | `RequestHeaderValidator`, `CommerceRequestValidator`, PartnerStore domain availability checks |
| customer checkout | `RequestHeaderValidator`, `CommerceRequestValidator` |
| customer topup/create credit | `RequestHeaderValidator`, `CommerceRequestValidator` |
| customer reward claim | `RequestHeaderValidator`, `RewardClaimRequestValidator` |
| tenant wallet adjustment | `RequestHeaderValidator`, `CommerceRequestValidator` |
| tenant topup approve/reject/cancel | `RequestHeaderValidator`, `CommerceRequestValidator` |
| tenant reward claim approve/reject/pay | `RequestHeaderValidator`, `RewardClaimRequestValidator` |
| tenant affiliate payout create/approve | `RequestHeaderValidator`, `GrowthRequestValidator` |
| tenant commission approve | `RequestHeaderValidator`, `GrowthRequestValidator` |
| tenant and central report query/export | `ReportRequestValidator`, `RequestHeaderValidator` for exports |
| central settlement approve | `RequestHeaderValidator`, `GrowthRequestValidator` |
| tenant maintenance update/events/bypasses | `RequestHeaderValidator`, `MaintenanceRequestValidator`; bypass list validates bounded `cursor`, `limit`, and `status` filters |
| tenant support access request/approve/revoke/impersonate/elevated/end-session | `RequestHeaderValidator`, `SupportAccessRequestValidator` |
| partner, RBAC, stock, reward-result writes | existing controller service validators, still returning `ApiErrorResponse::validationFailed` |

Validation before idempotency success storage is covered by focused tests for report exports and wallet adjustment. Service-level validation that needs database state still runs inside the service before response storage.

M9 support access validation also verifies tenant ownership for customer targets and tenant admin targets before any support request is written.
