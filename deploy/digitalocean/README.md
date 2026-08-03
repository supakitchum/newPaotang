# NewPaotang Production Deploy on DigitalOcean

This directory contains a scalable starter deployment for DigitalOcean Kubernetes (DOKS).
It is intentionally configuration-only: production secrets and real domains must be supplied outside git.

## Services

- `platform-api`: Laravel HTTP API.
- `platform-api-worker-critical`: checkout, reservation, reward, and notification queues.
- `platform-api-worker-default`: normal async jobs, reports, webhooks, monitoring.
- `platform-api-worker-image`: stock/ticket image generation queues.
- `platform-api-scheduler`: Laravel scheduler singleton.
- `platform-api-reverb`: realtime websocket service.
- `support-api`: isolated Customer Support HTTP API.
- `support-api-worker`: Support queue assignment and notification outbox.
- `support-api-scheduler`: Support queue/outbox recovery scheduler.
- `support-api-reverb`: isolated Support realtime websocket service.
- `customer`: Flutter customer web app.
- `back-office`: Nuxt admin SSR app.
- `lotto-scraper-sanook` and `lotto-scraper-thairath`: one replica per source to avoid duplicate scraping.

## Required DigitalOcean resources

1. DOKS cluster with autoscaling node pools.
2. DigitalOcean Container Registry (DOCR).
3. Managed PostgreSQL with a connection pool enabled for Platform.
4. A second, isolated Managed PostgreSQL database for Support.
5. Managed Valkey/Redis for Platform.
6. A second, isolated Managed Valkey/Redis for Support.
7. A private Spaces bucket for Support attachments, separate credentials
   preferred.
8. Spaces bucket + CDN for Platform uploads and ticket images.
9. Ingress NGINX and cert-manager installed in the cluster.

## First-time setup

Install CLI tools locally:

```bash
brew install doctl kubectl kustomize
doctl auth init
doctl kubernetes cluster kubeconfig save <cluster-name>
```

Connect the DOKS cluster to DOCR:

```bash
doctl registry kubernetes-manifest | kubectl apply -f -
```

Create the namespace and secrets:

```bash
kubectl apply -f deploy/digitalocean/namespace.yaml
cp deploy/digitalocean/secret.example.yaml /tmp/newpaotang-secret.yaml
# Edit /tmp/newpaotang-secret.yaml with production values.
kubectl apply -f /tmp/newpaotang-secret.yaml
rm /tmp/newpaotang-secret.yaml
```

Before applying the Support manifests, the secret file must include
`newpaotang-support-secret`, the Support RSA public key, and the matching
private key in `newpaotang-platform-secret`. Support DB/Valkey credentials must
point to the isolated managed resources, never the Platform database or cache.

Edit these placeholders before first deploy:

- `deploy/digitalocean/configmap.yaml`
  - `APP_URL`
  - `PLATFORM_PUBLIC_SITE_URL`
  - `PLATFORM_BACK_OFFICE_URL`
  - `CDN_BASE_URL`
  - realtime URLs
  - Support API/realtime URLs and allowed browser origins
- `deploy/digitalocean/ingress.yaml`
  - API, admin, realtime, root, and wildcard customer hosts
- `deploy/digitalocean/kustomization.yaml`
  - DOCR registry name and initial image tag if deploying manually

Customer native notification credentials and the physical-device acceptance
procedure are documented in
[`docs/customer-notification-deployment.md`](../../docs/customer-notification-deployment.md).
The Firebase service-account JSON, Android `google-services.json`, iOS
`GoogleService-Info.plist`, and APNs credentials must come from deployment or
build secrets and must not be committed.

Apply manifests:

```bash
kubectl apply -k deploy/digitalocean
```

Run migrations with the image you are deploying:

```bash
export PLATFORM_API_IMAGE=registry.digitalocean.com/<registry>/newpaotang-platform-api:<tag>
export MIGRATION_JOB_NAME=newpaotang-migrate-$(date +%s)
envsubst < deploy/digitalocean/jobs/migrate.yaml | kubectl apply -f -
kubectl -n newpaotang-prod wait --for=condition=complete job/$MIGRATION_JOB_NAME --timeout=600s
```

Run RBAC/menu seed only when menus, permissions, or default roles changed:

```bash
export PLATFORM_API_IMAGE=registry.digitalocean.com/<registry>/newpaotang-platform-api:<tag>
export RBAC_SEED_JOB_NAME=newpaotang-rbac-seed-$(date +%s)
envsubst < deploy/digitalocean/jobs/rbac-seed.yaml | kubectl apply -f -
kubectl -n newpaotang-prod wait --for=condition=complete job/$RBAC_SEED_JOB_NAME --timeout=600s
```

Migrate the isolated Support database only after its managed Postgres, Valkey,
RSA/HMAC secrets, and private attachment bucket are provisioned:

```bash
export SUPPORT_API_IMAGE=registry.digitalocean.com/<registry>/newpaotang-support-api:<tag>
export SUPPORT_MIGRATION_JOB_NAME=newpaotang-support-migrate-$(date +%s)
envsubst < deploy/digitalocean/jobs/support-migrate.yaml | kubectl apply -f -
kubectl -n newpaotang-prod wait --for=condition=complete job/$SUPPORT_MIGRATION_JOB_NAME --timeout=600s
```

The production workflow never runs this migration on a branch push. It runs
only from `workflow_dispatch` when `deploy=true` and
`run_support_migration=true` are explicitly selected.

## GitHub Actions setup

Create these GitHub repository secrets:

- `DIGITALOCEAN_ACCESS_TOKEN`
- `DOCR_REGISTRY` (registry name only, not the full URL)
- `DOKS_CLUSTER_NAME`

The production workflow is:

- `.github/workflows/production-deploy.yml`
- Push to `develop`: automatically build images, push to DOCR, apply manifests, run migrations, roll deployments, and smoke production endpoints.
- Manual `workflow_dispatch` with `deploy=false`: build and push images only.
- Manual `workflow_dispatch` with `deploy=true`: build, push, apply manifests, migrate, and roll deployments.
- Manual `workflow_dispatch` with `run_rbac_seed=true`: also run `DefaultRbacMenuSeeder`.
- Manual `workflow_dispatch` with `deploy=true` and `deploy_support=true`:
  apply and roll the isolated Support workloads after their infrastructure and
  secrets exist.
- Manual `workflow_dispatch` with `run_support_migration=true`: migrate only
  the isolated Support database; `deploy_support=true` is also required.

Normal branch pushes build the Support image but intentionally leave Support
workloads and Support migrations untouched.

If the GitHub `production` environment has required reviewers configured, GitHub will pause the deploy job for approval even on automatic pushes.

## How to update code

Use this flow for normal releases:

1. Create a release branch and merge reviewed code to the deploy branch.
2. Run local/test validation before deploy:

   ```bash
   docker compose exec -T platform-api php artisan test --env=testing
   (cd apps/customer_flutter && flutter analyze && flutter test)
   docker compose run --rm --no-deps \
     -e APP_ENV=testing \
     -e DB_DATABASE=newpaotang_support_test \
     -e DB_TEST_DATABASE=newpaotang_support_test \
     support-api php artisan test --env=testing
   npm --prefix apps/back-office run lint
   npm --prefix apps/back-office run build
   npm --prefix apps/lotto-scraper run test
   npm --prefix apps/lotto-scraper run build
   ```

3. Push or merge to `develop`; GitHub Actions will deploy production automatically.
4. Enable `run_rbac_seed=true` manually only for menu/permission/default role changes.
5. After deploy, smoke:

   ```bash
   kubectl -n newpaotang-prod get pods
   kubectl -n newpaotang-prod rollout status deployment/platform-api
   kubectl -n newpaotang-prod rollout status deployment/support-api
   curl -fsS https://api.siamblend.com/api/v1/health/ready
   curl -fsS https://api.siamblend.com/support-api/health/ready
   curl -fsS https://api.siamblend.com/api/v1/health/live
   ```

## Rollback

Rollback web/API deployments:

```bash
kubectl -n newpaotang-prod rollout undo deployment/platform-api
kubectl -n newpaotang-prod rollout undo deployment/customer
kubectl -n newpaotang-prod rollout undo deployment/back-office
kubectl -n newpaotang-prod rollout undo deployment/platform-api-reverb
kubectl -n newpaotang-prod rollout undo deployment/support-api
kubectl -n newpaotang-prod rollout undo deployment/support-api-reverb
```

Rollback worker deployments if needed:

```bash
kubectl -n newpaotang-prod rollout undo deployment/platform-api-worker-critical
kubectl -n newpaotang-prod rollout undo deployment/platform-api-worker-default
kubectl -n newpaotang-prod rollout undo deployment/platform-api-worker-image
kubectl -n newpaotang-prod rollout undo deployment/support-api-worker
kubectl -n newpaotang-prod rollout undo deployment/support-api-scheduler
```

Database migrations need a separate rollback plan per release. Do not run destructive rollback commands against production.

## Scaling notes

- Web/API/Nuxt services scale with HPA in `hpa.yaml`.
- Queue workers currently scale by CPU. For production-grade queue scaling, add KEDA using Redis queue length.
- Keep scraper source deployments at one replica unless the scraper has a distributed lock.
- Keep scheduler at one replica.
- Keep uploads on Spaces/S3. Do not rely on pod-local storage.

## Known follow-up

The current `apps/support-api/Dockerfile` production stage starts Laravel with
`php artisan serve`. That is acceptable for a first controlled rollout, but
Support traffic should move to PHP-FPM + NGINX, FrankenPHP, or Octane/RoadRunner
before high load.
