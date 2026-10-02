# Independent QA Coverage Plan

- Baseline: canonical develop, HEAD/origin c8f130cdcc1a1addc3a7526597bd7a17107d574d; tracked app diff SHA-256 f5aa423a45dfd1b1815990f2f711ff576360516a129cd6f49ebf17e6b4ca31c9. Hash untracked source and compare again at completion.
- Social acceptance: BLOCKED by CustomerSocialLinkPhoneRequest conflict; API regressions provide diagnostics only. Verify effective test DB/environment before RefreshDatabase tests.
- Flutter: isolated SDK copy, analyze, focused regressions, production web build, fresh fixture preview. Record tool versions and dependency resolution.
- Receipt: independent responsive renders and real PNG/PDF export from fictional order using production capture/export services. Inspect Thai/English/custom wallet labels, Kanit, brand asset, scrolling and fixed actions.
- Dock/social: regressions for affected surfaces and safe insets; fresh screenshots and fixture existing/new-phone interaction. Real installed OS safe areas/keyboard remain separate.
- News: test splash independence, first-cover priority, missing/slow/failed covers, six distinct cover limit; fixture timing is not production timing.
- Legacy Nuxt: isolated npm test/build plus logo hash/source checks; no authenticated SMS/purchase calls.
- Runtime: observe only; preserve pre-existing stopped API/BO/customer services. No runtime seed/reset or cache flush. Record smoke/login availability without starting stale services unnecessarily.
- Output: QA report to Coordinator, scoped defects and outstanding gates, no unconditional PASS/release.

## Completion Status

- [x] Start gate, source hashes, Docker mounts/images, pre/post runtime snapshot.
- [x] Effective testing/newpaotang_test verified; API regressions 42 tests / 353 assertions.
- [x] Independent API diagnostics 3 tests / 96 assertions, including generic providers and legacy LINE.
- [x] Flutter analyze; 173 existing focused regressions; 27 additional QA fixtures on the final rerun.
- [x] Isolated Flutter production/fixture builds and legacy Nuxt checks/build.
- [x] Fresh responsive browser/widget renders, eight real PNG/PDF export pairs and PDF visual inspection.
- [x] Dock six-screen 0/34 inset matrix; social three-size existing/new flow and keyboard/PIN checks.
- [x] News distinct-cover/cold/warm/failure fixture evidence, separate from production latency.
- [x] QA preview/tab/viewport cleanup; shared services unchanged.
- [ ] BLOCKED: authoritative social contract requires Coordinator decision.
- [ ] BLOCKED: shared runtime HTTP/login smoke unavailable; no seeding or account repair performed.
- [ ] NOT TESTED: approved native build, real providers/SMS, OS sharing, production news timing.
- [x] Report prepared for Coordinator only; no implementation edits, stage, commit, or push.
