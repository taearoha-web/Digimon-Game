# Toon Tale — แพ็กส่งต่อฉบับเต็ม v0.9.4

วันที่จัดแพ็ก: 12 ตุลาคม 2026 (Asia/Bangkok)

**เวอร์ชันเกม 0.9.4 · build afb9ddca** ตรงกับเกมที่เผยแพร่ล่าสุดบน https://toon-tale.taemongkichi.chatgpt.site

## ข้อความสำหรับส่งให้ Claude

> ใช้ ZIP นี้เป็นซอร์สเกม Toon Tale ฉบับเต็มล่าสุด v0.9.4 ไม่ใช่แพตช์จากเวอร์ชันเก่า อ่าน START_HERE_FOR_CLAUDE.md, VERSION.json และ hosting/DEPLOYMENT.md ก่อนทำงาน นำ game-source ไปอัปเดต repository เกมเดิม โดยคง .git และระบบ deploy ของ repository ปลายทางไว้ ใช้ไฟล์เว็บพร้อมใช้งานใน game-source/docs/play ซึ่งเป็น build afb9ddca หรือ rebuild ด้วย Godot 4.3 หลังเปลี่ยนซอร์ส รักษาระบบเซฟและฐานข้อมูลบัญชีเดิม ตรวจ manifest และทดสอบก่อนเผยแพร่ อย่านำ docs/play หรือ build เก่าจาก repository มาทับไฟล์ใหม่ ตรวจหน้าโหลดว่าเป็น v0.9.4 และทดสอบแมพวิหารบัวดารา ปีก 100 ดาว และชุด 200 ดาวแบบย้อมสีบนตัวละครเดิม

## โครงสร้าง

- `game-source/` — Godot project เต็ม รวมซอร์สล่าสุดทั้งไฟล์ที่แก้ไขและไฟล์ใหม่ แอสเซ็ต เสียง ไอคอน แอนิเมชัน ทดสอบ เอกสาร และใบอนุญาต
- `game-source/docs/play/` — เว็บเกมสำเร็จรูปปัจจุบัน พร้อม loader, WASM, game pack, ระบบบัญชีฝั่งหน้าเว็บ, รูปปก iPhone และหน้ารวมภาพ
- `hosting/accounts/` — ระบบบัญชี/พาสเวิร์ดและเซฟข้ามเครื่อง พร้อม schema และชุดทดสอบ
- `hosting/worker/` — ตัวอย่าง Cloudflare Worker ที่เสิร์ฟทั้งเว็บเกมและ API บัญชีในโดเมนเดียวกัน
- `hosting/sites-vinext/` — ซอร์สระบบ hosting เดิมแบบ Sites/Vinext สำหรับใช้งานกับแพลตฟอร์มเดิม
- `REFERENCE/` — รายการข้อมูลเกมและหลักฐานการตรวจเวอร์ชัน
- `handoff-tools/` — เครื่องมือเช็กไฟล์และเตรียม source สำหรับ hosting เดิม
- `MANIFEST.sha256` — SHA-256 ของไฟล์ทุกไฟล์ในแพ็ก

## อัปเดตที่ต้องรักษาไว้

- เกม 6 อาชีพ ตัวละครชาย/หญิง แอนิเมชัน อาวุธ และสกิลทั้งหมด รวม 24 สกิลดาวที่ปลดล็อก 50/100/150/200 ดาว
- นักดาบดาว 200 บินขึ้นพร้อมปีกและปล่อยดาบ 10 เล่มจากวงเวท โดยใช้รูปดาบที่สวมจริง; นักหอกดาว 100 แทง 5 ครั้ง
- 4 ดินแดนดาว และแมพใหม่วิหารบัวดารา เข้าได้เมื่อเลเวล 100 และครบ 200 ดาว พร้อมมอนสเตอร์เทพใหม่ 4 แบบรวมบอส
- ชุดเทพ 200 ดาวครบ 6 อาชีพ ดรอปตามอาชีพ: ทั่วไป 3.5%, ชั้นสูง 18%, บอส 2 ชิ้นต่างช่องกันแน่นอน
- v0.9.4 เปลี่ยนเกราะ กางเกง ถุงมือ และรองเท้าเป็นการย้อมสีบนตัวละครเดิมแบบเลเวล 1–100; หมวกเป็นวงคาดเล็ก มีสีเฉพาะอาชีพ ใช้ชุดและรองเท้าแยกชิ้นได้ อาวุธ/โล่/คัมภีร์ที่ผู้ใช้ส่งมายังเป็นโมเดลอาวุธ
- ปีกเลเวล 100 เดิมและปีกที่ผู้ใช้ส่งมา ซึ่งต้อง 100 ดาว; ไม่เพิ่มปีก 200 ดาว
- รูปหัวบน HUD แสดงหมวกและสีที่ใส่จริง, แถบเลือดเป้าหมายอยู่บนกลาง, บัฟอยู่ใต้ชื่อตัวละคร
- บัฟจากตัวเองสูงสุด 2 สกิล และจากเพื่อนอีก 2 สกิล; บัฟใหม่ทับรายการเก่าตามระบบ
- แถบขายของรักษาตำแหน่งเลื่อน, อัปสเตตัสด้วยจำนวนที่กรอก, สกิลและท่าถืออาวุธที่แก้ไขแล้ว
- ไม่มีการสั่นกล้อง ซูมสกิล หรือสั่นมือถือ; Armageddon 11 ฮิต เว้น 0.5 วินาที
- การปรับการใช้หน่วยความจำ เสียงแบบ Stream รายงาน session และการจัดการ spawn ของ Tower
- ระบบไอดี/พาสเวิร์ด เซฟ 4 ช่อง เซฟข้ามเครื่อง ประวัติเซฟ และการป้องกันเซฟชนกัน

รายละเอียดตัวเลขทุกอาชีพ/สกิล/แมพ/มอนสเตอร์อ่านได้จาก `REFERENCE/game_catalog.json` และโค้ดใน `game-source/data/` ซึ่งเป็นแหล่งข้อมูลจริง

## วิธีใช้กับ repository เกมเดิม

1. สร้าง branch และสำรอง repository ปลายทางก่อน
2. นำเนื้อหา `game-source/` ไปวางที่ราก Godot project ของ repository ปลายทาง รวมไฟล์ซ่อน `.github`, `.gitattributes`, `.gitignore` และไฟล์ใหม่ทั้งหมด ไม่ใช่เฉพาะไฟล์ที่ tracked
3. คง `.git`, ข้อมูลบัญชี/เซฟจริง และค่า deploy/credential ของปลายทางไว้ ทบทวน workflow เดิมกับ workflow ที่ให้มาแล้วปรับตามระบบปลายทาง
4. `docs/play` ใน ZIP เป็นเว็บล่าสุดแล้ว หาก repository มี pack เก่าให้เอาออกเฉพาะแพ็กที่ไม่ได้ถูกอ้างอิงใน `const PACKED` ของ `docs/play/index.html`
5. อย่าใช้ GitHub Pages เพียงอย่างเดียวแล้วอ้างว่าระบบบัญชีใช้งานได้: Pages เสิร์ฟเว็บเกมได้ แต่ API `/api/account/*` ต้องมี backend พร้อมฐานข้อมูล อ่าน `hosting/DEPLOYMENT.md`

## เปิดและ rebuild เกม

ต้องใช้ **Godot 4.3 stable** และ export templates รุ่นเดียวกัน; Python 3 พร้อม Pillow สำหรับ package เว็บ; Node 24+ สำหรับชุดทดสอบบัญชี

```sh
cd game-source
godot --headless --editor --import --path .
godot --headless --path . -s res://tools/check_scripts.gd
godot --headless --path . res://tests/integration/divine_region_test.tscn
godot --headless --path . res://tests/integration/star_wings_test.tscn
godot --headless --path . res://tests/integration/save_progression_test.tscn
```

ใช้ user-data directory แยกสำหรับ QA เช่น `XDG_DATA_HOME=/tmp/toon-qa` บน Linux เพื่อไม่ให้การทดสอบเขียนเซฟของผู้เล่น

```sh
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m pip install Pillow
python3 tools/package_web.py --pages docs/play
```

หลัง rebuild ต้องคัดลอกหน้ารวมภาพกลับจาก snapshot สำรอง และปรับ gallery links / URL ของ link preview ให้ตรงกับโฮสต์ปลายทาง เพราะ `package_web.py --pages` สร้างโฟลเดอร์ `docs/play` ใหม่ ให้ใช้เว็บพร้อมอัปใน ZIP ได้ทันทีถ้าไม่ได้แก้ซอร์ส ไม่จำเป็นต้อง rebuild

## ตรวจ ZIP

```sh
python3 handoff-tools/verify_package.py
```

ตรวจ build/เวอร์ชัน ไฟล์และ SHA-256, gzip game pack ทุกส่วน และการอ้างอิงไฟล์พื้นฐาน

## ฐานข้อมูลและเซฟ

แพ็กนี้รวมโปรแกรมระบบบัญชี schema และ migration **ไม่ได้รวมข้อมูลบัญชี/รหัสผ่าน/เซฟจริงจากฐานข้อมูล production** ข้อมูลเหล่านั้นอยู่ที่ระบบเดิม ส่วนเซฟในเครื่องผู้เล่นอยู่ใน origin/browser เดิม การย้ายโดเมนหรือฐานข้อมูลต้องวางแผนย้ายข้อมูลหรือส่งออกเซฟก่อนสลับระบบ และทดสอบบัญชีเดิมก่อนประกาศว่าเล่นต่อได้

ไม่มี access token, keystore, `.env`, `.git`, `node_modules`, cache ของ editor หรือไฟล์ทดสอบที่เป็น user-data ใน ZIP นี้ โมเดล/เสียงต้นฉบับและค่าการ import มีครบ Godot สร้าง cache ใหม่ได้

## หลักฐานตรวจล่าสุด

v0.9.4 ผ่านการตรวจซอร์ส 264 resource files, native outfit review 1,734 checks, mask validation, รูปหัว HUD และ regression ดรอป/เซฟ รวมถึงไฟล์เว็บบนระบบจริง ยังไม่ได้วัด FPS หรือทดสอบระยะยาวบน iPhone จริง อย่ารับประกันว่าปัญหา reload บน iPhone หายแล้วจากการตรวจเหล่านี้
