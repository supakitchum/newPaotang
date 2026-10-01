# AI Project Context: paotang-frontend

## Working Preferences

- เมื่อแก้ `paotang-frontend` ไม่ต้อง run build ให้ เว้นแต่ผู้ใช้ขอชัดเจน
- ไม่ต้อง run dev server ให้ เว้นแต่ผู้ใช้ขอชัดเจน
- หากมีการแก้ `routes/api.php` หรือ API routing ใน `paotang-agent` ให้รันคำสั่งนี้ทุกครั้งหลังแก้:

```bash
php artisan optimize
php artisan config:clear
```
