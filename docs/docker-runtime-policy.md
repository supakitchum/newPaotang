# Docker Runtime Policy

โปรเจค NewPaotang ต้อง run ผ่าน Docker ทั้งหมด

## Mandatory Rule

```text
Docker Compose is the only supported runtime for this project.
All application commands must run inside Docker containers.
Do not run PHP, Composer, Node, npm, pnpm, yarn, Nuxt, Vite, Artisan, queue workers, tests, builds, or migrations directly on the host machine.
```

เครื่อง local ใช้ได้เฉพาะ:

```text
git
docker
docker compose
file editing
file inspection commands that do not execute project runtime
```

## Command Pattern

ใช้รูปแบบนี้เป็นค่า default:

```sh
docker compose up -d
docker compose exec <service> <command>
docker compose run --rm <service> <command>
```

ถ้า container เปิดอยู่แล้ว ให้ใช้ `docker compose exec`

```sh
docker compose exec platform-api php artisan test
docker compose run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose exec customer npm run build
docker compose exec back-office npm run build
```

ถ้ายังไม่ได้เปิด container หรือเป็น one-off command ให้ใช้ `docker compose run --rm`

```sh
docker compose run --rm platform-api composer install
docker compose run --rm customer npm ci
docker compose run --rm back-office npm ci
```

## Service Names

```text
platform-api  Backend API service
customer      Customer frontend service
back-office   Admin dashboard frontend service
postgres      PostgreSQL service
valkey        Redis-compatible cache/queue/lock service
```

## Agent / Developer Requirements

```text
Orchestrator must write validation commands in Docker form only.
Backend Develop must run PHP/Composer/Artisan commands through platform-api container only.
BO Develop must run frontend commands through back-office container only.
Customer Develop must run frontend commands through customer container only.
QA Tester must run all test/build/migration commands through Docker containers only.
```

## Forbidden Examples

ห้ามใช้คำสั่งเหล่านี้บน host machine:

```sh
composer install
php artisan test
php artisan migrate
npm install
npm run build
npm run dev
pnpm install
yarn install
nuxt dev
vite build
```

ให้แปลงเป็น Docker command เสมอ:

```sh
docker compose run --rm platform-api composer install
docker compose exec platform-api php artisan test
docker compose exec customer npm run build
docker compose exec back-office npm run build
```

## QA Database Isolation

ฐานข้อมูล runtime หลักคือ:

```text
newpaotang
```

ฐานข้อมูลทดสอบสำหรับ PHPUnit/feature tests คือ:

```text
newpaotang_test
```

QA และ agent ทุกตัวห้ามรันคำสั่ง destructive เช่น `migrate:fresh`, `migrate:refresh`, `migrate:reset`, หรือ `db:wipe` กับ `newpaotang` เว้นแต่ user สั่งให้ล้าง DB หลักอย่างชัดเจนใน turn นั้น

คำสั่งเตรียม test database ที่ถูกต้อง:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

คำสั่งรัน backend tests ที่ถูกต้อง:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

คำสั่งตรวจ runtime หลักหลัง QA ต้องไม่ล้างข้อมูลหลัก ให้ใช้ smoke/seed แบบไม่ drop ตาราง:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
```

ถ้า QA ต้องทดสอบผ่าน BO browser workflow ที่เขียนข้อมูล ให้ใช้ข้อมูล fixture เฉพาะ QA หรือ test runtime database แยก ห้ามใช้ `migrate:fresh --seed` เพื่อ restore ฐานข้อมูลหลักหลังทดสอบ
