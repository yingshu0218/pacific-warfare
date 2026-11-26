// Actual UI acceptance only. Run via tools/verify.py; owns its Chrome/profile/server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const opt=(k,d)=>process.argv.find(v=>v.startsWith('--'+k+'='))?.slice(k.length+3)||d;
const out=path.resolve(root,opt('evidence','candidates/s14-expansion/chrome-review-r1'));
const pack=path.resolve(root,opt('pack','build/s14-expansion-review-r2'));
const scope=opt('scope','full');
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/s14-exp-chrome-'));
const audit={startedUtc:new Date().toISOString(),browserPlugin:'Browser plugin not available',flow:'Normal candidate loads -> visible B-25/D4Y/G4M menu entries -> actual carriers -> original training -> actual deck order/launch/recall'+(scope==='full'?' and hook':''),scope:scope==='full'?'Bounded integration including actual wire; no long/performance acceptance':'Basic integration including launch and legal recall; wire recovery/long cycles remain separate',viewport:{width:1280,height:720},checks:[],interactions:[],console:[],pageErrors:[],cleanup:{}};
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
  if(key==='segment'&&index===23)await shot('b25_visible_menu');
  audit.interactions.push({action:'menu_scroll',menu:key,index,measured:p,scroll,bottom,wallUtc:new Date().toISOString()});
  await gameClick([p.position[0]+p.size[0]*.5,y]);
  await wait(k=>!window.S14X.latest.popups[k].visible,key);
 };
 const button=async label=>{const s=await snap();check(!!s.buttons[label],'Visible button '+label);await gameClick(s.buttons[label])};
 await sleep(500);let s=await snap();check(s.models===23&&s.static_models.includes('b25j')&&s.static_models.includes('g4m1')&&s.static_models.includes('d4y2'),'Normal expanded page has23 units and3 actual static aircraft');
 check(s.popups.segment.count===24&&s.popups.segment.labels[23].includes('B-25'),'B-25 discoverable in normal scene menu');await shot('normal_harbor');
 await phase('harbor_1x');await sleep(5000);
 await phase('new_models');
 for(const [index,id]of [[23,'b25j'],[22,'g4m1'],[21,'d4y2']]){
  await choose('segment',index);await wait(v=>window.S14X.latest.exercise==='inspect_'+v&&window.S14X.latest.label.includes('模型展示')&&window.S14X.latest.label.includes('飞行与轰炸待接入'),id);
  await sleep(500);s=await snap();check(s.static_models.includes(id)&&s.operation_text.includes('静态安装已完成'),'Actual static installation and visible capability boundary '+id);
  check(s.guide_active&&s.camera_distance_m>25&&s.camera_distance_m<60,'Menu scrolling preserves static model guide and camera '+id);
  await shot(id);audit.interactions.push({action:'static_model',id,state:{exercise:s.exercise,generation:s.generation,label:s.label,static_models:s.static_models,camera_distance_m:s.camera_distance_m,guide_active:s.guide_active}});
 }
 await phase('carrier_gunnery');await choose('segment',17);await wait(()=>window.S14X.latest.exercise==='carrier_gunnery');
 for(const id of ['us_cv','jp_cv']){
  s=await snap();await choose('unit',s.popups.unit.metadata.indexOf(id));await button('跟随');await wait(v=>window.S14X.latest.followed_id===v&&window.S14X.latest.camera_mode==='follow',id);await sleep(250);await shot(id);
 }
 await wait(()=>['us_cv','jp_cv'].every(id=>window.S14X.data.events.some(e=>e.exercise==='carrier_gunnery'&&e.kind==='fired'&&e.entity_id===id)),null,35000);
 check(true,'Both carriers fire actual combat events');
 await button('恢复信息');await button('指挥态势');await wait(()=>window.S14X.latest.ui.expanded);await shot('real_commander_orders');await button('指挥态势');await button('收起信息');
 await phase('original_training');
 for(const [index,mode]of [[8,'train_us_axial_roll'],[15,'train_jp_split_s']]){
  await choose('segment',index);await wait(v=>window.S14X.latest.exercise===v,mode);await wait(()=>window.S14X.latest.training.status==='completed'&&window.S14X.latest.label.includes('已完成'),null,40000);
  s=await snap();check(s.models===19&&Object.keys(s.units).length===19&&!s.operation_text_visible,'Original19-unit training renders and hides OPS controls '+mode);
  check(s.training.execution.status==='completed'&&s.training.training.status==='completed','Original actual training completion preserved '+mode);await shot(mode);
 }
 await phase('partial_wave');await choose('segment',20);await wait(()=>window.S14X.latest.exercise==='carrier_partial'&&window.S14X.latest.operation_text.includes('指令已拒绝'));
 s=await snap();check(s.orders.some(o=>o.status==='failed'&&o.reason==='carrier_complete_wave_required'),'Partial wave rejected at normal task dispatch');check(['us_deck_1','us_deck_2'].every(id=>s.units[id].carrier_ops.on_deck&&s.units[id].carrier_ops.sorties===0),'Both actual deck aircraft remain parked after rejected order');await shot('partial_wave_rejected');
 await phase('deck_single');await choose('segment',18);await wait(()=>window.S14X.latest.exercise==='carrier_single'&&window.S14X.latest.time_s>1);
 await focus();await key('Space');await wait(()=>window.S14X.latest.paused);const frozen=await snap();await sleep(600);s=await snap();check(s.tick===frozen.tick&&s.environment.time_s===frozen.environment.time_s,'Space pauses OPS and environment together');
 await choose('speed',2);await wait(()=>window.S14X.latest.speed===2);await focus();await key('Space');await wait(()=>!window.S14X.latest.paused);const t0=await snap(),w0=Date.now();await sleep(1100);s=await snap();audit.twoX={requested:2,achieved:(s.time_s-t0.time_s)/((Date.now()-w0)/1000),pending_s:s.pending_s};check(s.time_s>t0.time_s&&s.environment.time_s===s.time_s,'2x setting advances authoritative OPS/environment clock');
 await button('启用声音');await wait(()=>window.S14X.latest.sound_enabled);check(true,'Existing sound enabled by user gesture');
 await wait(()=>window.S14X.latest.units.us_deck_1.carrier_ops.sorties>=1&&!window.S14X.latest.units.us_deck_1.carrier_ops.on_deck,null,45000);await shot('actual_leave_deck');
 await choose('carrier',2);await wait(()=>window.S14X.latest.orders.some(o=>o.intent==='carrier_wave_recall'&&o.status!=='failed'));
 check(true,'Visible high-level recall reaches same command interface');
 if(scope==='full'){
 await choose('speed',3);await wait(()=>window.S14X.latest.speed===4);const fastStart=await snap(),fastWall=Date.now();
 await phase('actual_recovery');await wait(()=>window.S14X.data.events.some(e=>e.exercise==='carrier_single'&&e.kind==='carrier_wire_caught'),null,180000);
 s=await snap();audit.fourX={requested:4,achieved:(s.time_s-fastStart.time_s)/((Date.now()-fastWall)/1000),pending_s:s.pending_s,visual_performance_accepted:false};
 check(s.units.us_deck_1.carrier_ops.recoveries>=0&&s.units.us_deck_1.active,'Actual wire event without losing aircraft');await shot('actual_wire_caught');
 await choose('speed',1);await wait(()=>window.S14X.latest.speed===1);await wait(()=>['taxi_clear','servicing','standby'].includes(window.S14X.latest.units.us_deck_1.carrier_ops.phase),null,15000);await shot('actual_clear_or_service');
 }else{
 await wait(()=>['return','holding','approach','go_around'].includes(window.S14X.latest.units.us_deck_1.carrier_ops.phase));await shot('actual_recall_executing');
 await choose('speed',1);await wait(()=>window.S14X.latest.speed===1);
 }
 const oldGen=(await snap()).generation;await focus();await key('KeyR');await wait(g=>window.S14X.latest.generation>g,oldGen);s=await snap();check(s.models===22&&s.units.us_deck_1.carrier_ops.recoveries===0&&s.speed===1,'R restarts OPS inventory, generation and controls');await shot('restart');
 await phase('between');audit.data=await page.evaluate(()=>window.S14X.data);audit.frameSummary={};
 for(const name of new Set(audit.data.raf.map(v=>v.phase))){if(['between','loading'].includes(name))continue;const rows=audit.data.raf.filter(v=>v.phase===name),ms=rows.map(v=>v.ms).sort((a,b)=>a-b);audit.frameSummary[name]={frames:ms.length,p50Ms:ms[Math.floor(ms.length*.5)],p95Ms:ms[Math.min(ms.length-1,Math.floor(ms.length*.95))],allVisibleFocused:rows.every(v=>v.visible==='visible'&&v.focused)}}
 check(audit.pageErrors.length===0,'No browser runtime exception');check(!audit.console.some(v=>/SCRIPT ERROR|^\s*ERROR:|shader.*error|WebGL.*INVALID_/i.test(v.text)),'No Godot/shader/WebGL error');audit.passed=true;
}catch(error){audit.passed=false;audit.failure=String(error?.stack||error);if(page){try{audit.last=await page.evaluate(()=>window.S14X?.latest);audit.data=await page.evaluate(()=>window.S14X?.data);await page.screenshot({path:path.join(out,'failure.png')})}catch{}}}
finally{
 if(statusInterval)clearInterval(statusInterval);
 if(context){try{await context.close();audit.cleanup.chromeClosed=true}catch(e){audit.cleanup.chromeError=String(e)}}
 if(server.listening)await new Promise(r=>server.close(r));audit.cleanup.serverClosed=true;await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profileRemoved=true;audit.endedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify({passed:audit.passed,checks:audit.checks.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode=audit.passed?0:1;
