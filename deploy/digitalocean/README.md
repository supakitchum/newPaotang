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
- `customer`: Nuxt customer SSR app.
- `back-office`: Nuxt admin SSR app.
- `lotto-scraper-sanook` and `lotto-scraper-thairath`: one replica per source to avoid duplicate scraping.

## Required DigitalOcean resources

1. DOKS cluster with autoscaling node pools.
2. DigitalOcean Container Registry (DOCR).
3. Managed PostgreSQL with a connection pool enabled.
4. Managed Valkey/Redis.
5. Spaces bucket + CDN for uploads and ticket images.
6. Ingress NGINX and cert-manager installed in the cluster.

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

Edit these placeholders before first deploy:

- `deploy/digitalocean/configmap.yaml`
  - `APP_URL`
  - `PLATFORM_PUBLIC_SITE_URL`
  - `PLATFORM_BACK_OFFICE_URL`
  - `CDN_BASE_URL`
  - realtime URLs
- `deploy/digitalocean/ingress.yaml`
  - API, admin, realtime, root, and wildcard customer hosts
- `deploy/digitalocean/kustomization.yaml`
  - DOCR registry name and initial image tag if deploying manually

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

## GitHub Actions setup

Create these GitHub repository secrets:

- `DIGITALOCEAN_ACCESS_TOKEN`
- `DOCR_REGISTRY` (registry name only, not the full URL)
- `DOKS_CLUSTER_NAME`

The workflow is manual:

- `.github/workflows/production-deploy.yml`
- Input `deploy=false`: build and push images only.
- Input `deploy=true`: build, push, apply manifests, migrate, and roll deployments.
- Input `run_rbac_seed=true`: also run `DefaultRbacMenuSeeder`.

## How to update code

Use this flow for normal releases:

1. Create a release branch and merge reviewed code to the deploy branch.
2. Run local/test validation before deploy:

   ```bash
   docker compose exec -T platform-api php artisan test --env=testing
   npm --prefix apps/customer run lint
   npm --prefix apps/customer run build
   npm --prefix apps/back-office run lint
   npm --prefix apps/back-office run build
   npm --prefix apps/lotto-scraper run test
   npm --prefix apps/lotto-scraper run build
   ```

3. Open GitHub Actions > Production Deploy.
4. Start with `deploy=false` to build/push images.
5. If image build passes, run again with `deploy=true`.
6. Enable `run_rbac_seed=true` only for menu/permission/default role changes.
7. After deploy, smoke:

   ```bash
   kubectl -n newpaotang-prod get pods
   kubectl -n newpaotang-prod rollout status deployment/platform-api
   curl -fsS https://api.lottery80.online/api/v1/health/ready
   curl -fsS https://api.lottery80.online/api/v1/health/live
   ```

## Rollback

Rollback web/API deployments:

```bash
kubectl -n newpaotang-prod rollout undo deployment/platform-api
kubectl -n newpaotang-prod rollout undo deployment/customer
kubectl -n newpaotang-prod rollout undo deployment/back-office
kubectl -n newpaotang-prod rollout undo deployment/platform-api-reverb
```

Rollback worker deployments if needed:

```bash
kubectl -n newpaotang-prod rollout undo deployment/platform-api-worker-critical
kubectl -n newpaotang-prod rollout undo deployment/platform-api-worker-default
kubectl -n newpaotang-prod rollout undo deployment/platform-api-worker-image
```

Database migrations need a separate rollback plan per release. Do not run destructive rollback commands against production.

## Scaling notes

- Web/API/Nuxt services scale with HPA in `hpa.yaml`.
- Queue workers currently scale by CPU. For production-grade queue scaling, add KEDA using Redis queue length.
- Keep scraper source deployments at one replica unless the scraper has a distributed lock.
- Keep scheduler at one replica.
- Keep uploads on Spaces/S3. Do not rely on pod-local storage.

## Known follow-up

The current `apps/platform-api/Dockerfile` production stage starts Laravel with `php artisan serve`.
That is acceptable for a first controlled deployment, but production traffic should move to PHP-FPM + NGINX, FrankenPHP, or Octane/RoadRunner before high load.
