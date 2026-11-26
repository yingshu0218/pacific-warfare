// Invoke only through tools/verify.py --owner CV02 exec; owns its browser/server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const pack=path.join(root,'build/cv02-web');
const out=path.join(root,'docs/showcase/evidence/CV02/chrome');
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/cv02-chrome-'));
const audit={scope:'Isolated CV02 1941 model/static cross-era A6M bearing/D4Y dimensions only; not OPS01',
  browserAutomation:'No browser automation plugin tools exposed; existing project local Playwright workflow used',
  viewport:{width:1440,height:900},deviceScaleFactor:1,checks:[],views:[],console:[],pageErrors:[],cleanup:{},startedUtc:new Date().toISOString()};
let context,page,failed=false;
const check=(passed,name,detail=null)=>{audit.checks.push({passed,name,detail});if(!passed)throw Error(name);};
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server=http.createServer(async(req,res)=>{
  try {
    const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    if(pathname==='/favicon.ico'){res.writeHead(204);res.end();return;}
    const target=path.resolve(pack,'.'+pathname);
    if(!target.startsWith(pack+'/'))throw Error('outside package');
    const data=await fs.readFile(target);
    res.writeHead(200,{'Content-Type':mime[path.extname(target)]||'application/octet-stream','Cache-Control':'no-store'});res.end(data);
  } catch {res.writeHead(404);res.end('not found');}
});
const labels=['type89_open_module','type89_smoke_module','type96_module','starboard_side','port_side','top',
  'starboard_bow_quarter','port_stern_quarter','starboard_aft_twins','downturned_funnels','bow_underdeck','stern_underdeck',
  'a6m_forward_park','a6m_actual_wheels','three_lifts_and_static_fit','d4y2_dimension_proxy_only','forward_elevator_lowered'];
let sequence=0;
const command=async(data)=>{
  const id=++sequence;
  await page.evaluate(c=>window.CV02.commands.push(c),{...data,id});
  await page.waitForFunction(id=>window.CV02.latest.command_id===id,id,{timeout:5000});
  return await page.evaluate(()=>window.CV02.latest);
};
try {
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  audit.url='http://127.0.0.1:'+server.address().port+'/index.html';
  audit.hardware={cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),
    memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),os:os.release()};
  context=await chromium.launchPersistentContext(profile,{executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless:false,viewport:audit.viewport,deviceScaleFactor:1,args:['--window-position=-1900,0',
      '--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
  audit.launch='Private offscreen headful Chrome with hardware WebGL; no existing browser windows accessed';
  audit.browserVersion=await context.browser()?.version();
  page=context.pages()[0]||await context.newPage();
  page.on('console',message=>{if(['error','warning'].includes(message.type()))audit.console.push({type:message.type(),text:message.text()});});
  page.on('pageerror',error=>audit.pageErrors.push(String(error)));
  await page.goto(audit.url,{waitUntil:'load',timeout:60000});
  await page.waitForFunction(()=>window.CV02?.latest?.sockets===14,null,{timeout:60000});
  audit.identity=await page.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect(),gl=c.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');
    return {title:document.title,url:location.href,canvas:[c.width,c.height,r.width,r.height],
      gpu:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,status:document.querySelector('#status')?.textContent||''};});
  check(audit.identity.title==='CV02 Shokaku · isolated inspection','isolated project identity');
  check(audit.identity.canvas.every((v,i)=>v===[1440,900,1440,900][i]),'actual render buffer / viewport / DPR');
  check(audit.identity.gpu&&!/swiftshader|llvmpipe|software/i.test(audit.identity.gpu),'hardware WebGL');
  await page.locator('canvas').focus();
  await page.keyboard.press('ArrowRight');await page.waitForFunction(()=>window.CV02.latest.index===7);
  await page.keyboard.press('ArrowLeft');await page.waitForFunction(()=>window.CV02.latest.index===6);
  check(true,'real keyboard camera switching');
  for(let i=0;i<labels.length;i++){
    const state=await command({kind:'view',value:i});
    await page.waitForTimeout(180);
    check(state.view===labels[i]&&state.model_id==='jp_shokaku_1941_08_23'&&state.sockets===14,'model/view '+labels[i]);
    const file=path.join(out,labels[i]+'.png');
    const bytes=await page.screenshot({path:file});
    check(bytes.length>10000,'rendered '+labels[i]);
    audit.views.push({id:labels[i],file,state,bytes:bytes.length});
  }
  await command({kind:'view',value:5});
  for(const elevator_id of ['elevator_forward','elevator_middle','elevator_aft']){
    for(const value of [4,8.95,14.15]){
      const state=await command({kind:'elevator',elevator_id,value});
      check(Math.abs(state.elevator_heights[elevator_id]-value)<.001,'independent lift '+elevator_id+' @ '+value);
    }
  }
  await command({kind:'view',value:6});await page.waitForTimeout(350);
  audit.cadence=await page.evaluate(()=>new Promise(resolve=>{
    const samples=[],start=performance.now();let previous;
    const frame=now=>{
      if(previous!==undefined)samples.push(now-previous);previous=now;
      if(now-start<6000){requestAnimationFrame(frame);return;}
      const sorted=[...samples].sort((a,b)=>a-b),sum=samples.reduce((a,b)=>a+b,0);
      resolve({durationMs:now-start,frames:samples.length,meanMs:sum/samples.length,p50Ms:sorted[Math.floor(sorted.length*.5)],
        p95Ms:sorted[Math.floor(sorted.length*.95)],p99Ms:sorted[Math.floor(sorted.length*.99)],estimatedFps:samples.length*1000/sum,
        drawCalls:window.CV02.latest.draw_calls,primitives:window.CV02.latest.primitives});
    };requestAnimationFrame(frame);
  }));
  check(audit.cadence.p95Ms<=33.4,'isolated model p95 <=33.3ms (rounding .1ms)',audit.cadence);
  check(audit.pageErrors.length===0,'no page errors');
  check(!audit.console.some(m=>m.type==='error'||/SCRIPT ERROR|ERROR:|shader.*fail/i.test(m.text)),'engine / shader console health');
  check(!/Error|failed/i.test(audit.identity.status),'no error overlay');
  audit.passed=true;
} catch(error) {
  failed=true;audit.passed=false;audit.error=String(error);console.error(error);
  if(page)await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
} finally {
  if(context){await context.close();audit.cleanup.chromeClosed=true;}
  await new Promise(resolve=>server.close(resolve));audit.cleanup.serverClosed=!server.listening;
  await fs.rm(profile,{recursive:true,force:true});audit.cleanup.privateProfileRemoved=true;
  audit.finishedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2)+'\n');
}
if(failed)process.exitCode=1;
else console.log('PASS CV02 Chrome: 17 views, 3 lifts, controls, console, cadence; private browser/server/profile cleaned');
