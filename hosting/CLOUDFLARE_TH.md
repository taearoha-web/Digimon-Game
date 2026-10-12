# ตั้งระบบไอดี/พาสเวิร์ดบน Cloudflare (ทำจากมือถือได้)

เกมและ API บัญชี (`/api/account/*`) อยู่บนโดเมนเดียวกันผ่าน Cloudflare Worker + ฐานข้อมูล D1
GitHub Pages ไม่มี backend จึงเล่นได้แต่ไม่มีระบบบัญชี

## 1) เตรียมบัญชี Cloudflare (ครั้งเดียว)
1. สมัคร/ล็อกอินที่ https://dash.cloudflare.com
2. เมนู Workers & Pages → ถ้าถามให้ตั้งชื่อ subdomain ของ workers.dev ให้ตั้ง (ครั้งเดียว)
3. คัดลอก **Account ID** (หน้า Workers & Pages ฝั่งขวา หรือ URL หลัง dash.cloudflare.com/)
4. สร้าง **API Token**: My Profile → API Tokens → Create Token → Custom token
   - Account · Workers Scripts · Edit
   - Account · D1 · Edit
   - (เลือก Account Resources เป็นบัญชีของคุณ) แล้วคัดลอก token เก็บไว้ (แสดงครั้งเดียว)

## 2) ใส่ secret ใน GitHub (ห้ามส่ง token ในแชต)
repo → Settings → Secrets and variables → Actions → New repository secret
- `CLOUDFLARE_ACCOUNT_ID` = Account ID
- `CLOUDFLARE_API_TOKEN` = token จากข้อ 4

## 3) สั่ง deploy
repo → Actions → "Deploy to Cloudflare (game + accounts)" → Run workflow
(ค่าเริ่มต้นใช้ได้เลย) งานจะ: ทดสอบระบบบัญชี → สร้าง D1 (ถ้ายังไม่มี) → สร้างตาราง → deploy

เสร็จแล้วเกมอยู่ที่ `https://toon-tale.<subdomain>.workers.dev/`

## ตรวจหลัง deploy
- เปิด `/api/account/session` ต้องได้ `{"user":null}`
- สมัครไอดีทดสอบ (ใช้ชื่อทดสอบ ไม่ใช้ข้อมูลผู้เล่นจริง) → ออกจากระบบ → เข้าใหม่ → เซฟข้ามเครื่อง
- รหัสกู้คืน (recoveryCode) แสดงตอนสมัครครั้งเดียว ให้ผู้เล่นจดไว้

## หมายเหตุ
- ไฟล์เกมแต่ละไฟล์ต้องไม่เกิน 25 MiB (Workers static assets) ระบบแบ่งไฟล์ WASM เป็นส่วนๆ ให้แล้ว
- ถ้ารัน workflow ซ้ำ จะใช้ D1 เดิมและข้าม migration ที่ทำแล้ว ข้อมูลผู้เล่นไม่ถูกทับ
- รายละเอียด API: `hosting/accounts/API_REFERENCE.md` และ `hosting/DEPLOYMENT.md`
