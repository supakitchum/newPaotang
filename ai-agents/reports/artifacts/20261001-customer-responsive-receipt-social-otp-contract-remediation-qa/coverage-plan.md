# Independent Remediation Confirmation

Only Coordinator's four-field CustomerProfile correction is under review. Application snapshot and prior fixture provenance must match dispatch before reuse.

| Criterion | Verification |
| --- | --- |
| Full OpenAPI 3.1 / internal refs | Fresh isolated Python specification validator, not copied Coordinator results |
| Prior 48 request/response/profile cases | Unmodified, hash-identical QA validator rerun on corrected docs; fixtures copied only after 31-entry prior manifest verification |
| Null/string/type/format constraints | Independent null/populated-string and number/boolean/array/object boundaries for email/avatar/locale; invalid email/URI reject |
| Bank object/null/empty-array | All three accepted; nonempty arrays/scalars/incomplete/wrong-type objects rejected; optional string branch retained |
| Both endpoint shapes / five provider routes | Prior controller/profile fixtures reused; schema validations freshly executed; no new PHP/HTTP/provider claims |
| Correction scope | Request/auth/registration/union schemas and other profile properties unchanged; no compatibility normalization |
| Runtime/native acceptance | Prior QA-G02/QA-G03 limitations and prerequisites retained, not rerun or waived |

New isolated schema runner mounts root source/docs read-only and only this evidence directory writable. Dependencies are in disposable /tmp. No PHP runner, DB access, runtime inventory/recovery, migration, seed, build, device/SMS/provider/account/purchase/deployment operations are included. Coordinator's successful checks and prior failed checks remain preserved, labeled prior evidence rather than fresh independent approval.
