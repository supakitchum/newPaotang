# Decision: Stock Generation Summary Widgets

Date: 2026-05-15

Decision: OPEN IMPLEMENTATION THROUGH ORCHESTRATOR

## User Request

Add widgets to Stock Generation showing:

- total stock tickets
- totals/coverage for 2-tail numbers
- totals/coverage for 3-tail numbers
- totals/coverage for 3-front numbers
- total counts by stock status

## Coordinator Interpretation

The wording "ยอดรวมเลข 2 ท้าย 3 ท้าย 3 หน้า" is interpreted as quota/coverage summary, not a raw sum of numeric values.

The widget should help operators verify stock generation distribution after quota-based generation:

- `back2`: distinct values expected 100 (`00-99`), plus min/max/count summary per value
- `back3`: distinct values expected 1000 (`000-999`), plus min/max/count summary per value
- `front3`: distinct values expected 1000 (`000-999`), plus min/max/count summary per value
- status totals: `available`, `allocated`, `sold`, `recalled`, `voided`, and total

## API Contract Direction

Backend should add a dedicated aggregate endpoint instead of making BO aggregate from paginated stock rows.

Preferred endpoint:

```text
GET /admin/central/stock/summary
```

Query:

```text
game_id optional but strongly recommended in BO
batch_id optional if easy and useful for generated batch verification
```

Permission:

```text
central scope
stock.view OR stock.generate
```

If the current authorization helper cannot support OR permissions cleanly, Orchestrator/Backend must report the blocker to Coordinator before narrowing the permission.

Response shape should be stable and widget-friendly:

```json
{
  "game_id": "gam_xxx",
  "batch_id": null,
  "total_count": 3000,
  "status_counts": {
    "available": 3000,
    "allocated": 0,
    "sold": 0,
    "recalled": 0,
    "voided": 0
  },
  "number_coverage": {
    "back2": {
      "expected_distinct": 100,
      "distinct_count": 100,
      "min_count_per_number": 30,
      "max_count_per_number": 30,
      "total_count": 3000
    },
    "back3": {
      "expected_distinct": 1000,
      "distinct_count": 1000,
      "min_count_per_number": 3,
      "max_count_per_number": 3,
      "total_count": 3000
    },
    "front3": {
      "expected_distinct": 1000,
      "distinct_count": 1000,
      "min_count_per_number": 3,
      "max_count_per_number": 3,
      "total_count": 3000
    }
  }
}
```

Backend may include additional fields such as `missing_distinct_count`, `over_quota_count`, `under_quota_count`, or top samples if useful, but BO should not depend on unapproved fields.

## BO Direction

On the central stock operations / stock generation view:

- Add a compact widget band above the Generate Stock action/table area.
- The widgets should update when game filter changes.
- Show loading/error/empty state.
- Do not block Generate Stock if summary fails; show a visible non-blocking API state.
- Do not render misleading zero values while loading.

Suggested widgets:

```text
Total tickets
2-tail coverage
3-tail coverage
3-front coverage
Status totals
```

## QA Direction

QA must verify:

- API returns correct aggregate counts for quota-generated stock.
- BO widgets call the summary endpoint and display values from API.
- Widgets respond to `game_id` filter changes.
- Invalid/missing game state is not misleading.
- Backend authorization and central scope are enforced.
- Existing Generate Stock flow still works.
- QA database isolation policy is mandatory:
  - destructive DB commands must use `newpaotang_test`
  - runtime DB `newpaotang` must not be wiped

## Ownership

Expected Orchestrator split:

```text
Backend Develop: endpoint, service aggregate, OpenAPI, permissions docs, feature tests
BO Develop: widgets and API wiring
QA Tester: focused API + BO real workflow validation
```

## Next Agent

Orchestrator

