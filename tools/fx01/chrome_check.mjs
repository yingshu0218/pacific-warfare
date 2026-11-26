// Only run via tools/verify.py exec. Private Chrome/profile/server; no user tabs touched.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const pack=path.join(root,'build/fx01-web');
const out=path.join(root,'docs/showcase/evidence/FX01/chrome');
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/fx01-chrome-'));
const audit={browserPlugin:'Browser plugin not available',viewport:{width:1280,height:720},checks:[],interactions:[],console:[],pageErrors:[],measurements:[],cleanup:{},startedUtc:new Date().toISOString(),scope:'One bounded Chrome incremental/visual check, frozen S10/S13 plus FX01; controlled probes labelled separately from natural production battle'};
let context,page,id=0;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const check=(ok,name,detail=null)=>{audit.checks.push({passed:ok,name,detail});if(!ok)throw Error(name);};
const quantile=(v,q)=>{if(!v.length)return null;const a=[...v].sort((a,b)=>a-b),x=(a.length-1)*q;return a[Math.floor(x)]+(a[Math.ceil(x)]-a[Math.floor(x)])*(x%1);};
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server=http.createServer(async(req,res)=>{try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(name==='/favicon.ico'){res.writeHead(204);res.end();return;}const p=path.resolve(pack,'.'+name);if(!p.startsWith(pack+'/'))throw Error('outside pack');const bytes=await fs.readFile(p);res.writeHead(200,{'Content-Type':mime[path.extname(p)]||'application/octet-stream','Cache-Control':'no-store'});res.end(bytes);}catch{res.writeHead(404);res.end('not found');}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
audit.url='http://127.0.0.1:'+server.address().port+'/index.html';
try{
 const manifest=JSON.parse(await fs.readFile(path.join(pack,'build_manifest.json'),'utf8'));
 const runtimeFixture='tests/fixtures/fx01_runtime_fixture.gd';
 check(manifest.sources[runtimeFixture]===createHash('sha256').update(await fs.readFile(path.join(root,runtimeFixture))).digest('hex'),'fresh release-safe fixture in exported pack');
 check(manifest.outputs['index.pck'].sha256===createHash('sha256').update(await fs.readFile(path.join(pack,'index.pck'))).digest('hex'),'exported pack matches recorded hash');
 audit.packManifest=manifest;
 audit.hardware={cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),os:os.release()};
 context=await chromium.launchPersistentContext(profile,{executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,viewport:{width:1280,height:720},deviceScaleFactor:1,args:['--window-position=-1600,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 audit.flags=['private profile','offscreen headful window','background/occlusion throttling disabled equally in all samples'];
 page=context.pages()[0]||await context.newPage();
 audit.allConsole=[];
 page.on('console',m=>{const item={type:m.type(),text:m.text()};audit.allConsole.push(item);if(['error','warning'].includes(m.type())||/SCRIPT ERROR|Parse Error|^\s*ERROR:|shader compilation|WebGL.*INVALID_/i.test(item.text))audit.console.push(item);});
 page.on('pageerror',e=>audit.pageErrors.push(String(e)));
 await page.goto(audit.url,{waitUntil:'load',timeout:60000});
 await page.waitForFunction(()=>window.FX01?.latest?.game_children>0,null,{timeout:60000});
 audit.version=await context.browser().version();
 audit.identity=await page.evaluate(()=>{const c=document.querySelector('canvas'),gl=c.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info'),r=c.getBoundingClientRect();return{title:document.title,url:location.href,canvas:{width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height},gpu:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,visible:document.visibilityState,focused:document.hasFocus()};});
 check(audit.identity.url===audit.url&&audit.identity.title.includes('FX01'),'page identity');
 check(audit.identity.canvas.width===1280&&audit.identity.canvas.height===720&&audit.identity.canvas.cssWidth===1280&&audit.identity.canvas.cssHeight===720,'1280x720 drawing buffer and CSS viewport');
 check(!/swiftshader|llvmpipe|software/i.test(audit.identity.gpu||'software'),'hardware WebGL');
 await page.screenshot({path:path.join(out,'production_normal_ui.png')});
 const snap=()=>page.evaluate(()=>FX01.latest);
 const command=async(kind,value)=>{const next=++id;await page.evaluate(c=>FX01.commands.push(c),{kind,value,id:next});await page.waitForFunction(v=>FX01.latest.command_id>=v,next,{timeout:10000});return snap();};
 const sample=async(label,seconds)=>{await page.evaluate(()=>FX01.phase('warmup'));await sleep(700);await page.evaluate(label=>FX01.phase(label),label);const begin=await snap();await sleep(seconds*1000);const end=await snap();audit.measurements.push({label,seconds,begin,end});await page.evaluate(()=>FX01.phase('between'));console.log('FX01 measured',label,seconds);};
 await sample('production_live',8);
 await page.keyboard.press('KeyH'); // Normal cinematic UI control.
 await command('case','water');
 await command('enabled',false);
 await sleep(500);
 check((await snap()).event_counts.surface_impact===2,'disabled FX still receives two real sea impacts');
 await sample('water_effects_disabled',8);
 await command('enabled',true);
 await command('case','water');
 await sleep(900);
 check((await snap()).event_counts.surface_impact===2&&(await snap()).effects.active>0,'enabled water has actual impacts and rendered instances');
 await page.screenshot({path:path.join(out,'water.png')});
 await sample('water_effects_enabled',8);
 await command('case','flak');
 await sleep(1000);
 check((await snap()).event_counts.airburst===4&&(await snap()).effects.active>0,'real time fuzes plus fixed self-destruct visible in browser');
 await page.screenshot({path:path.join(out,'flak.png')});
 await sample('flak_controlled',8);
 await command('case','tracer');
 await sleep(700);
 check((await snap()).event_counts.fired>20&&(await snap()).effects.active>0,'actual sampled projectile tracers visible in browser');
 await page.screenshot({path:path.join(out,'tracer.png')});
 await sample('tracer_controlled',4);
 await command('case','smoke');
 await sleep(2700);
 check((await snap()).event_counts.damaged>0&&(await snap()).effects.active>0,'smoke driven by actual engine hit damage');
 await page.screenshot({path:path.join(out,'smoke_150mps.png')});
 await sample('smoke_controlled',5);
 await page.keyboard.press('Space');
 await page.waitForFunction(()=>FX01.latest.paused);
 await sleep(500);
 const paused=await snap();
 await page.mouse.move(1,1);
 const first=await page.screenshot({path:path.join(out,'paused_smoke.png')});
 await sleep(700);
 const second=await page.screenshot();
 const still=await snap();
 check(paused.demo_tick===still.demo_tick&&paused.environment.time_s===still.environment.time_s,'Space freezes real clock and effects');
 check(createHash('sha256').update(first).digest('hex')===createHash('sha256').update(second).digest('hex'),'paused frame pixels identical');
 audit.interactions.push({action:'Actual Space pause',before:paused,after:still});
 // Production menu receives actual clicks, not a direct time_scale assignment.
 await page.keyboard.press('KeyH');
 await sleep(300);
 const controls=await snap();await page.mouse.click(...controls.speed_control);
 await page.waitForFunction(()=>FX01.latest.speed_popup.visible);
 const menu=(await snap()).speed_popup;
 await page.mouse.click(menu.position[0]+menu.size[0]*.5,menu.position[1]+menu.size[1]*.875);
 await page.waitForFunction(()=>FX01.latest.speed===4);
 await page.keyboard.press('Space');
 await page.waitForFunction(()=>!FX01.latest.paused);
 await sleep(350);
 const resumed=await snap();
 check(resumed.speed===4&&resumed.demo_tick!==still.demo_tick,'Actual 4x dropdown and Space resume advance effects');
 audit.interactions.push({action:'Actual speed popup selects 4x then Space resume',after:resumed});
 // Reset in a repeatable water scene; pools are already warmed to full capacity.
 await command('case','water');
 const restarts=[];
 for(let n=0;n<3;n++){
  const before=await snap();await page.keyboard.press('KeyR');
  await page.waitForFunction(g=>FX01.latest.generation>g,before.generation);
  const after=await snap();restarts.push(after);
  check(after.demo_age_s<1&&after.effects.render_instances<=144,'Actual restart resets FX state within same pool '+n);
 }
 check(new Set(restarts.map(v=>v.effects.render_instances)).size===1,'three restarts retain actual mesh allocation');
 audit.interactions.push({action:'Three actual R restarts',snapshots:restarts});
 audit.data=await page.evaluate(()=>FX01.data);
 audit.summary=[];
 for(const item of audit.measurements){
  const frames=audit.data.raf.filter(x=>x.phase===item.label),values=frames.map(x=>x.ms),snaps=audit.data.snapshots.filter(x=>x.phase===item.label);
  const total=values.reduce((a,b)=>a+b,0);
  audit.summary.push({label:item.label,samples:values.length,p50_ms:quantile(values,.5),p95_ms:quantile(values,.95),p99_ms:quantile(values,.99),mean_fps:1000*values.length/total,all_visible_focused:frames.every(x=>x.visible==='visible'&&x.focused),max_visible_instances:Math.max(...snaps.map(x=>x.effects.visible_instances)),max_allocated_instances:Math.max(...snaps.map(x=>x.effects.render_instances)),draw_calls_p50:quantile(snaps.map(x=>x.draw_calls),.5),draw_calls_max:Math.max(...snaps.map(x=>x.draw_calls)),dropped_max:Math.max(...snaps.map(x=>x.effects.dropped)),preempted_max:Math.max(...snaps.map(x=>x.effects.preempted))});
 }
 check(audit.summary.every(x=>x.max_allocated_instances<=(x.label==='production_live'?384:144)),'actual rendering cap in every browser phase (existing production 384, isolated demo 144)');
 check(audit.summary.every(x=>x.all_visible_focused),'all performance samples visible/focused');
 check(audit.summary.every(x=>x.p95_ms<=33.3),'bounded incremental p95 within 33.3ms');
 check(audit.console.length===0&&audit.pageErrors.length===0,'no console warning/error or page errors');
 audit.passed=true;
}catch(error){audit.passed=false;audit.failure=String(error.stack||error);if(page){try{audit.data=await page.evaluate(()=>window.FX01?.data);await page.screenshot({path:path.join(out,'failure.png')});}catch{}}}
finally{
 if(context){try{await context.close();audit.cleanup.chromeClosed=true;}catch(e){audit.cleanup.chromeError=String(e);}}
 await new Promise(r=>server.close(r));audit.cleanup.serverClosed=true;
 await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profileRemoved=true;
 audit.endedUtc=new Date().toISOString();
 await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));
 console.log(JSON.stringify({passed:audit.passed,checks:audit.checks.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode=audit.passed?0:1;
