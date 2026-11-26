// Actual UI acceptance only. Run via tools/verify.py; owns its Chrome/profile/server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const opt=(k,d)=>process.argv.find(v=>v.startsWith('--'+k+'='))?.slice(k.length+3)||d;
const out=path.resolve(root,opt('evidence','candidates/s14-bombing/ordinary-smoke-r13'));
const pack=path.resolve(root,opt('pack','build/first-playable'));
const scope=opt('scope','full');
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/s14-bomb-chrome-'));
const audit={startedUtc:new Date().toISOString(),browserPlugin:'Browser plugin not available',flow:'Ordinary expanded entry -> visible bomber menu -> actual B25 mission -> pause',scope:'Minimal bounded ordinary startup; no long/performance acceptance',viewport:{width:1280,height:720},checks:[],interactions:[],console:[],pageErrors:[],cleanup:{}};
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
 await page.addInitScript({path:path.join(root,'tools/s14_bombing/measure.js')});
 await page.goto(url,{waitUntil:'load',timeout:60000});await page.waitForFunction(()=>window.S14X?.latest?.models===23,null,{timeout:60000});
 audit.browserVersion=await context.browser()?.version();
 audit.identity=await page.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect(),g=c.getContext('webgl2'),e=g.getExtension('WEBGL_debug_renderer_info');return{url:location.href,title:document.title,ua:navigator.userAgent,canvas:{width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height},gpu:e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):null,webgl:g.getParameter(g.VERSION),dpr:devicePixelRatio}});
 check(audit.identity.url===url&&audit.identity.title.includes('海空交锋'),'Correct S14 page');check(audit.identity.canvas.width===1280&&audit.identity.canvas.height===720,'Real 1280x720 canvas');check(audit.identity.gpu&&!/swiftshader|software|llvmpipe/i.test(audit.identity.gpu),'Hardware WebGL');
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
 await sleep(400);let s=await snap();
 check(s.models===23&&s.popups.segment.count===30,'Ordinary expanded entry has23 units and30 visible choices');await shot('ordinary_expanded');
 await choose('segment',27);await wait(()=>window.S14X.latest.exercise==='attack_b25'&&window.S14X.latest.time_s>1,null,20000);
 s=await snap();check(s.models===3&&s.units.bomber.rack.remaining===6&&s.units.wing.rack.remaining===6,'Normal menu starts actual B25 flight with finite stores');
 check(s.orders.some(o=>o.order_type==='bombing'&&o.source==='ai'),'Actual AI bombing order dispatched from ordinary entry');await shot('ordinary_b25');
 await button('暂停');await wait(()=>window.S14X.latest.paused);const frozen=await snap();await sleep(400);s=await snap();check(s.tick===frozen.tick,'Ordinary pause responds');
 check(audit.pageErrors.length===0&&!audit.console.some(v=>/SCRIPT ERROR|^\s*ERROR:|WebGL.*INVALID_/i.test(v.text)),'No startup script or browser error');
 audit.last=s;audit.data=await page.evaluate(()=>window.S14X.data);audit.passed=true;

}catch(error){audit.passed=false;audit.failure=String(error?.stack||error);if(page){try{audit.last=await page.evaluate(()=>window.S14X?.latest);audit.data=await page.evaluate(()=>window.S14X?.data);await page.screenshot({path:path.join(out,'failure.png')})}catch{}}}
finally{
 if(statusInterval)clearInterval(statusInterval);
 if(context){try{await context.close();audit.cleanup.chromeClosed=true}catch(e){audit.cleanup.chromeError=String(e)}}
 if(server.listening)await new Promise(r=>server.close(r));audit.cleanup.serverClosed=true;await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profileRemoved=true;audit.endedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify({passed:audit.passed,checks:audit.checks.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode=audit.passed?0:1;
