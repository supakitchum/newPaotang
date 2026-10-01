# Scoped Main Integration Verification

Date: 2026-10-01, Asia/Bangkok
Owner: Coordinator
Delivery: customer-responsive-receipt-social-otp

## Acceptance and Scope

The user confirmed remaining testing was completed and requested closure and main integration. QA-G02 / QA-G03 are closed by user acceptance. This report records additional source integration checks; historical QA reports retain their original observations.

Stage the receipt/news/social OTP delivery only. Preserve concurrent source changes and raw local QA evidence. The working localization file retains its unstaged push-channel/account-deletion hunks.

## Fresh Checks

- Exported the staged Flutter tree with `git archive` and checked it in a disposable cached Flutter Docker runner. No shared runtime or database was used.
- `flutter analyze --no-pub`: no issues found, 20.2 seconds.
- Focused regression suite: **173 tests passed** in the final rerun.
- The initial scoped check exposed the old news-card color expectation. Included the existing QA-tested one-line expectation correction to match the already committed theme; no implementation color was changed. Final tests pass.
- `pubspec.lock` remained byte-identical after dependency resolution.
- Final staged Flutter subtree: `313f79ab1c87a6f55fd44339c31266502cf4e1c9`; matches the tested export.
- `git diff --cached --check`: passed before committing.
- 392 pre-existing working file hashes match, excluding the three intentionally updated closure documents. All application working bytes and historical QA artifacts are preserved.
- 21 tracked files retain unstaged unrelated changes. Generated QA web output and local raw evidence remain outside the release commit.

Final regression log SHA-256: `374fa310ac6a6cbee3f3c245f14ff9fb01f7a420400771d1235a7373a34d9e62`. Raw integration logs/checkpoints are local in `/var/folders/n1/52tqydn14ws4cb5jhhps_ckm0000gn/T/newpaotang-main-merge-d3x08_3v`.

Prior API (42 tests / 353 assertions), API diagnostics, Flutter/Nuxt builds and contract QA remain the unchanged-source evidence in the referenced October reports. They were not represented as new executions.

## Git Integration

Main starts from independent initial deploy commit `e93dcc14b5c383f67aa6c0d121474e905a7f9767`. Preserve that history and the current develop history in an isolated merge, resolving the obsolete main snapshot to the selected develop tree. Verify tree equality and both-parent ancestry before push, then verify the actual remote revision. The final merge revision is available from Git main history and the coordinator's completion response.

Production Deploy builds on develop pushes; main push alone does not trigger it. No production dispatch, migration, restart, install, SMS or purchase is part of this integration.
