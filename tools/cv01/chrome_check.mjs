// Run only via tools/verify.py exec. Owns a private Chrome profile and temporary HTTP server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const pack=path.join(root,'build/cv01-web'),out=path.join(root,'docs/showcase/evidence/CV01/chrome');
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/cv01-chrome-'));
const audit={scope:'Isolated CV01 model and static deck fit; not fleet/aviation operations',browserPlugin:'Browser plugin is not available; existing local Playwright workflow used',viewport:{width:1440,height:900},deviceScaleFactor:1,checks:[],views:[],console:[],pageErrors:[],cleanup:{},startedUtc:new Date().toISOString()};
let context,page,failed=false;
const check=(passed,name,detail=null)=>{audit.checks.push({passed,name,detail});if(!passed)throw Error(name);};
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server=http.createServer(async(req,res)=>{try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(name==='/favicon.ico'){res.writeHead(204);res.end();return;}const target=path.resolve(pack,'.'+name);if(!target.startsWith(pack+'/'))throw Error('outside pack');const data=await fs.readFile(target);res.writeHead(200,{'Content-Type':mime[path.extname(target)]||'application/octet-stream','Cache-Control':'no-store'});res.end(data);}catch{res.writeHead(404);res.end('not found');}});
try{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 audit.url='http://127.0.0.1:'+server.address().port+'/index.html';
 audit.hardware={cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),os:os.release()};
 context=await chromium.launchPersistentContext(profile,{executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,viewport:audit.viewport,deviceScaleFactor:1,args:['--window-position=-1900,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 audit.launch='Private offscreen headful Chrome, hardware WebGL; no existing window accessed';
 audit.browserVersion=await context.browser()?.version();
 page=context.pages()[0]||await context.newPage();
 page.on('console',m=>{if(['error','warning'].includes(m.type()))audit.console.push({type:m.type(),text:m.text()});});page.on('pageerror',e=>audit.pageErrors.push(String(e)));
 await page.goto(audit.url,{waitUntil:'load',timeout:60000});
 await page.waitForFunction(()=>window.CV01?.latest?.sockets===25,null,{timeout:60000});
 audit.identity=await page.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect(),gl=c.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return{title:document.title,url:location.href,canvas:[c.width,c.height,r.width,r.height],gpu:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,status:document.querySelector('#status')?.textContent||''};});
 check(audit.identity.title==='CV01 USS Essex · isolated inspection','dedicated project identity');
 check(audit.identity.canvas.every((v,i)=>v===[1440,900,1440,900][i]),'render buffer, viewport and DPR');
 check(audit.identity.gpu&&!/swiftshader|llvmpipe|software/i.test(audit.identity.gpu),'hardware WebGL');
 await page.locator('canvas').focus();await page.keyboard.press('ArrowRight');await page.waitForFunction(()=>window.CV01.latest.index===6);await page.keyboard.press('ArrowLeft');await page.waitForFunction(()=>window.CV01.latest.index===5);check(true,'keyboard camera controls actual model view');
 const labels=['mk32_module','mk24_module','port_side','starboard_side','top','bow_quarter','stern_quarter','forward_battery','aft_battery','deck_installation','sb2c_installation','sb2c_low_side','elevator_lowered'];
 for(let i=0;i<labels.length;i++){
  await page.evaluate(c=>window.CV01.commands.push(c),{id:i+1,kind:'view',value:i});await page.waitForFunction(id=>window.CV01.latest.command_id>=id,i+1);await page.waitForTimeout(200);
  const state=await page.evaluate(()=>window.CV01.latest);check(state.view===labels[i]&&state.model_id==='us_essex_cv9_1944_04_15'&&state.sockets===25,'model and camera '+labels[i]);
  const file=path.join(out,labels[i]+'.png'),bytes=await page.screenshot({path:file});check(bytes.length>10000,'rendered '+labels[i]);audit.views.push({id:labels[i],file,state,bytes:bytes.length});
 }
 await page.evaluate(()=>window.CV01.commands.push({id:100,kind:'view',value:5}));await page.waitForFunction(()=>window.CV01.latest.command_id===100);await page.waitForTimeout(500);
 audit.cadence=await page.evaluate(()=>new Promise(resolve=>{const samples=[],start=performance.now();let prev;const frame=now=>{if(prev!==undefined)samples.push(now-prev);prev=now;if(now-start<6000){requestAnimationFrame(frame);return;}const sorted=[...samples].sort((a,b)=>a-b),sum=samples.reduce((a,b)=>a+b,0);resolve({durationMs:now-start,frames:samples.length,meanMs:sum/samples.length,p50Ms:sorted[Math.floor(sorted.length*.5)],p95Ms:sorted[Math.floor(sorted.length*.95)],p99Ms:sorted[Math.floor(sorted.length*.99)],estimatedFps:samples.length*1000/sum,engineFrames:window.CV01.latest.frames,drawCalls:window.CV01.latest.draw_calls,primitives:window.CV01.latest.primitives});};requestAnimationFrame(frame);}));
 check(audit.cadence.p95Ms<=33.4,'isolated-model Chrome p95 <=33.3ms (rounding tolerance .1ms)',audit.cadence);
 check(audit.pageErrors.length===0,'no page errors');check(!audit.console.some(m=>m.type==='error'||/SCRIPT ERROR|ERROR:|shader.*fail/i.test(m.text)),'console health');check(!/Error|failed/i.test(audit.identity.status),'no engine error overlay');
 audit.passed=true;
}catch(error){failed=true;audit.passed=false;audit.error=String(error);console.error(error);if(page)await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
}finally{
 if(context){await context.close();audit.cleanup.chromeClosed=true;}
 await new Promise(resolve=>server.close(resolve));audit.cleanup.serverClosed=!server.listening;
 await fs.rm(profile,{recursive:true,force:true});audit.cleanup.privateProfileRemoved=true;audit.finishedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2)+'\n');
}
if(failed)process.exitCode=1;else console.log('PASS CV01 Chrome: model, 13 views, controls, console, cadence; private browser/server/profile cleaned');
