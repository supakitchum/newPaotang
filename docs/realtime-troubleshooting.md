# Realtime Troubleshooting Runbook

## Case: BO Saves Price But Customer Does Not Update

Incident date: 2026-05-21

Use this case when Product/QA reports:

- Back Office can save a tenant sale price.
- Public/customer API returns the new price after refresh.
- Customer page `/buy` does not update price in realtime.
- Platform API logs may show `Broadcasting [stock.price.updated]`, but the browser websocket does not receive `stock.price.updated`.

Do not assume this is a customer UI bug first.

## Expected Flow

Back Office does not need a websocket to make customer realtime work.

The correct flow is:

```text
BO Set sale price -> platform-api HTTP request -> backend saves price -> backend broadcasts Reverb event -> customer socket receives event -> visible prices patch in-place
```

Customer channel:

```text
customer.tenant.{tenant_id}.sale-price
```

Customer event:

```text
stock.price.updated
```

Example payload:

```json
{
  "tenant_id": "ten_demo_alpha",
  "game_id": "gam_01KS29G2SJBX41ZZ51YKRVKB0B",
  "set_size": 1,
  "price": { "amount": 10000, "currency": "THB" },
  "source": "tenant_override"
}
```

## Root Cause Seen Locally

In the local Docker stack, `platform-api` was running:

```sh
php artisan serve --host=0.0.0.0 --port=8000
```

Laravel `artisan serve` starts a child PHP built-in server process. When `.env` exists and `--no-reload` is not used, Laravel passes only a small allowlist of environment variables to the child process. The parent container had:

```text
BROADCAST_CONNECTION=reverb
REVERB_HOST=platform-api-reverb
```

but the HTTP child process only had:

```text
APP_ENV=local
```

That means HTTP requests from BO loaded broadcasting config from `.env` / defaults and used the `log` broadcaster instead of Reverb. The Laravel log still printed:

```text
Broadcasting [stock.price.updated] ...
```

but this was only `LogBroadcaster` output. It was not proof that the event reached Reverb or the customer browser.

## Diagnosis Checklist

1. Confirm the BO save request reached the expected endpoint.

```sh
docker compose logs --tail=300 platform-api | rg 'sale-price-rules|stock.price.updated|Broadcasting'
```

Expected sale price endpoint:

```text
/api/v1/admin/tenant/sale-price-rules/{sale_price_rule_id}
```

2. Confirm the customer/public API now returns the saved price.

```sh
curl -sS 'http://xn--42cl1cp5p.localhost/api/v1/public/stock/search?game_id={game_id}&mode=random&limit=1' \
  | jq '{price: .data[0].price, price_rule_summary: .data[0].price_rule_summary}'
```

If the API price changed but the customer page did not update, continue to websocket/runtime checks.

3. Do not trust CLI env alone.

This checks the CLI container process only and can be misleading:

```sh
docker compose exec -T platform-api php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $kernel = $app->make("Illuminate\\Contracts\\Console\\Kernel"); $kernel->bootstrap(); echo config("broadcasting.default").PHP_EOL;'
```

If this prints `reverb`, that only proves the CLI process has correct env. It does not prove the HTTP child process has correct env.

4. Check the HTTP child process env.

```sh
docker compose exec -T platform-api sh -lc 'for p in /proc/[0-9]*; do cmd=$(tr "\0" " " < "$p/cmdline" 2>/dev/null || true); case "$cmd" in *"php -S"*) echo PID=${p#/proc/} CMD=$cmd; tr "\0" "\n" < "$p/environ" 2>/dev/null | grep -E "BROADCAST|REVERB|APP_ENV" | sort | sed "s/^/  /";; esac; done'
```

Correct local output must include:

```text
APP_ENV=local
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=newpaotang-local
REVERB_APP_KEY=newpaotang-admin
REVERB_APP_SECRET=newpaotang-admin-secret
REVERB_HOST=platform-api-reverb
REVERB_PORT=8080
REVERB_SCHEME=http
```

If the PHP server child only shows `APP_ENV=local`, the HTTP process is not using Reverb even if the container parent env is correct.

5. Confirm an actual websocket event.

The proof is a browser websocket message, not a Laravel log line.

Expected after saving price from BO:

```text
event: stock.price.updated
channel: customer.tenant.{tenant_id}.sale-price
data.price.amount: latest saved price in minor units
```

For example, saving `100.00 บาท` should emit:

```json
"price": { "amount": 10000, "currency": "THB" }
```

## Fix

In local Docker, `platform-api` must run `artisan serve` with `--no-reload` so the PHP built-in HTTP server keeps the Docker Compose env:

```yaml
platform-api:
  command: php artisan serve --host=0.0.0.0 --port=8000 --no-reload
```

Then recreate the API service:

```sh
docker compose up -d --force-recreate platform-api
```

Re-run the HTTP child env check before testing the browser again.

## Verification

After the fix:

1. Open customer:

```text
http://xn--42cl1cp5p.localhost/buy
```

2. Open BO sale price page and save a new partner price.
3. Customer websocket must receive:

```text
stock.price.updated
```

4. Visible customer prices must change without page reload.
5. Public API must return the same effective price.

## What Not To Do

- Do not add a BO websocket to solve this symptom. BO is not the event producer; backend is.
- Do not clear or reseed runtime DB for this issue.
- Do not keep changing customer price-patching logic until backend event delivery is proven.
- Do not treat `Broadcasting [stock.price.updated]` in Laravel logs as websocket delivery proof. If `LogBroadcaster` is active, that log is the destination.
- Do not validate only through CLI `php -r` config checks; inspect the HTTP child process env.

## Regression Guard

Keep the local Docker command for `platform-api` using `--no-reload`.

If the command is changed back, repeat this case before debugging customer socket code.
