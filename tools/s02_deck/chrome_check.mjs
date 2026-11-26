// Run through tools/verify.py exec. Owns only a private Chrome profile and server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const pack = path.join(root, 'build/s02-deck-web');
const out = path.join(root, 'docs/showcase/evidence/S02-deck/chrome');
const {chromium} = await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out, {recursive:true});
const profile = await fs.mkdtemp(path.join(root,'.local/s02-deck-chrome-'));
const audit = {flow:'Inspection loads -> switch the same seven cameras -> shared hull/deck edge and installed model remain visible',
  scope:'One isolated Yamato model; no Showcase combat or fleet performance claim',
  browserPlugin:'Browser plugin not available',viewport:{width:1600,height:1000},deviceScaleFactor:1,
  checks:[],views:[],console:[],pageErrors:[],cleanup:{},startedUtc:new Date().toISOString()};
let context, page, failed = false;
const check = (passed,name,detail=null) => {audit.checks.push({passed,name,detail});if (!passed) throw Error(name);};
const mime = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server = http.createServer(async (req,res) => {
  try {
    const name = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    if (name === '/favicon.ico') {res.writeHead(204);res.end();return;}
    const target = path.resolve(pack,'.' + name);
    if (!target.startsWith(pack + '/')) throw Error('outside pack');
    const bytes = await fs.readFile(target);
    res.writeHead(200,{'Content-Type':mime[path.extname(target)]||'application/octet-stream','Cache-Control':'no-store'});
    res.end(bytes);
  } catch {res.writeHead(404);res.end('not found');}
});
try {
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  audit.url = 'http://127.0.0.1:' + server.address().port + '/index.html';
  audit.hardware = {cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),
    memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),os:os.release()};
  context = await chromium.launchPersistentContext(profile, {
    executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,
    viewport:audit.viewport,deviceScaleFactor:1,
    args:['--window-position=-1900,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']
  });
  audit.launch = 'Private headful Chrome, offscreen position, background/occlusion throttling disabled';
  audit.browserVersion = await context.browser()?.version();
  page = context.pages()[0] || await context.newPage();
  page.on('console',m=>{if(['error','warning'].includes(m.type()))audit.console.push({type:m.type(),text:m.text()});});
  page.on('pageerror',e=>audit.pageErrors.push(String(e)));
  await page.goto(audit.url,{waitUntil:'load',timeout:60000});
  await page.waitForFunction(()=>window.S02Deck?.latest?.sockets===39,null,{timeout:60000});
  audit.identity = await page.evaluate(()=>{
    const c=document.querySelector('canvas'),r=c.getBoundingClientRect(),gl=c.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');
    return {title:document.title,url:location.href,canvas:[c.width,c.height,r.width,r.height],
      gpu:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,visibility:document.visibilityState,
      status:document.querySelector('#status')?.textContent||''};
  });
  audit.sceneIdentity = await page.evaluate(()=>window.S02Deck.latest);
  // Godot updates the browser title from config/name after the scene's _ready.
  check(audit.identity.title==='Yamato · 1944 study' && audit.identity.url===audit.url && audit.sceneIdentity.model_id==='jp_yamato_1944_04','page and dedicated scene identity');
  check(audit.identity.canvas.every((n,i)=>n===[1600,1000,1600,1000][i]),'matching native viewport and render buffer');
  check(audit.identity.gpu && !/swiftshader|llvmpipe|software/i.test(audit.identity.gpu),'hardware WebGL');
  await page.locator('canvas').focus();
  await page.keyboard.press('ArrowRight');
  await page.waitForFunction(()=>window.S02Deck.latest.index===1);
  audit.interaction = {action:'ArrowRight',state:await page.evaluate(()=>window.S02Deck.latest)};
  await page.keyboard.press('ArrowLeft');
  await page.waitForFunction(()=>window.S02Deck.latest.index===0);
  check(audit.interaction.state.view==='starboard_side','keyboard changes the actual inspection camera');
  const labels=['port_side','starboard_side','port_elevated','fore_transition','aft_transition','fore_hull_side','aft_hull_side'];
  for(let i=0;i<labels.length;i++) {
    await page.evaluate(c=>window.S02Deck.commands.push(c),{id:i+1,kind:'view',value:i});
    await page.waitForFunction(id=>window.S02Deck.latest.command_id>=id,i+1);
    await page.waitForTimeout(250);
    const state=await page.evaluate(()=>window.S02Deck.latest);
    check(state.view===labels[i] && state.sockets===39,'camera/model state ' + labels[i]);
    const file=path.join(out,labels[i]+'.png');
    const bytes=await page.screenshot({path:file});
    check(bytes.length>10000,'nonempty rendered screenshot ' + labels[i]);
    audit.views.push({label:labels[i],file,state,bytes:bytes.length});
  }
  // Return to the complete model, then sample actual Chrome animation-frame cadence.
  await page.keyboard.press('ArrowRight');
  await page.waitForFunction(()=>window.S02Deck.latest.index===0);
  await page.waitForTimeout(1000);
  audit.cadence=await page.evaluate(()=>new Promise(resolve=>{
    const times=[],start=performance.now();let previous;
    const frame=now=>{if(previous!==undefined)times.push(now-previous);previous=now;
      if(now-start<6000){requestAnimationFrame(frame);return;}
      const sorted=[...times].sort((a,b)=>a-b),sum=times.reduce((a,b)=>a+b,0);
      resolve({durationMs:now-start,frames:times.length,meanMs:sum/times.length,
        p50Ms:sorted[Math.floor(sorted.length*.5)],p95Ms:sorted[Math.floor(sorted.length*.95)],
        estimatedFps:times.length*1000/sum,state:window.S02Deck.latest});};requestAnimationFrame(frame);
  }));
  check(audit.pageErrors.length===0,'no page errors');
  check(!audit.console.some(m=>m.type==='error' || /SCRIPT ERROR|ERROR:|shader.*fail/i.test(m.text)),'console health');
  check(!/Error|failed/i.test(audit.identity.status),'no engine error overlay');
  audit.passed=true;
} catch(error) {
  failed=true;audit.passed=false;audit.error=String(error);console.error(error);
} finally {
  if(context){await context.close();audit.cleanup.chromeClosed=true;}
  await new Promise(resolve=>server.close(resolve));audit.cleanup.serverClosed=!server.listening;
  await fs.rm(profile,{recursive:true,force:true});audit.cleanup.privateProfileRemoved=true;
  audit.finishedUtc=new Date().toISOString();
  await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2)+'\n');
}
if(failed)process.exitCode=1;
else console.log('PASS S02-deck: seven matching Chrome views, camera input, console and bounded cadence; temporary Chrome/server closed');
