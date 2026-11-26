// Actual UI acceptance only. Run via tools/verify.py; owns its Chrome/profile/server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const opt=(k,d)=>process.argv.find(v=>v.startsWith('--'+k+'='))?.slice(k.length+3)||d;
const out=path.resolve(root,opt('evidence','candidates/s14-bombing/chrome-review-r13'));
const pack=path.resolve(root,opt('pack','build/s14-bombing-review-r13'));
const scope=opt('scope','full');
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/s14-bomb-chrome-'));
const audit={startedUtc:new Date().toISOString(),browserPlugin:'Browser plugin not available',flow:'Normal Showcase -> actual four bomber task modes -> actual fighter interceptions -> visible both commander execution -> pause/speed/restart -> original training',scope:scope==='b25-ui'?'Focused UI row selection and resumed bomber camera':'Bounded integration; no long/performance acceptance',viewport:{width:1280,height:720},checks:[],interactions:[],console:[],pageErrors:[],cleanup:{}};
let context,page,statusInterval,statusBusy=false;
const check=(passed,name,detail=null)=>{audit.checks.push({name,passed,detail});if(!passed)throw Error(name)};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream'};
const server=http.createServer(async(req,res)=>{try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(name==='/favicon.ico'){res.writeHead(204);res.end();return}const f=path.resolve(pack,'.'+name);if(!f.startsWith(pack+'/'))throw Error('outside pack');const b=await fs.readFile(f);res.writeHead(200,{'Content-Type':mime[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});res.end(b)}catch{res.writeHead(404);res.end('missing')}});
let url;
try{
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve)});url='http://127.0.0.1:'+server.address().port+'/index.html';audit.url=url;
 audit.hardware={cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),os:os.release()};
 context=await chromium.launchPersistentContext(profile,{executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,viewport:audit.viewport,deviceScaleFactor:1,args:['--window-position=-1800,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 page=context.pages()[0]||await context.newPage();page.on('console',m=>{if(['error','warning'].includes(m.type()))audit.console.push({type:m.type(),text:m.text()})});page.on('pageerror',e=>audit.pageErrors.push(String(e)));
 await page.goto(url,{waitUntil:'load',timeout:60000});await page.waitForFunction(()=>window.S14X?.latest?.models===23,null,{timeout:60000});
 audit.browserVersion=await context.browser()?.version();
 audit.identity=await page.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect(),g=c.getContext('webgl2'),e=g.getExtension('WEBGL_debug_renderer_info');return{url:location.href,title:document.title,ua:navigator.userAgent,canvas:{width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height},gpu:e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):null,webgl:g.getParameter(g.VERSION),dpr:devicePixelRatio}});
 check(audit.identity.url===url&&audit.identity.title.includes('S14'),'Correct S14 page');check(audit.identity.canvas.width===1280&&audit.identity.canvas.height===720,'Real 1280x720 canvas');check(audit.identity.gpu&&!/swiftshader|software|llvmpipe/i.test(audit.identity.gpu),'Hardware WebGL');
 const snap=()=>page.evaluate(()=>window.S14X.latest);
 statusInterval=setInterval(async()=>{if(statusBusy)return;statusBusy=true;try{const s=await snap();const {journal,...state}=s;await fs.writeFile(path.join(out,'live.json'),JSON.stringify({utc:new Date().toISOString(),state}));}catch{}finally{statusBusy=false}},10000);
 const wait=(fn,arg=null,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
 const phase=async name=>{await page.evaluate(v=>window.S14X.phase(v),name);await fs.writeFile(path.join(out,'progress.json'),JSON.stringify({phase:name,time:new Date().toISOString(),checks:audit.checks.length}));console.log('S14 Chrome '+name)};
 const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
 const gameClick=async point=>{const r=await page.locator('canvas').boundingBox();audit.interactions.push({action:'click',canvas:point,wallUtc:new Date().toISOString()});await page.mouse.click(r.x+point[0]*r.width/1280,r.y+point[1]*r.height/720)};
 const key=async value=>{audit.interactions.push({action:'key',key:value,wallUtc:new Date().toISOString()});await page.keyboard.press(value)};
 const focus=()=>gameClick([940,580]);
 const choose=async(key,index)=>{
  let s=await snap();await gameClick(s.controls[key]);await wait(k=>window.S14X.latest.popups[k].visible,key);
  s=await snap();check(index>=0&&index<s.popups[key].count,'Visible menu entry '+key+'/'+index);
  const p=s.popups[key],r=await page.locator('canvas').boundingBox();
  await page.mouse.move(r.x+(p.position[0]+p.size[0]*.5)*r.width/1280,r.y+(p.position[1]+p.size[1]*.5)*r.height/720);
  const content=p.count*p.row_height+p.padding_top+p.padding_bottom,scroll=Math.max(0,content-p.size[1]);
  const bottom=index*p.row_height>=scroll;
  await page.mouse.wheel(0,bottom?2400:-2400);await sleep(250);
  const y=p.position[1]+p.padding_top+(index+.5)*p.row_height-(bottom?scroll:0);
  check(y>p.position[1]&&y<p.position[1]+p.size[1],'Requested item visible after actual menu scroll '+key+'/'+index);
  if(key==='segment'&&index===27)await shot('bombing_visible_menu');
  audit.interactions.push({action:'menu_scroll',menu:key,index,measured:p,scroll,bottom,wallUtc:new Date().toISOString()});
  await gameClick([p.position[0]+p.size[0]*.5,y]);
  await wait(k=>!window.S14X.latest.popups[k].visible,key);
 };
 const button=async label=>{const s=await snap();check(!!s.buttons[label],'Visible button '+label);await gameClick(s.buttons[label])};
 await sleep(500);let s=await snap();
 check(s.models===23&&s.static_models.length===3,'Normal harbor has23 units and3 static aircraft');
 check(s.popups.segment.count===30&&s.popups.segment.labels.slice(24).join('|').includes('截击'),'All6 real task entries discoverable in normal menu');
 await shot('normal_harbor');
 const cases=[];
 const eventRows=(state)=>page.evaluate(({generation,exercise})=>window.S14X.data.events.filter(e=>e.generation===generation&&e.exercise===exercise),state);
 for(const [index,mode,count]of (scope==='b25-ui'?[[27,'attack_b25',3]]:[[27,'attack_b25',3],[25,'attack_d4y',2],[26,'attack_g4m',3],[24,'attack_sb2c',3],[28,'intercept_g4m',4],[29,'intercept_b25',4]])){
  await phase(mode);await choose('segment',index);
  await wait(v=>window.S14X.latest.exercise===v&&window.S14X.latest.time_s>1,mode,25000);
  s=await snap();const generation=s.generation;
  check(s.models===count&&Object.keys(s.units).length===count,'Actual focused scenario model count '+mode);
  check(s.units.bomber.rack.remaining>0&&s.units.bomber.bombing.order_id,'Actual finite bombing task '+mode);
  check(s.orders.filter(o=>o.order_type==='bombing').every(o=>o.source==='ai'),'Initial bombing commands remain AI '+mode);
  check(!s.label.includes('单位已退出')&&!s.label.includes('待接入'),'Current actual task camera label '+mode);
  await shot(mode+'_inbound');
  if(mode==='attack_b25'){
   await focus();await key('Space');await wait(()=>window.S14X.latest.paused);
   const frozen=await snap();await sleep(600);s=await snap();
   check(s.tick===frozen.tick&&s.environment.time_s===frozen.environment.time_s,'Pause freezes authoritative flight, stores and environment');
   await choose('speed',2);await wait(()=>window.S14X.latest.speed===2);
   await focus();await key('Space');await wait(()=>!window.S14X.latest.paused);
   const before=await snap();await sleep(1000);s=await snap();
   check(s.time_s>before.time_s&&s.environment.time_s===s.time_s,'2x advances same flight/environment clock');
   await button('启用声音');await wait(()=>window.S14X.latest.sound_enabled);
   await button('恢复信息');await button('指挥态势');await wait(()=>window.S14X.latest.ui.expanded);
   s=await snap();check(s.orders.some(o=>o.faction_id==='jp')&&s.orders.some(o=>o.faction_id==='us'),'Both real commander order sets available');
   const orderButton=Object.keys(s.buttons).find(v=>v.startsWith('B-25J')&&v.includes('轰炸任务'));
   check(!!orderButton,'Normal visible bombing order row');await button(orderButton);await sleep(300);await shot('both_commanders_actual_execution');
   await button('指挥态势');await button('收起信息');await button('继续导览');await wait(()=>window.S14X.latest.guide_active);
  }
  await choose('speed',3);await wait(()=>window.S14X.latest.speed===4);
  if(mode==='attack_sb2c'){
   await wait(g=>window.S14X.data.events.some(e=>e.generation===g&&e.kind==='bombing_phase'&&e.data.phase==='pullout'&&e.data.reason==='too_low'),generation,65000);
   s=await snap();check(Object.values(s.units).filter(u=>u.rack.remaining>=0).every(u=>u.rack.released===0&&u.rack.remaining===1),'SB2C safety abort preserves both real bombs');await shot('sb2c_actual_safety_abort');
   await wait(g=>window.S14X.data.events.some(e=>e.generation===g&&e.kind==='unit_impact'&&e.entity_id==='bomber'),generation,140000);
   await shot('sb2c_actual_sea_contact');
  }else if(mode==='intercept_b25'){
   await wait(g=>window.S14X.data.events.some(e=>e.generation===g&&e.kind==='fired'&&e.entity_id==='fighter'),generation,65000);
   await shot('a6m_actual_interception');
   await wait(g=>window.S14X.data.events.some(e=>e.generation===g&&e.kind==='bombing_phase'&&e.data.phase==='pullout'&&['damage_abort','combat_damage_abort'].includes(e.data.reason)),generation,110000);
   await shot('b25_actual_intercept_abort');
  }else{
   await wait(g=>window.S14X.data.events.some(e=>e.generation===g&&e.kind==='bomb_released'),generation,100000);
   await shot(mode+'_actual_release');
   await wait(g=>window.S14X.data.events.some(e=>e.generation===g&&e.kind==='bomb_contact'),generation,90000);
   await shot(mode+'_actual_contact');
   if(mode==='intercept_g4m'){
    await wait(g=>window.S14X.data.events.some(e=>e.generation===g&&e.kind==='fired'&&e.entity_id==='fighter'),generation,90000);
    check(true,'F6F real fighter firing; G4M actual drops are retained');
   }
  }
  s=await snap();const events=await eventRows(s);
  check(events.some(e=>e.kind==='fired'&&e.entity_id==='target'),'Live target AA retained '+mode);
  if(mode.startsWith('intercept_')){
   check(events.some(e=>e.kind==='fired'&&e.entity_id==='fighter'),'Real interceptor weapon expenditure '+mode);
   check(s.orders.filter(o=>o.assigned_unit_ids.includes('fighter')).every(o=>!o.order_id.startsWith('bombing_commander_')&&o.source==='ai'),'Fighter remains assigned by original fleet commander '+mode);
  }
  if(mode==='attack_b25'&&Object.values(s.units).some(u=>u.damage.phase==='crashing'))check(s.operation_text.includes('受令单位已退出任务')&&!s.operation_text.includes('等待实际执行回报'),'Terminal reason displays actual recipient exit');
  check(!s.ended,'Scenario remains in ordinary ongoing view '+mode);
  cases.push({mode,generation,terminal:s,counts:Object.fromEntries(['bomb_released','bomb_contact','fired','damaged','damage_phase','unit_impact'].map(k=>[k,events.filter(e=>e.kind===k).length]))});
  if(mode==='attack_b25'){
   await focus();await key('KeyR');await wait(g=>window.S14X.latest.generation>g,generation);
   s=await snap();check(s.units.bomber.rack.released===0&&s.units.bomber.rack.remaining===6&&s.units.bomber.active,'R restores real bomber inventory and generation');
   check(s.orders.every(o=>o.source==='ai'),'R does not install human-source automatic orders');await shot('b25_restart');
  }
 }
 if(scope!=='b25-ui'){
 await phase('original_training');await choose('segment',8);await wait(()=>window.S14X.latest.exercise==='train_us_axial_roll');
 await wait(()=>window.S14X.latest.training.status==='completed',null,45000);s=await snap();
 check(s.models===19&&!s.operation_text_visible&&s.training.execution.status==='completed','Original19-unit actual training preserved');await shot('original_training');
 await phase('static_inspection');await choose('segment',23);await wait(()=>window.S14X.latest.exercise==='inspect_b25j');s=await snap();
 check(s.models===23&&s.static_models.includes('b25j')&&s.label.includes('轰炸任务另选'),'Static inspection remains separate from actual mission');await shot('static_b25');
 }
 await phase('between');audit.cases=cases;audit.data=await page.evaluate(()=>window.S14X.data);audit.frameSummary={};
 for(const name of new Set(audit.data.raf.map(v=>v.phase))){if(['between','loading'].includes(name))continue;const rows=audit.data.raf.filter(v=>v.phase===name),ms=rows.map(v=>v.ms).sort((a,b)=>a-b);audit.frameSummary[name]={frames:ms.length,p50Ms:ms[Math.floor(ms.length*.5)],p95Ms:ms[Math.min(ms.length-1,Math.floor(ms.length*.95))],allVisibleFocused:rows.every(v=>v.visible==='visible'&&v.focused),performanceAcceptance:false}}
 check(audit.pageErrors.length===0,'No browser runtime exception');check(!audit.console.some(v=>/SCRIPT ERROR|^\s*ERROR:|shader.*error|WebGL.*INVALID_/i.test(v.text)),'No Godot/shader/WebGL error');
 check(audit.data.snapshots.every(v=>!('journal'in v)&&!('orders'in v)),'Protocol2 snapshots do not repeat history or full orders');
 const eventKeys=audit.data.events.map(v=>v.generation+':'+v.sequence);check(new Set(eventKeys).size===eventKeys.length,'Event dedup by generation and sequence');audit.passed=true;

}catch(error){audit.passed=false;audit.failure=String(error?.stack||error);if(page){try{audit.last=await page.evaluate(()=>window.S14X?.latest);audit.data=await page.evaluate(()=>window.S14X?.data);await page.screenshot({path:path.join(out,'failure.png')})}catch{}}}
finally{
 if(statusInterval)clearInterval(statusInterval);
 if(context){try{await context.close();audit.cleanup.chromeClosed=true}catch(e){audit.cleanup.chromeError=String(e)}}
 if(server.listening)await new Promise(r=>server.close(r));audit.cleanup.serverClosed=true;await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profileRemoved=true;audit.endedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify({passed:audit.passed,checks:audit.checks.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode=audit.passed?0:1;
