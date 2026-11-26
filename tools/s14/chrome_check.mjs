// Actual UI acceptance only. Run via tools/verify.py; owns its Chrome/profile/server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const selectionsOnly=process.argv.includes('--selections-only');
const opt=(k,d)=>process.argv.find(v=>v.startsWith('--'+k+'='))?.slice(k.length+3)||d;
const out=path.resolve(root,opt('evidence','docs/showcase/evidence/S14/final/chrome'));
const pack=path.resolve(root,opt('pack','build/s14-final-web'));
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/s14-chrome-'));
const audit={startedUtc:new Date().toISOString(),browserPlugin:'Browser plugin not available',flow:'S14 baseline loads -> real menus select units, weapons and training -> actual execution/controls and readable final result',scope:'Bounded S14 basic integration; no ten-minute, three-restart or 4x performance acceptance',viewport:{width:1280,height:720},checks:[],interactions:[],console:[],pageErrors:[],cleanup:{}};
let context,page;
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
 await page.goto(url,{waitUntil:'load',timeout:60000});await page.waitForFunction(()=>window.S14?.latest?.models===19,null,{timeout:60000});
 audit.browserVersion=await context.browser()?.version();
 audit.identity=await page.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect(),g=c.getContext('webgl2'),e=g.getExtension('WEBGL_debug_renderer_info');return{url:location.href,title:document.title,ua:navigator.userAgent,canvas:{width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height},gpu:e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):null,webgl:g.getParameter(g.VERSION),dpr:devicePixelRatio}});
 check(audit.identity.url===url&&audit.identity.title.includes('S14'),'Correct S14 page');check(audit.identity.canvas.width===1280&&audit.identity.canvas.height===720,'Real 1280x720 canvas');check(audit.identity.gpu&&!/swiftshader|software|llvmpipe/i.test(audit.identity.gpu),'Hardware WebGL');
 const snap=()=>page.evaluate(()=>window.S14.latest);
 const wait=(fn,arg=null,timeout=20000)=>page.waitForFunction(fn,arg,{timeout});
 const phase=async name=>{await page.evaluate(v=>window.S14.phase(v),name);await fs.writeFile(path.join(out,'progress.json'),JSON.stringify({phase:name,time:new Date().toISOString(),checks:audit.checks.length}));console.log('S14 Chrome '+name)};
 const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
 const gameClick=async point=>{const r=await page.locator('canvas').boundingBox();audit.interactions.push({action:'click',canvas:point,wallUtc:new Date().toISOString()});await page.mouse.click(r.x+point[0]*r.width/1280,r.y+point[1]*r.height/720)};
 const key=async value=>{audit.interactions.push({action:'key',key:value,wallUtc:new Date().toISOString()});await page.keyboard.press(value)};
 const focus=()=>gameClick([940,580]);
 const choose=async(key,index)=>{
  let s=await snap();await gameClick(s.controls[key]);await wait(k=>window.S14.latest.popups[k].visible,key);
  s=await snap();const p=s.popups[key];check(index>=0&&index<p.count,'Menu item exists '+key+'/'+index);
  await gameClick([p.position[0]+p.size[0]*.5,p.position[1]+p.size[1]*(index+.5)/p.count]);
  await wait(k=>!window.S14.latest.popups[k].visible,key);
 };
 const button=async label=>{const s=await snap();check(!!s.buttons[label],'Visible button '+label);await gameClick(s.buttons[label])};
 await sleep(700);let s=await snap();check(s.models===19&&Object.keys(s.units).length===19&&s.orders.length>0,'Nonblank 19-unit baseline and real orders');check(s.modes.length===16,'Both aircraft have five selectable training entries');check(!Object.values(s.units).some(u=>/essex|cv9/i.test(u.definition_id)),'Unadmitted CV01 excluded');await shot('normal_ui');
 if(!selectionsOnly){
 await phase('normal_1x');await sleep(5000);await phase('controls');
 await button('恢复信息');await wait(()=>!window.S14.latest.ui.cinema);await button('指挥态势');await wait(()=>window.S14.latest.ui.expanded&&window.S14.latest.ui.both_cards&&window.S14.latest.ui.timeline);await shot('real_orders');await button('指挥态势');await button('收起信息');
 await focus();await key('Space');await wait(()=>window.S14.latest.paused);const paused=await snap();await sleep(650);const frozen=await snap();check(paused.tick===frozen.tick&&paused.environment.time_s===frozen.environment.time_s,'Space freezes simulation and environment');
 await choose('speed',2);await wait(()=>window.S14.latest.speed===2);await focus();await key('Space');await wait(()=>!window.S14.latest.paused);const speedStart=await snap(),wallStart=Date.now();await sleep(650);s=await snap();check(s.time_s>speedStart.time_s&&s.speed===2&&s.environment.time_s===s.time_s,'2x setting advances one authoritative clock');audit.speedObservation={requested:2,achieved:(s.time_s-speedStart.time_s)/((Date.now()-wallStart)/1000),pending:s.pending_s};
 await focus();const oldGen=(await snap()).generation;await key('KeyR');await wait(g=>window.S14.latest.generation>g,oldGen);s=await snap();check(s.models===19&&s.global_fragments===0&&s.speed===1,'R resets 19-unit scene and visual state');
 }
 await phase('unit_selection');
 for(const id of ['jp_bb','us_bb','jp_dd','us_dd','us_pair_demo_1','jp_air_1','us_sb2c_1','us_coast_01','us_aa_01']){
  const before=await snap();const index=before.popups.unit.metadata.indexOf(id);await choose('unit',index);await button('跟随');await wait(v=>window.S14.latest.followed_id===v&&window.S14.latest.camera_mode==='follow',id);await sleep(150);audit.interactions.push({action:'unit_follow',id,state:await snap()});await shot('unit_'+id);
 }
 await phase('weapon_selection');
 for(let index=1;index<=5;index++){const generation=(await snap()).generation;await choose('weapon',index);await wait(v=>window.S14.latest.gallery_index===v&&window.S14.latest.guide.section==='gallery',index-1);check((await snap()).generation===generation,'Weapon inspection keeps current generation '+index);await sleep(120);await shot('weapon_'+index);}
 await phase('training');
 for(const faction of ['us','jp']){
  for(const kind of ['bank_turn','climb_dive','axial_roll','roll_reversal','split_s']){
   const mode='train_'+faction+'_'+kind;const before=await snap();await choose('segment',before.modes.indexOf(mode));await wait(v=>window.S14.latest.exercise===v,mode);
   const readableName={bank_turn:'大坡度转弯',climb_dive:'爬升与俯冲',axial_roll:'完整轴向滚转',roll_reversal:'反向滚转转弯',split_s:'半滚倒转'}[kind];
   await wait(({mode,readableName})=>{const v=window.S14.latest;return v.exercise===mode&&v.training?.training?.order_id===v.mission.training_order_id&&v.training.training.phase&&['executing','completed'].includes(v.training.status)&&v.label.includes(readableName)&&!v.label.includes('等待实际接收')},{mode,readableName});
   s=await snap();check(s.label.includes(readableName)&&!s.label.includes('等待实际接收')&&!s.label.includes('[object')&&s.training.training.order_id===s.mission.training_order_id,'Actual per-unit training and visible label start '+mode);
   if(['axial_roll','split_s'].includes(kind)){
    await phase(mode);await wait(readableName=>{const v=window.S14.latest;return v.training.status==='completed'&&v.label.includes('已完成')&&v.label.includes(readableName)},readableName,50000);s=await snap();check(s.training.execution.status==='completed'&&s.training.training.status==='completed'&&s.training.training.order_id===s.mission.training_order_id&&s.label.includes('已完成')&&s.label.includes(readableName),'Matched actual training completion and visible result '+mode);
    if(kind==='axial_roll')check(s.training.training.peak_roll_rad>=Math.PI*2,'Full measured axial roll '+faction);
    check(s.projected[s.mission.training_subject]&&Math.abs(s.projected[s.mission.training_subject][0]-640)<3&&Math.abs(s.projected[s.mission.training_subject][1]-360)<3,'Training subject visible at center '+mode);
    check(!s.tooltip.includes('order_id')&&!s.tooltip.includes('peak_roll_rad')&&!s.tooltip.includes(s.mission.training_order_id),'Normal tooltip contains readable result only '+mode);
    await shot(mode+'_completed');
   }else{await shot(mode+'_started')}
   audit.interactions.push({action:'training_ui',mode,extent:['axial_roll','split_s'].includes(kind)?'completed':'actual_start',state:await snap()});
  }
 }
 await phase('cycle_views');
 let before=await snap();await choose('segment',before.modes.indexOf('escort'));await wait(()=>window.S14.latest.exercise==='escort'&&window.S14.latest.time_s>2);await shot('escort_sb2c_close');await wait(()=>window.S14.latest.time_s>11);await shot('escort_pair_close');
 check((await snap()).guide.ids.length<=2,'Escort alternates a readable close view');
 before=await snap();await choose('segment',before.modes.indexOf('four'));await wait(()=>window.S14.latest.exercise==='four'&&window.S14.latest.time_s>6);await shot('four_pair_close');
 await phase('between');audit.data=await page.evaluate(()=>window.S14.data);
 const summary={};for(const name of new Set(audit.data.raf.map(v=>v.phase))){if(['between','loading'].includes(name))continue;const rows=audit.data.raf.filter(v=>v.phase===name);const ms=rows.map(v=>v.ms).sort((a,b)=>a-b);summary[name]={frames:ms.length,p50Ms:ms[Math.floor(ms.length*.5)],p95Ms:ms[Math.min(ms.length-1,Math.floor(ms.length*.95))],p99Ms:ms[Math.min(ms.length-1,Math.floor(ms.length*.99))],allVisibleFocused:rows.every(v=>v.visible==='visible'&&v.focused)}}audit.frameSummary=summary;
 check(audit.pageErrors.length===0,'No browser runtime errors');check(!audit.console.some(v=>/SCRIPT ERROR|^\s*ERROR:|shader.*error|WebGL.*INVALID_/i.test(v.text)),'No Godot/shader/WebGL errors');check(audit.data.events.some(e=>e.kind==='order_issued')&&audit.data.events.some(e=>e.kind==='fired'),'Actual command and combat events captured');
 audit.selectionsOnly=selectionsOnly;audit.passed=true;
}catch(error){audit.passed=false;audit.failure=String(error?.stack||error);if(page){try{audit.last=await page.evaluate(()=>window.S14?.latest);audit.data=await page.evaluate(()=>window.S14?.data);await page.screenshot({path:path.join(out,'failure.png')})}catch{}}}
finally{
 if(context){try{await context.close();audit.cleanup.chromeClosed=true}catch(e){audit.cleanup.chromeError=String(e)}}
 if(server.listening)await new Promise(r=>server.close(r));audit.cleanup.serverClosed=true;await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profileRemoved=true;audit.endedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify({passed:audit.passed,checks:audit.checks.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode=audit.passed?0:1;
