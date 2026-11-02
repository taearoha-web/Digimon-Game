/** Browser integration tests for the account client contract. The small test
 * service deliberately models cookies and revision conflicts; production
 * backend security is verified by its own test suite. */
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
let chromium;
try { ({chromium} = require('playwright')); }
catch { ({chromium} = require('/opt/codex/runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')); }
const js = await fs.readFile(new URL('./web/accounts.js',import.meta.url),'utf8');
const css = await fs.readFile(new URL('./web/accounts.css',import.meta.url),'utf8');
const icon = await fs.readFile(new URL('../docs/play/icon-512.png',import.meta.url)).catch(()=>null);
const screenshotDir=process.env.TOON_ACCOUNT_SCREENSHOT_DIR;
if(screenshotDir)await fs.mkdir(screenshotDir,{recursive:true});
const empty = () => ({slots:{},selectedSlot:1});
const hero = (name,level,saved_at=100) => ({version:1,name,class:'mage',level,gold:300,equip:{},inv:[],saved_at});
const bundle = (name,level,saved_at=100) => ({slots:{'1':hero(name,level,saved_at)},selectedSlot:1});
const users = new Map(), sessions = new Map();
let sequence=0, posts=0, delayedLogout, releaseLogout;
let dropNextPost = false;
// rejectPost: the production validator's answer to a save it refuses (e.g. a class
// it does not know). driftOnPost: another device commits between the GET and
// the POST, so every compare-and-swap loses.
let rejectPost = null, driftOnPost = false;
const headers = [];
const defender = (level,saved_at) => ({version:1,name:'Assotix',class:'defender',level,gold:1200,equip:{},inv:[],party:[{class:'priest',name:'นีน่า',level:level-1}],saved_at});
const server = http.createServer(async (req,res) => {
  function json(status,data) { res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data)); }
  if (req.url === '/accounts.js') {res.setHeader('Content-Type','text/javascript; charset=utf-8');res.end(js);return;}
  if (req.url === '/accounts.css') {res.setHeader('Content-Type','text/css');res.end(css);return;}
  if (req.url === '/icon-512.png') {res.writeHead(icon?200:204,{'Content-Type':'image/png'});res.end(icon);return;}
  if (!req.url.startsWith('/api/account/')) {res.setHeader('Content-Type','text/html');res.end('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/accounts.css"></head><body><canvas id="canvas"></canvas><script src="/accounts.js"></script><script>window.ready=false;toonAccountsReady().then(()=>window.ready=true)</script></body></html>');return;}
  const route=req.url.slice('/api/account/'.length), cookie=(req.headers.cookie||'').match(/sid=([^;]+)/), current=cookie && users.get(sessions.get(cookie[1]));
  let data={};for await (const chunk of req) data._raw=(data._raw||'')+chunk;
  if (data._raw) data=JSON.parse(data._raw);
  const failure=(status,code,message)=>json(status,{error:{code,message}});
  if (route==='session') return json(200,{user:current?{id:current.id,username:current.username}:null});
  if (['register','login','reset-password'].includes(route)) {
    let user=users.get(data.username);
    if (route==='register') {if(user)return failure(409,'username_taken','Taken');user={id:'u'+(++sequence),username:data.username,password:data.password,revision:0,bundle:empty()};users.set(user.username,user);}
    else if (!user || user.password!==data.password) return failure(401,'invalid_credentials','Wrong credentials');
    const sid='s'+(++sequence);sessions.set(sid,user.username);res.setHeader('Set-Cookie','sid='+sid+'; HttpOnly; SameSite=Strict; Path=/');
    return json(200,{user:{id:user.id,username:user.username},...(route==='register'?{recoveryCode:'recover-test-once'}:{})});
  }
  if (!current) return failure(401,'unauthorized','Expired');
  headers.push({route,id:req.headers['x-toon-account-id'],user:current.id});
  if(req.headers['x-toon-account-id']!==current.id)return failure(409,'account_changed','Account changed');
  if(route==='logout') { if(delayedLogout)await new Promise(resolve=>releaseLogout=resolve);res.setHeader('Set-Cookie','sid=; Max-Age=0; Path=/');return json(200,{ok:true}); }
  if(route==='save'&&req.method==='GET')return json(200,{userId:current.id,revision:current.revision,bundle:current.bundle,updatedAt:Date.now()});
  if(route==='save') {
    posts++;
    if(rejectPost)return failure(rejectPost.status,rejectPost.code,rejectPost.message);
    if(driftOnPost)current.revision++;
    if(data.expectedRevision!==current.revision)return failure(409,'save_conflict','A newer save exists. Load it before saving again.');
    current.bundle=data.bundle;current.revision++;
    return json(200,{revision:current.revision,updatedAt:Date.now()});
  }
  failure(404,'missing','Missing');
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const url='http://127.0.0.1:'+server.address().port;
const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox']});
let checks=0;
function ok(value,message){assert.ok(value,message);checks++;}
async function poll(fn,label){const deadline=Date.now()+15000;while(Date.now()<deadline){if(await fn())return;await new Promise(r=>setTimeout(r,100));}throw new Error('Timeout: '+label);}
async function cache(page,key){return page.evaluate(key=>new Promise((resolve,reject)=>{const req=indexedDB.open('toon_tale_accounts_v1');req.onsuccess=()=>{const db=req.result,r=db.transaction('records').objectStore('records').get(key);r.onsuccess=()=>{db.close();resolve(r.result)};r.onerror=reject};req.onerror=reject}),key);}
async function local(page){return page.evaluate(()=>new Promise((resolve,reject)=>{const req=indexedDB.open('/userfs');req.onsuccess=()=>{const db=req.result,r=db.transaction('FILE_DATA').objectStore('FILE_DATA').get('/userfs/godot/app_userdata/Toon Tale/toon_tale_slot_1.json');r.onsuccess=()=>{db.close();resolve(r.result?JSON.parse(new TextDecoder().decode(r.result.contents)):null)};r.onerror=reject};req.onerror=reject}));}
// A file under user:// as Godot's IDBFS keeps it (what SaveBackup.restore writes); `data` null deletes it.
const FILE_ROOT='/userfs/godot/app_userdata/Toon Tale';
async function putFile(page,name,data){return page.evaluate(([path,text])=>new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>{const db=r.result,tx=db.transaction('FILE_DATA','readwrite'),s=tx.objectStore('FILE_DATA');if(text===null)s.delete(path);else s.put({timestamp:new Date(),mode:33188,contents:new TextEncoder().encode(text)},path);tx.oncomplete=()=>{db.close();resolve()};tx.onerror=reject};r.onerror=reject}),[FILE_ROOT+'/'+name,data===null?null:JSON.stringify(data)]);}
async function readFile(page,name){return page.evaluate(path=>new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>{const db=r.result,q=db.transaction('FILE_DATA').objectStore('FILE_DATA').get(path);q.onsuccess=()=>{db.close();resolve(q.result&&q.result.contents?JSON.parse(new TextDecoder().decode(q.result.contents)):null)};q.onerror=reject};r.onerror=reject}),FILE_ROOT+'/'+name);}
async function hasFile(page,name){return page.evaluate(path=>new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>{const db=r.result,q=db.transaction('FILE_DATA').objectStore('FILE_DATA').get(path);q.onsuccess=()=>{db.close();resolve(!!q.result)};q.onerror=reject};r.onerror=reject}),FILE_ROOT+'/'+name);}
// The panel can re-render once more while it settles (a session check finishing), which
// wipes typed fields on slow CI runners; fill until the values stick, then submit.
async function form(page,name,password='super-secret-10'){for(let attempt=0;attempt<5;attempt++){await page.locator('#ta-username').fill(name);await page.locator('#ta-password').fill(password);const confirm=page.locator('#ta-confirm');if(await confirm.count())await confirm.fill(password);await page.waitForTimeout(150);const stuck=await page.evaluate(([n,p])=>{const u=document.querySelector('#ta-username'),w=document.querySelector('#ta-password'),c=document.querySelector('#ta-confirm');return !!u&&u.value===n&&!!w&&w.value===p&&(!c||c.value===p);},[name,password]);if(stuck)break;}await page.locator('.ta-submit').click();}
const context=await browser.newContext({viewport:{width:430,height:932},hasTouch:true,isMobile:true});
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
try {
  // A brand new browser creates /userfs before Godot. The client must release
  // its connection so Godot can upgrade to Emscripten's version21 unblocked.
  const freshContext=await browser.newContext();const fresh=await freshContext.newPage();
  await fresh.goto(url);await fresh.locator('#ta-username').waitFor();
  await fresh.getByRole('button',{name:'เล่นในเครื่องนี้ก่อน',exact:true}).click();await fresh.waitForFunction(()=>window.ready);
  const upgraded=await fresh.evaluate(()=>new Promise(resolve=>{const r=indexedDB.open('/userfs',21);r.onblocked=()=>resolve(false);r.onerror=()=>resolve(false);r.onsuccess=()=>{r.result.close();resolve(true)}}));
  ok(upgraded,'fresh IDB can upgrade to Godot version21 without blocked connection');
  await fresh.evaluate(b=>toonCloudSave(b),bundle('Fresh guest',1));
  await poll(async()=>((await cache(fresh,'guest')).bundle.slots['1'].level===1),'fresh guest cache');
  const reopened=await fresh.evaluate(()=>new Promise(resolve=>{const r=indexedDB.open('/userfs',22);r.onblocked=()=>resolve(false);r.onerror=()=>resolve(false);r.onsuccess=()=>{r.result.close();resolve(true)}}));
  ok(reopened,'cache-only saves never reopen the live Godot file database');
  await freshContext.close();
  // Seed an existing legacy guest profile before the account gate touches IDB.
  await page.route('**/accounts.js',route=>route.fulfill({contentType:'text/javascript',body:''}));
  await page.goto(url);
  await page.evaluate(p=>new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs',21);r.onupgradeneeded=()=>{const s=r.result.createObjectStore('FILE_DATA');s.createIndex('timestamp','timestamp')};r.onsuccess=()=>{const db=r.result,tx=db.transaction('FILE_DATA','readwrite');tx.objectStore('FILE_DATA').put({timestamp:new Date(),mode:33188,contents:new TextEncoder().encode(JSON.stringify(p))},'/userfs/godot/app_userdata/Toon Tale/toon_tale_save.json');tx.oncomplete=()=>{db.close();resolve()};tx.onerror=reject};r.onerror=reject}),hero('Guest <img onerror=bad()>',44));
  await page.unroute('**/accounts.js');await page.reload();await page.locator('#ta-username').waitFor();
  ok((await cache(page,'guest')).bundle.slots['1'].level===44,'legacy guest preserved before gate');
  if(screenshotDir)await page.screenshot({path:screenshotDir+'/login-portrait.png',fullPage:true});
  await page.getByRole('button',{name:'สร้างบัญชีใหม่',exact:true}).click();await form(page,'hero_one');
  await page.getByRole('heading',{name:'เก็บรหัสกู้บัญชีของคุณ'}).waitFor();
  ok(!(await page.evaluate(()=>window.ready)),'recovery gate must be acknowledged');
  await page.getByRole('button',{name:'ไปต่อ',exact:true}).click();
  ok((await page.locator('.ta-feedback').innerText()).includes('ติ๊ก'),'recovery acknowledgement enforced');
  await page.locator('#ta-kept').check();await page.getByRole('button',{name:'ไปต่อ',exact:true}).click();
  await page.getByRole('heading',{name:'นำตัวละครเดิมเข้าบัญชี'}).waitFor();
  ok(users.get('hero_one').revision===0,'guest never auto-uploaded on register');
  ok((await page.locator('.ta-hero strong').innerText()).includes('<img'),'profile names escaped');
  await page.getByRole('button',{name:'นำตัวละครเหล่านี้เข้าบัญชี',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok((await local(page)).level===44,'selected account installed in actual Godot IDB');
  ok((await cache(page,'guest')).bundle.slots['1'].level===44,'guest backup remains isolated');
  ok(users.get('hero_one').bundle.slots['1'].level===44,'explicit guest migration posted');
  ok(headers.every(h=>h.id===h.user),'cloud calls carry the exact account identity');
  ok(!(await cache(page,'lastUser')).password,'no password stored as metadata');
  const before=posts;await page.evaluate(([a,b])=>{toonCloudSave(JSON.stringify(a));toonCloudSave(JSON.stringify(b))},[bundle('Online hero',45,200),bundle('Online hero',46,201)]);
  await poll(()=>users.get('hero_one').bundle.slots['1'].level===46,'coalesced upload');
  ok(posts===before+1,'bursty saves coalesce into one latest upload');
  await poll(()=>page.evaluate(()=>!JSON.parse(toonCloudStatus()).pending),'acknowledged revision');
  ok(!(await page.evaluate(()=>JSON.parse(toonCloudStatus()).pending)),'acknowledged revision clears pending state');
  // Ten character slots: heroes on circles 5-10 and a selected slot past 4 reach the account.
  const ten={slots:{'1':hero('Online hero',46,201),'7':hero('Seventh',12,205),'10':hero('Tenth',3,206)},selectedSlot:10};
  await page.evaluate(b=>toonCloudSave(JSON.stringify(b)),ten);
  await poll(()=>users.get('hero_one').bundle.slots['10']&&users.get('hero_one').bundle.slots['10'].name==='Tenth','slot 10 upload');
  ok(users.get('hero_one').bundle.slots['7'].name==='Seventh'&&users.get('hero_one').bundle.selectedSlot===10,'slots 7 and 10 and selected slot 10 reach the account');
  await poll(()=>page.evaluate(()=>!JSON.parse(toonCloudStatus()).pending),'ten-slot revision acknowledged');
  // A second live game in the same origin must never touch the shared IDB.
  const other=await context.newPage();await other.goto(url);await other.getByRole('heading',{name:'เกมเปิดอยู่ในแท็บอื่น'}).waitFor();
  ok(!(await other.evaluate(()=>window.ready)),'origin-wide lock blocks a second engine');await other.close();
  // Lost POST response: the server committed, so next409 can be acknowledged.
  await page.route('**/api/account/save',async route=>{if(route.request().method()==='POST' && dropNextPost){dropNextPost=false;await route.fetch();await route.abort('failed');}else await route.continue()});
  dropNextPost=true;await page.evaluate(b=>toonCloudSave(b),bundle('Online hero',47,202));
  await poll(()=>users.get('hero_one').bundle.slots['1'].level===47,'lost response committed');
  await poll(()=>page.evaluate(()=>JSON.parse(toonCloudStatus()).offline),'lost response preserves draft');
  await page.evaluate(()=>window.dispatchEvent(new Event('online')));
  await poll(()=>page.evaluate(()=>!JSON.parse(toonCloudStatus()).pending),'lost response reconciliation');
  ok(!(await page.evaluate(()=>JSON.parse(toonCloudStatus()).conflict)),'exact committed bundle does not cause a false conflict');
  // A genuinely different cloud revision needs an explicit player choice.
  const first=users.get('hero_one');first.bundle=bundle('Other device',51,300);first.revision++;
  await page.evaluate(b=>toonCloudSave(b),bundle('Online hero',48,203));
  await page.getByRole('heading',{name:'พบเซฟใหม่จากอีกเครื่อง'}).waitFor();
  if(screenshotDir)await page.screenshot({path:screenshotDir+'/conflict-portrait.png',fullPage:true});
  ok((await page.evaluate(()=>JSON.parse(toonCloudStatus()).modalOpen))===true,'conflict pauses Godot with boolean modalOpen');
  ok(first.bundle.slots['1'].level===51,'409 does not blindly overwrite server');
  await page.evaluate(p=>new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>{const db=r.result,tx=db.transaction('FILE_DATA','readwrite');tx.objectStore('FILE_DATA').put({timestamp:new Date(),mode:33188,contents:new TextEncoder().encode(JSON.stringify(p))},'/userfs/godot/app_userdata/Toon Tale/toon_tale_slot_1.json');tx.oncomplete=()=>{db.close();resolve()};tx.onerror=reject};r.onerror=reject}),hero('Old engine focus-out',98,999999));
  await page.getByRole('button',{name:'ใช้เซฟออนไลน์ล่าสุด',exact:true}).click();await page.getByRole('heading',{name:'ยินดีต้อนรับ hero_one'}).waitFor();
  await page.getByRole('button',{name:'เล่นต่อจากเซฟออนไลน์',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok((await local(page)).level===51,'chosen cloud installed only after full reload');
  ok((await cache(page,'backups:'+first.id.replace(/^/,'account:'))).some(x=>x.bundle.slots['1'].level===48),'conflicting local progress backed up');
  // Cookies changed outside this document must not retarget an old draft.
  users.set('hero_two',{id:'u_other',username:'hero_two',password:'super-secret-10',revision:first.revision,bundle:bundle('Second account',9)});
  sessions.set('forced_other','hero_two');await context.addCookies([{name:'sid',value:'forced_other',url,httpOnly:true}]);
  await page.evaluate(b=>toonCloudSave(b),bundle('Old account only',55,500));
  await page.getByRole('heading',{name:'บัญชีเปลี่ยนในอีกแท็บ'}).waitFor();
  ok(users.get('hero_two').bundle.slots['1'].level===9,'cookie account changes cannot overwrite another user');
  ok((await cache(page,'account:'+first.id)).bundle.slots['1'].level===55,'old user draft preserved under old identity');
  await page.getByRole('button',{name:'เปิดหน้าล็อกอินใหม่'}).click();await page.locator('#ta-username').waitFor();
  await form(page,'hero_two');await page.getByRole('heading',{name:'ยินดีต้อนรับ hero_two'}).waitFor();
  ok(users.get('hero_two').revision===first.revision,'existing cloud never auto-imports guest');
  await page.getByRole('button',{name:'เล่นต่อจากเซฟออนไลน์',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok((await local(page)).level===9,'second account has separate character files');
  // Suppress late Godot focus-out saves while logout is replacing the session.
  delayedLogout=true;await page.evaluate(()=>toonOpenAccountPanel());
  await page.getByRole('button',{name:'ออกจากบัญชี / เปลี่ยนบัญชี'}).click({noWaitAfter:true});
  await poll(()=>!!releaseLogout,'logout pending');
  await page.evaluate(b=>toonCloudSave(b),bundle('Late focus out',99,900));releaseLogout();delayedLogout=false;
  await page.locator('#ta-username').waitFor();
  ok((await cache(page,'account:u_other')).bundle.slots['1'].level===9,'late saves ignored during identity replacement');
  await page.getByRole('button',{name:'เล่นในเครื่องนี้ก่อน',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok((await local(page)).level===44,'logout guest choice restores original guest characters');
  // Local backups can actually be selected and recovered, rather than merely
  // retained in an inaccessible database.
  await page.evaluate(b=>toonCloudSave(b),bundle('New guest progress',50,2000));
  await poll(async()=>((await cache(page,'guest')).bundle.slots['1'].level===50),'guest cache');
  await page.evaluate(()=>toonOpenAccountPanel());
  await page.getByRole('button',{name:'สำเนาเซฟในเครื่อง',exact:true}).click();
  await page.getByRole('button',{name:/นำเข้าบัญชี hero_one/}).click();
  await page.getByRole('heading',{name:'ตรวจสำเนาก่อนนำกลับมาใช้'}).waitFor();
  await page.getByRole('button',{name:'ยืนยันใช้สำเนานี้และเปิดใหม่'}).click();
  await page.locator('#ta-username').waitFor();
  await page.getByRole('button',{name:'เล่นในเครื่องนี้ก่อน',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok((await local(page)).level===44,'selected local backup restored through staged switch');
  ok((await cache(page,'backups:guest')).some(x=>x.bundle.slots['1'].level===50),'backup restore preserves previous guest progress');
  // Cached account can boot while the API is unreachable and later upload its
  // own pending draft, without using a guest or another account cache.
  await page.evaluate(()=>toonOpenAccountPanel());await page.getByRole('button',{name:'เข้าสู่ระบบ / สร้างบัญชี'}).click();
  await form(page,'hero_two');
  await page.evaluate(()=>JSON.parse(toonCloudStatus())).catch(()=>null);
  await page.getByRole('heading',{name:'ยินดีต้อนรับ hero_two'}).waitFor();
  await page.getByRole('button',{name:'เล่นต่อจากเซฟออนไลน์'}).click();await page.waitForFunction(()=>window.ready);
  await page.route('**/api/account/**',route=>route.abort('failed'));await page.reload();
  await page.getByRole('heading',{name:'เล่นต่อขณะออฟไลน์'}).waitFor();
  await page.getByRole('button',{name:'เล่นเซฟของบัญชีในเครื่องนี้'}).click();await page.waitForFunction(()=>window.ready);
  ok((await local(page)).level===9,'offline uses only last known account cache');
  await page.evaluate(b=>toonCloudSave(b),bundle('Offline second hero',10,2500));
  await poll(async()=>((await cache(page,'account:u_other')).dirty===true),'offline durable draft');
  ok(users.get('hero_two').bundle.slots['1'].level===9,'offline progress does not pretend cloud acknowledgement');
  await page.unroute('**/api/account/**');await page.evaluate(()=>window.dispatchEvent(new Event('online')));
  await poll(()=>users.get('hero_two').bundle.slots['1'].level===10,'reconnect upload');
  await poll(()=>page.evaluate(()=>!JSON.parse(toonCloudStatus()).pending),'reconnect acknowledgement');
  ok((await cache(page,'account:u_other')).dirty===false,'reconnect acknowledges revision and clears durable draft');
  // The owner's report: this phone holds a Defender Lv.23 the server never got
  // (uploads failed), another device then saved a Vagabond Lv.12. On the start
  // screen the player picks "use this device's save instead of the online one".
  const two=users.get('hero_two');
  await page.route('**/api/account/save',route=>route.request().method()==='POST'?route.abort('failed'):route.continue());
  const phone={slots:{'1':defender(23,3000)},selectedSlot:1};
  await page.evaluate(p=>new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>{const db=r.result,tx=db.transaction('FILE_DATA','readwrite');tx.objectStore('FILE_DATA').put({timestamp:new Date(),mode:33188,contents:new TextEncoder().encode(JSON.stringify(p))},'/userfs/godot/app_userdata/Toon Tale/toon_tale_slot_1.json');tx.oncomplete=()=>{db.close();resolve()};tx.onerror=reject};r.onerror=reject}),phone.slots['1']);
  await page.evaluate(b=>toonCloudSave(b),JSON.stringify(phone));
  await poll(async()=>{const c=await cache(page,'account:u_other');return c.dirty===true&&c.bundle.slots['1'].level===23;},'unsent defender draft');
  const stuckRevision=two.revision;
  await page.unroute('**/api/account/save');
  // 1. Same revision, but the server refuses the save: the player must see the
  // server's reason on the conflict screen, not land back on the login form.
  rejectPost={status:400,code:'invalid_save',message:'The character class, level or save version is invalid.'};
  await page.reload();
  await page.getByRole('heading',{name:'พบเซฟใหม่จากอีกเครื่อง'}).waitFor();
  let note=await page.locator('.ta-feedback').innerText();
  ok(note.includes('HTTP 400')&&note.includes('invalid_save')&&note.includes(rejectPost.message),'refused auto-upload names HTTP code, server code and detail: '+note);
  ok((await page.locator('.ta-compare').innerText()).includes('สายโล่'),'the conflict screen names the defender class');
  ok(two.revision===stuckRevision&&two.bundle.slots['1'].level===10,'a refused auto-upload changes nothing online');
  // 2. Another device saved meanwhile; the explicit choice is refused the same way.
  two.bundle=bundle('Assotix',12,3500);two.bundle.slots['1'].class='vagabond';two.revision++;
  await page.getByRole('button',{name:'ยืนยันใช้เซฟในเครื่องแทนออนไลน์',exact:true}).click();
  await poll(async()=>(await page.locator('.ta-feedback').innerText()).includes('HTTP 400'),'refusal shown');
  note=await page.locator('.ta-feedback').innerText();
  ok(note.includes('invalid_save')&&note.includes(rejectPost.message),'refused replacement shows the server detail: '+note);
  ok(await page.getByRole('heading',{name:'พบเซฟใหม่จากอีกเครื่อง'}).isVisible(),'the choice stays on screen after a refusal');
  ok(await page.getByRole('button',{name:'ยืนยันใช้เซฟในเครื่องแทนออนไลน์',exact:true}).isEnabled(),'buttons are usable again after a refusal');
  ok(two.bundle.slots['1'].level===12&&!(await page.evaluate(()=>window.ready)),'a refused replacement leaves the online save and does not start the game');
  const kept=await cache(page,'account:u_other');
  ok(kept.dirty===true&&kept.bundle.slots['1'].level===23&&(await local(page)).level===23,'the local defender stays untouched after a refusal');
  // 3. Compare-and-swap keeps losing (the other device is still uploading): say so.
  rejectPost=null;driftOnPost=true;
  await page.getByRole('button',{name:'ยืนยันใช้เซฟในเครื่องแทนออนไลน์',exact:true}).click();
  await poll(async()=>(await page.locator('.ta-feedback').innerText()).includes('HTTP 409'),'conflict loop is reported');
  ok((await page.locator('.ta-compare').innerText()).includes('เลเวล 12'),'the re-read online save is shown with the 409 note');
  ok(two.bundle.slots['1'].level===12,'a lost compare-and-swap changes nothing online');
  // 4. The server accepts: the online save becomes the phone's defender and the game starts with it.
  driftOnPost=false;const revisionBefore=two.revision;
  await page.getByRole('button',{name:'ยืนยันใช้เซฟในเครื่องแทนออนไลน์',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok(two.bundle.slots['1'].class==='defender'&&two.bundle.slots['1'].level===23&&two.revision===revisionBefore+1,'the local defender replaced the online save at the next revision');
  ok((await local(page)).level===23&&(await local(page)).class==='defender','the game starts with the defender installed');
  const settled=await cache(page,'account:u_other');
  ok(settled.dirty===false&&settled.revision===two.revision,'the draft is acknowledged at the server revision');
  ok((await cache(page,'backups:account:u_other')).some(x=>x.bundle.slots['1'].level===12&&x.bundle.slots['1'].class==='vagabond'),'the replaced online save is backed up on this device');
  // 5. "Play this device's save now, send it later" starts the game at once and uploads afterwards.
  await page.route('**/api/account/save',route=>route.request().method()==='POST'?route.abort('failed'):route.continue());
  await page.evaluate(b=>toonCloudSave(b),JSON.stringify({slots:{'1':defender(24,4000)},selectedSlot:1}));
  await poll(async()=>{const c=await cache(page,'account:u_other');return c.dirty===true&&c.bundle.slots['1'].level===24;},'second unsent defender draft');
  two.bundle=bundle('Assotix',13,4500);two.bundle.slots['1'].class='vagabond';two.revision++;
  await page.unroute('**/api/account/save');await page.reload();
  await page.getByRole('heading',{name:'พบเซฟใหม่จากอีกเครื่อง'}).waitFor();
  await page.getByRole('button',{name:'เล่นเซฟในเครื่องก่อน ค่อยส่งออนไลน์ภายหลัง',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok((await local(page)).level===24,'deferring the upload still starts the game with the local save');
  await poll(()=>two.bundle.slots['1'].level===24&&two.bundle.slots['1'].class==='defender','deferred upload');
  await poll(()=>page.evaluate(()=>!JSON.parse(toonCloudStatus()).pending),'deferred upload acknowledged');
  ok((await cache(page,'account:u_other')).revision===two.revision,'the deferred upload is acknowledged at the server revision');
  // Restoring an offline backup in the game (SaveBackup.restore) rewrites the slot file
  // with saved_at = now and lists the slot in backups/restored.json. Without that marker a
  // local slot newer than the online one is uploaded at boot without a question (the
  // revision matches, so chooseAccountSave sends it): the behaviour before the marker.
  const MARKER='backups/restored.json';
  await putFile(page,'toon_tale_slot_1.json',defender(25,5000));
  let cloudBefore=two.revision;await page.reload();await page.waitForFunction(()=>window.ready);
  ok(two.bundle.slots['1'].level===25&&two.revision===cloudBefore+1&&!(await page.evaluate(()=>JSON.parse(toonCloudStatus()).conflict)),'without a restore marker a newer local slot is uploaded at boot as before, no conflict screen');
  // With the marker the player is asked, the restored save first: nothing is uploaded or installed until they choose.
  await putFile(page,'toon_tale_slot_1.json',defender(26,6000));await putFile(page,MARKER,{time:6000,slots:[1]});
  cloudBefore=two.revision;await page.reload();
  await page.getByRole('heading',{name:'เซฟที่กู้คืน หรือเซฟออนไลน์'}).waitFor();
  if(screenshotDir)await page.screenshot({path:screenshotDir+'/restored-conflict-portrait.png',fullPage:true});
  ok((await page.locator('.ta-intro').innerText()).includes('คุณเพิ่งกู้คืนเซฟในเครื่อง — จะใช้เซฟที่กู้คืนหรือเซฟออนไลน์?'),'the restore line is shown');
  ok((await page.locator('.ta-hint').innerText()).includes('ช่อง 1'),'the restored slots are named');
  const buttons=await page.locator('.ta-actions button').evaluateAll(list=>list.map(b=>({text:b.textContent,primary:b.classList.contains('primary')})));
  ok(buttons[0].text==='ใช้เซฟที่กู้คืน (ส่งขึ้นออนไลน์)'&&buttons[0].primary&&buttons[1].text==='ใช้เซฟออนไลน์ล่าสุด'&&!buttons[1].primary,'the restored save is the first, primary button: '+JSON.stringify(buttons));
  await poll(()=>page.evaluate(()=>document.activeElement&&document.activeElement.textContent==='ใช้เซฟที่กู้คืน (ส่งขึ้นออนไลน์)'),'default button focused');
  ok((await page.locator('.ta-compare').innerText()).includes('ที่กู้คืนในเครื่องนี้')&&(await page.locator('.ta-compare').innerText()).includes('เลเวล 26')&&(await page.locator('.ta-compare').innerText()).includes('เลเวล 25'),'both saves are shown for comparison');
  ok(two.revision===cloudBefore&&two.bundle.slots['1'].level===25&&(await local(page)).level===26&&!(await page.evaluate(()=>window.ready)),'nothing is uploaded or installed before the choice');
  ok(await hasFile(page,MARKER),'the marker stays until the choice is made');
  await page.locator('.ta-actions button').first().click();await page.waitForFunction(()=>window.ready);
  ok(two.bundle.slots['1'].level===26&&two.revision===cloudBefore+1,'the default button uploads the restored save over the online one');
  ok((await local(page)).level===26&&(await cache(page,'account:u_other')).dirty===false,'the game starts with the restored save, acknowledged at the new revision');
  ok(!(await hasFile(page,MARKER)),'the marker is cleared after the choice');
  ok((await cache(page,'backups:account:u_other')).some(x=>x.bundle.slots['1'].level===25),'the replaced online save is backed up on this device');
  // The second choice keeps the online copy: the restored save is backed up, not lost.
  await putFile(page,'toon_tale_slot_1.json',defender(27,7000));await putFile(page,MARKER,{time:7000,slots:[1]});
  cloudBefore=two.revision;await page.reload();
  await page.getByRole('heading',{name:'เซฟที่กู้คืน หรือเซฟออนไลน์'}).waitFor();
  await page.getByRole('button',{name:'ใช้เซฟออนไลน์ล่าสุด',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok(two.revision===cloudBefore&&two.bundle.slots['1'].level===26&&(await local(page)).level===26,'choosing the online save installs it and uploads nothing');
  ok((await cache(page,'backups:account:u_other')).some(x=>x.bundle.slots['1'].level===27&&x.label.includes('กู้คืน')),'the restored save is kept as a local backup');
  ok(!(await hasFile(page,MARKER)),'the marker is cleared after choosing the online save too');
  // A stale marker with nothing newer in the local files changes nothing and is cleared.
  await putFile(page,MARKER,{time:7000,slots:[1]});
  cloudBefore=two.revision;await page.reload();
  await page.getByRole('heading',{name:'ยินดีต้อนรับ hero_two'}).waitFor();
  await page.getByRole('button',{name:'เล่นต่อจากเซฟออนไลน์',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok(two.revision===cloudBefore&&(await local(page)).level===26&&!(await hasFile(page,MARKER)),'a marker without a newer local save keeps the usual boot and is cleared');
  // The storage every character shares (the game's toon_tale_storage.json) travels as the
  // bundle's "storage" and "storageMigrated": uploaded with the heroes, installed with them,
  // read from the game's files, counted on the choice screens, removed with a bundle without it.
  const STORAGE='toon_tale_storage.json', chaos={kind:'jewel',id:'chaos',count:3}, pink={kind:'jewel',id:'pink',count:2};
  await page.evaluate(b=>toonCloudSave(b),JSON.stringify({slots:{'1':defender(28,8000)},selectedSlot:1,storage:[chaos],storageMigrated:{'u:old':1}}));
  await poll(()=>Array.isArray(two.bundle.storage)&&two.bundle.storage.length===1,'shared storage upload');
  ok(two.bundle.storage[0].id==='chaos'&&two.bundle.storageMigrated['u:old']===1,'the shared storage and its record reach the account');
  await poll(()=>page.evaluate(()=>!JSON.parse(toonCloudStatus()).pending),'shared storage acknowledged');
  two.bundle={...two.bundle,slots:{'1':defender(29,8100)}};two.revision++;
  await page.reload();await page.getByRole('heading',{name:'ยินดีต้อนรับ hero_two'}).waitFor();
  ok((await page.locator('.ta-body').innerText()).includes('คลังรวมทุกตัวละคร: 1 ชิ้น'),'the account screen counts the shared storage');
  await page.getByRole('button',{name:'เล่นต่อจากเซฟออนไลน์',exact:true}).click();await page.waitForFunction(()=>window.ready);
  let file=await readFile(page,STORAGE);
  ok(file&&file.version===1&&file.items.length===1&&file.items[0].id==='chaos'&&file.migrated['u:old']===1,'installing the account writes the shared storage file: '+JSON.stringify(file));
  // The game deposits (the storage file and the slot change): the next start sends both.
  await putFile(page,STORAGE,{version:1,items:[chaos,pink],migrated:{'u:old':1}});await putFile(page,'toon_tale_slot_1.json',defender(29,8200));
  let cloudBefore2=two.revision;await page.reload();await page.waitForFunction(()=>window.ready);
  ok(two.revision===cloudBefore2+1&&two.bundle.storage.length===2&&two.bundle.storage[1].id==='pink','the shared storage in the game files is uploaded with the heroes');
  // Every hero deleted, the storage kept: the account still counts as holding a save.
  two.bundle={slots:{},selectedSlot:1,storage:[pink],storageMigrated:{}};two.revision++;
  await page.reload();await page.getByRole('heading',{name:'ยินดีต้อนรับ hero_two'}).waitFor();
  ok((await page.locator('.ta-body').innerText()).includes('คลังรวมทุกตัวละคร: 1 ชิ้น'),'an account with only a shared storage is not offered a guest import over it');
  await page.getByRole('button',{name:'เล่นต่อจากเซฟออนไลน์',exact:true}).click();await page.waitForFunction(()=>window.ready);
  file=await readFile(page,STORAGE);
  ok(file&&file.items.length===1&&file.items[0].id==='pink'&&!(await hasFile(page,'toon_tale_slot_1.json')),'only the storage is installed');
  // A bundle from before the shared storage has none: the file goes with it.
  two.bundle=bundle('Assotix',30,8300);two.bundle.slots['1'].class='defender';two.revision++;
  await page.reload();await page.getByRole('heading',{name:'ยินดีต้อนรับ hero_two'}).waitFor();
  ok(!(await page.locator('.ta-body').innerText()).includes('คลังรวม'),'a bundle without a shared storage shows none');
  await page.getByRole('button',{name:'เล่นต่อจากเซฟออนไลน์',exact:true}).click();await page.waitForFunction(()=>window.ready);
  ok(!(await hasFile(page,STORAGE))&&(await local(page)).level===30,'installing a bundle without it removes the storage file');
  await page.evaluate(()=>toonOpenAccountPanel());await page.setViewportSize({width:956,height:440});
  if(screenshotDir)await page.screenshot({path:screenshotDir+'/account-landscape.png',fullPage:true});
  ok(await page.locator('.ta-card').evaluate(el=>el.scrollWidth<=el.clientWidth),'landscape card has no horizontal overflow');
    ok(errors.filter(e=>!e.includes('toonAccountsReady is not defined')).length===0,'no client JavaScript errors');
  console.log('PASS '+checks+' account client browser checks');
} catch(error) {console.error('UI at failure:',await page.locator('body').innerText());console.error('JS errors:',errors);throw error;} finally {await context.close();await browser.close();await new Promise(resolve=>server.close(resolve));}
