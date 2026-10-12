# วิธีนำ Toon Tale ขึ้นระบบ

เว็บที่อยู่ใน `game-source/docs/play` เป็นเกม v0.9.4 build afb9ddca สำเร็จรูป ไม่ต้องรัน Godot เพื่อใช้งานเว็บชุดนี้

## 1. ระบบครบ: Cloudflare Worker + D1 + Static Assets

ใช้ `hosting/worker` ซึ่ง import API ตัวจริงจาก `hosting/accounts/server/accounts.js` แล้วเสิร์ฟไฟล์เกมจาก `game-source/docs/play` ทั้งเกมและ `/api/account/*` อยู่บนโดเมน HTTPS เดียวกัน

```sh
cd hosting/worker
npm install
cp wrangler.example.jsonc wrangler.jsonc
```

กำหนด `name` เป็น Worker ปลายทางที่เจ้าของอนุญาต และใส่ D1 `database_id`/`database_name` ของปลายทางจริง โดยรักษาชื่อ binding **DB** หากปรับปรุงระบบเดิมต้องชี้ฐานข้อมูลเดิมก่อน deploy ไม่ใช่สร้างฐานข้อมูลว่างทับ

สำหรับฐานข้อมูลใหม่เท่านั้น: สร้าง D1 ผ่านบัญชีเจ้าของ นำ ID ที่แพลตฟอร์มคืนมาใส่ config จากนั้นใช้ migration:

```sh
npx wrangler d1 migrations apply toon-tale-accounts --remote
npx wrangler deploy
```

ชื่อฐานข้อมูลในคำสั่งต้องตรงกับ `database_name` ที่เลือกไว้จริง ถ้าเป็นฐานข้อมูลเดิมที่มีตารางเหล่านี้อยู่แล้ว ห้ามรัน CREATE TABLE ชุดแรกซ้ำ ให้ตรวจ migration journal และ schema ก่อน

ทดสอบ API แบบ unauthenticated `/api/account/session` ต้องได้ `{"user":null}` และทดสอบ signup/login/save/history ด้วยบัญชี QA แยก ตามชุดทดสอบและสัญญา API ไม่ใช้ข้อมูลผู้เล่นจริงเป็น fixture

```sh
cd ../accounts
node tests/account.test.mjs
```

ต้องใช้ Node 24+ สำหรับ SQLite built-in ของชุดทดสอบ

ข้อกำหนดสำคัญ: Secure/HttpOnly/SameSite cookie, exact Origin check และ X-Toon-Account-ID ต้องคงไว้ ทั้ง frontend/backend ที่แนบมารองรับแล้ว ไม่เปลี่ยนเป็นการส่งพาสเวิร์ดหรือ token ผ่าน URL และไม่เปิด cross-origin wildcard เพื่อแก้ login

## 2. ใช้ hosting เดิมแบบ Sites/Vinext

`hosting/sites-vinext` เก็บซอร์ส hosting เดิมครบ ยกเว้น public assets และ deployment identity ที่ต้องกำหนดตามโครงการปลายทาง

1. รัน `python3 handoff-tools/prepare_sites_source.py` จากรากแพ็ก เพื่อคัดลอก static assets ไปยัง `hosting/sites-vinext/public`
2. เตรียม `hosting/sites-vinext/.openai/hosting.json` โดยใช้ project ID จริงที่ได้จากระบบ Sites ของเจ้าของ คง `d1: "DB"` และฐานข้อมูลเดิม
3. `hosting.reference.json` เป็นข้อมูลอ้างอิงโครงการเดิม ไม่ใช่คำสั่งให้สร้างหรือเปลี่ยน Site โดยอัตโนมัติ
4. ติดตั้ง dependency ตาม `package-lock.json` แล้ว build จากโฟลเดอร์นี้ด้วย `node --import ./scripts/sites-env.mjs ./node_modules/vinext/dist/cli.js build`
5. ใช้ workflow save/deploy ของระบบปลายทาง และคง audience/database binding เดิม

README ฝั่ง backend เดิมมีชื่อไฟล์เก่าบางจุด (`account.mjs`, `migrations/`): ไฟล์จริงคือ `server/accounts.js` และ schema migration `drizzle/0000_quick_turbo.sql`

## 3. GitHub Pages / โฮสต์ static

นำ `game-source` ไปอัปเดต repo Godot แล้วตั้ง Pages ให้เสิร์ฟ `docs` โดยเกมจะอยู่ที่ `/play/` หรือจัด deploy directory ให้เสิร์ฟ `docs/play` เป็นรากเว็บตามโฮสต์นั้น

Pages ไม่มี backend `/api/account/*` จึงเล่นเกม/ใช้เซฟในเครื่องได้ แต่ระบบไอดี/พาสเวิร์ดและเซฟข้ามเครื่องต้องจัด backend ใน origin เดียวกัน เช่น Worker ที่ route โดเมนเกมทั้งหมด ไม่ใช่เอา API ไปคนละโดเมนแล้วปิด Origin protection

หน้ารวมภาพใน `docs/play/divine-sanctum` และ `star-expansion` มีลิงก์บางส่วนเริ่มด้วย `/` ตามโดเมนเกมเดิม หากเผยแพร่ใต้ subpath ของ GitHub Pages ให้ปรับเป็น relative URL ตามปลายทางก่อนเผยแพร่ URL `og:url`/`og:image` ในหน้าเกมต้องเปลี่ยนให้ตรงกับโดเมนปลายทางด้วย

## ตรวจหลังขึ้นระบบ

- หน้าโหลดแสดง v0.9.4 build afb9ddca สำหรับเว็บที่ไม่ได้ rebuild
- game.afb9ddca.part001–004.gz.wasm และ engine.d0b30e03.gz.wasm เปิดได้ครบ ไม่ถูกแปลงหรืออัด gzip ซ้ำ
- หน้าเกมโหลดไอคอน iPhone และภาพชุดย้อมสีใหม่ได้
- เข้าแมพวิหารบัวดาราด้วยตัวละครเลเวล 100 / 200 ดาว, ชุดตรงตามอาชีพ และบอสให้ 2 ชิ้นต่างช่อง
- ปีก 100 ดาว โหลดเซฟเดิมและสวมอุปกรณ์แยกชิ้นได้
- ทดสอบ login/save บนสองเครื่องและกรณี revision conflict; หากย้าย DB ต้องยืนยันการเล่นต่อด้วยบัญชีเดิม

รายละเอียดทรัพย์สินและใบอนุญาตอยู่ใน `game-source/ASSET_CREDITS.md` และ `game-source/assets/vendor/` โมเดลที่ผู้ใช้ส่งมาไม่ถูกระบุว่าเป็น CC0
