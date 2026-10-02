# Targeted Contract QA Plan

Snapshot: canonical develop c8f130cdcc1a1addc3a7526597bd7a17107d574d plus intentional dirty delivery and Coordinator docs, with fingerprints checked against dispatch. No implementation changes.

| Case | Expected | Method |
| --- | --- | --- |
| All internal refs and complete OpenAPI 3.1 document | Resolve / valid document | Independent Python OpenAPI validator in disposable Docker |
| Minimal existing-phone probe | Request-schema valid | JSON Schema 2020-12 |
| Legacy blank member fields, false terms | Request-schema valid | JSON Schema 2020-12 |
| Full new member, omitted existing_only / confirmation fallback | Request-schema valid; backend conditional validation retained | Schema plus unchanged service/client trace and prior tests |
| Missing universal field / nonboolean existing_only | Request-schema invalid | Negative schema cases |
| Registration-required top-level response, true only, no wrappers | Valid only for documented branch | Schema / actual controller with stubbed service |
| Auth-session top-level response for four providers and legacy LINE | Schema valid with populated and optional-empty profile | Real profile serializer and controller; no database / HTTP middleware / provider exchange |
| OTP tenant/phone/purpose/TTL/consumption, inactive/suspended/conflicting identity | Preserved guards / no account disclosure before OTP | Unchanged source trace and verified prior 42+3 test evidence |
| Flutter/Nuxt probe/member/session/PIN/redirect | Match documented flow without weakening form rules | Unchanged client trace and verified prior regressions |
| Shared runtime/login URLs | Observe only, stopped services remain stopped | Selected Docker fields and unauthenticated curl |
| Native/providers/Nuxt auth/production timing | NOT TESTED until exact prerequisites authorized | Prerequisite matrix only |

Missing assertion reason for new PHP runner: prior regressions assert branch fields but never feed the production profile's nullable/empty-bank JSON and controller top-level serialization into the corrected response schema. The runner stubs partner/auth services and Wallet lookup, invokes the actual profile serializer and public linkPhone controllers, and asserts their exact top-level JSON. It has no app bootstrap, DB connection or issued token. Network is disabled; application/vendor mounts are read-only. Session scalar fields use a fictional envelope traced from issueSession; this is not fresh DB-backed or real-provider login acceptance.

No full application suites/builds, migrations, service recovery, seed, cache smoke, credential/account changes, installation, SMS or deployment. Reuse prior evidence only after all 269 manifest entries and source/report hashes match. Preserve the original artifact tree, report, contract docs, Board and decision.
