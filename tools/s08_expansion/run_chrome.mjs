// Preparation is inert. --execute additionally requires a fully bound final
// contract, a passing read-only pack audit, and the parent verify.py lock.
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import {createReadStream} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {EvidenceSink,installObserver,at,matches,menuIndex,menuPoint} from './observer.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const arg=(key,fallback)=>process.argv.find(value=>value.startsWith('--'+key+'='))?.slice(key.length+3)??fallback;
const small=(view,bindings)=>Object.fromEntries(Object.entries(bindings).filter(([,p])=>p).map(([key,p])=>[key,at(view.state,p)]));

export async function heldByParent(lockPath,parent) {
 const lock=JSON.parse(await fs.readFile(lockPath,'utf8'));
 if(lock.status!=='held'||lock.pid!==parent||!lock.owner.startsWith('S08'))throw Error('Execute only as a direct child of tools/verify.py --owner S08...');
 return lock;
}

async function main() {
 if(process.argv.includes('--help')||!process.argv.includes('--execute')){
  console.log('PREPARATION ONLY: no server, Godot, export, Chrome or browser imports.\nLater: tools/verify.py --owner S08-expanded --timeout 1250 exec -- node tools/s08_expansion/run_chrome.mjs --execute --contract=FINAL.json --mode=plain|observed --evidence=NEW_DIRECTORY');return;
 }
 const contractFile=path.resolve(arg('contract',''));
 if(!arg('contract'))throw Error('Final coordinator-bound contract required');
 const mode=arg('mode','plain');if(!['plain','observed'].includes(mode))throw Error('Choose plain or observed');
 const contract=JSON.parse(await fs.readFile(contractFile,'utf8'));
 // Python's audit validates every final binding before any browser import.
 const packAudit=JSON.parse(execFileSync('/usr/bin/python3',[path.join(root,'tools/s08_expansion/audit_pack.py'),'--contract',contractFile],{cwd:root,encoding:'utf8',timeout:30000}));
 const lock=await heldByParent(path.join(root,'.local/validation/godot-render.lock'),process.ppid);
 const out=path.resolve(arg('evidence',''));
 const scopes=['tools/s08_expansion/evidence','candidates/s08-expansion','docs/showcase/evidence/S08-expansion'].map(p=>path.join(root,p)+path.sep);
 if(!arg('evidence')||!scopes.some(p=>out.startsWith(p)))throw Error('Supply a fresh S08 expansion evidence directory');
 await fs.mkdir(path.dirname(out),{recursive:true});
 await fs.mkdir(out,{recursive:false}); // Refuse overwriting previous evidence.
 const sink=new EvidenceSink(out,contract.runtime);
 const audit={status:'running',mode,started_utc:new Date().toISOString(),contract_file:contractFile,contract_sha256:packAudit.contract_sha256,pack_audit:packAudit,verify_lock:lock,flow:'Ordinary expanded page -> real visible menus and controls -> authoritative states and events',browser_path:'Browser plugin not available in preparation session; recheck before final execution; locally installed actual Chrome via Playwright',checks:[],phases:[],cases:[],cleanup:{},errors:[],console:[]};
 let context,page,server,profile,timer,cdp,lastMemory=0;let abortReason=null;
 const check=(condition,name,detail=null)=>{audit.checks.push({name,passed:!!condition,detail});if(!condition)throw Error(name)};
 const abort=reason=>{abortReason=reason;if(context)context.close().catch(()=>{});if(server)server.close()};
 const signals=new Map(['SIGTERM','SIGINT'].map(signal=>[signal,()=>abort(signal)]));
 for(const [signal,handler]of signals)process.on(signal,handler);
 timer=setTimeout(()=>abort('Browser lifetime exceeded'),contract.runtime.max_seconds*1000);
 async function view(){if(abortReason)throw Error(abortReason);const value=await page.evaluate(()=>{const c=window.__S08X;return c?{state:c.latest,ui:c.ui,metrics:c.metrics,tallies:c.tallies,receivedAt:c.receivedAt,failure:c.failure}:null});if(value?.failure)throw Error(value.failure);if(sink.failure)throw Error(sink.failure);return value}
 async function until(fn,timeout=20000){const deadline=Date.now()+timeout;while(Date.now()<deadline){const value=await view();if(fn(value))return value;await memory();await sleep(100)}throw Error('Timed out waiting for actual UI/state')}
 async function phase(name){await page.evaluate(value=>window.__S08X.setPhase(value),name);await sink.write('actions',{action:'phase',name,utc:new Date().toISOString()})}
 async function point(point){check(Array.isArray(point)&&point.length===2&&point.every(Number.isFinite),'Actual control geometry available');const rect=await page.locator('canvas').boundingBox();await page.mouse.click(rect.x+point[0]*rect.width/contract.target.buffer[0],rect.y+point[1]*rect.height/contract.target.buffer[1]);const after=await page.evaluate(()=>performance.now()+80);await until(v=>v?.receivedAt>after);await sink.write('actions',{action:'click',point,utc:new Date().toISOString()})}
 async function choose(step){
  let v=await until(v=>v?.state?.controls?.[step.menu]&&Object.values(v.state.buttons||{}).some(p=>JSON.stringify(p)===JSON.stringify(v.state.controls[step.menu])));
  await point(v.state.controls[step.menu]);v=await until(v=>v.state.popups?.[step.menu]?.visible);
  const popup=v.state.popups[step.menu],index=menuIndex(popup,step),geometry=menuPoint(popup,index),rect=await page.locator('canvas').boundingBox();
  await page.mouse.move(rect.x+(popup.position[0]+popup.size[0]*.5)*rect.width/1280,rect.y+(popup.position[1]+popup.size[1]*.5)*rect.height/720);
  await page.mouse.wheel(0,geometry.wheel);await sleep(250);await point(geometry.point);
  await until(v=>!v.state.popups[step.menu].visible);
  await sink.write('actions',{action:'menu',menu:step.menu,label:step.label,metadata:step.metadata,observed_index:index,popup,utc:new Date().toISOString()});
 }
 async function memory(){
  if(!cdp||Date.now()-lastMemory<5000)return;lastMemory=Date.now();
  const {processInfo}=await cdp.send('SystemInfo.getProcessInfo');
  const values=JSON.parse(execFileSync('/usr/bin/python3',[path.join(root,'tools/s08_expansion/owned_memory.py'),...processInfo.map(p=>String(p.id))],{encoding:'utf8',timeout:4000}));
  await sink.write('memory',{utc:new Date().toISOString(),scope:'PIDs returned by this isolated Chrome CDP session only',processes:processInfo,memory:values});
  await fs.writeFile(path.join(out,'ownership.json'),JSON.stringify({pid:process.pid,parent_verify:process.ppid,profile,lock_token:lock.token,owned_cdp_pids:processInfo.map(p=>p.id),updated_utc:new Date().toISOString()},null,2)+'\n');
 }
 async function sample(step,name){
  await phase(name);const begin=await view(),start=Date.now(),browserStart=await page.evaluate(()=>performance.now());
  while(Date.now()-start<step.seconds*1000){
   await sleep(Math.min(1000,Math.max(1,step.seconds*1000-(Date.now()-start))));await memory();
   const v=await view();if(!step.active)continue;
   const state=small(v,contract.bindings);if(!(state.generation===small(begin,contract.bindings).generation&&!state.paused&&!state.ended&&state.speed===1))throw Error('Active 1x sample paused, ended, changed generation or speed');
   if((await page.evaluate(()=>performance.now()))-v.receivedAt>=2000)throw Error('State samples became stale');
  }
  const end=await view(),wall=(Date.now()-start)/1000,browserEnd=await page.evaluate(()=>performance.now()),a=small(begin,contract.bindings),b=small(end,contract.bindings);
  let moved=0;for(const [id,unit]of Object.entries(begin?.state?.units||{})){const p=unit.position_m,q=end?.state?.units?.[id]?.position_m;if(Array.isArray(p)&&Array.isArray(q)&&Math.hypot(...q.map((x,i)=>x-p[i]))>1)moved++}
  if(step.active)check(b.tick>a.tick&&b.sim_time>a.sim_time&&moved>0,'Active interval advances real ticks and unit positions without pause/end/speed changes');
  const result={name,wall_s:wall,browser_start_ms:browserStart,browser_end_ms:browserEnd,begin:a,end:b,actual_scale:(b.sim_time-a.sim_time)/wall,active:!!step.active,units_moved:moved};audit.phases.push(result);await sink.write('phases',result);
 }
 try{
  const {chromium}=await import(contract.runtime.playwright_module);
  profile=await fs.mkdtemp(path.join(root,'.local/s08-expanded-chrome-'));audit.profile=profile;
  await fs.writeFile(path.join(out,'ownership.json'),JSON.stringify({pid:process.pid,parent_verify:process.ppid,profile,lock_token:lock.token,owned_cdp_pids:[],created_utc:new Date().toISOString()},null,2)+'\n');
  const pack=path.resolve(root,contract.package.directory);
  server=http.createServer(async(req,res)=>{
   try{const url=new URL(req.url,contract.target.url);if(url.pathname==='/favicon.ico'){res.writeHead(204);res.end();return}
    const file=path.resolve(pack,'.'+decodeURIComponent(url.pathname));if(!file.startsWith(pack+path.sep))throw Error('outside pack');
    const stat=await fs.stat(file);if(!stat.isFile())throw Error('not file');const type={'.html':'text/html','.wasm':'application/wasm','.js':'text/javascript','.pck':'application/octet-stream'}[path.extname(file)]||'application/octet-stream';
    res.writeHead(200,{'Content-Type':type,'Content-Length':stat.size,'Cache-Control':'no-store'});createReadStream(file).on('error',()=>res.destroy()).pipe(res);
   }catch{res.writeHead(404);res.end('missing')}
  });
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(8765,'127.0.0.1',resolve)});
  context=await chromium.launchPersistentContext(profile,{executablePath:contract.runtime.chrome,headless:false,viewport:{width:1280,height:720},deviceScaleFactor:1,args:['--window-position=-1800,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
  page=context.pages()[0]||await context.newPage();page.on('pageerror',error=>audit.errors.push(String(error)));page.on('console',message=>{if(['warning','error'].includes(message.type())){if(audit.console.length>=200)abort('Console evidence limit exceeded');else audit.console.push({type:message.type(),text:message.text()})}});
  await page.exposeBinding('_s08xWrite',(_,channel,value)=>sink.write(channel,value));
  await page.exposeBinding('_s08xAudio',async(_,value)=>{const bytes=Buffer.from(value.base64,'base64');if(bytes.length>2*1024*1024)throw Error('Audio limit exceeded');const name=value.mime.includes('mp4')?'actual-output.mp4':'actual-output.webm';await fs.writeFile(path.join(out,name),bytes,{flag:'wx'});audit.audio={file:name,bytes:bytes.length,mime:value.mime}});
  const observerOptions={observed:mode==='observed',probe:contract.probe,budgets:contract.runtime,audioEnabled:mode==='observed'};
  if(mode==='observed')await page.addInitScript(installObserver,observerOptions);
  await page.goto(contract.target.url,{waitUntil:'load',timeout:60000});await page.waitForFunction(()=>!document.getElementById('status'),null,{timeout:60000});
  audit.identity=await page.evaluate(async()=>{const c=document.querySelector('canvas'),g=c.getContext('webgl2'),e=g.getExtension('WEBGL_debug_renderer_info');return{url:location.href,title:document.title,buffer:[g.drawingBufferWidth,g.drawingBufferHeight],css:[c.clientWidth,c.clientHeight],dpr:devicePixelRatio,gpu:e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):null,ua:navigator.userAgent,uaData:await navigator.userAgentData?.getHighEntropyValues(['fullVersionList','architecture','bitness'])}});
  check(audit.identity.url===contract.target.url&&audit.identity.title.includes(contract.target.title_contains),'Ordinary default entry and title');check(JSON.stringify(audit.identity.buffer)==='[1280,720]','Actual 1280x720 rendering buffer');check(audit.identity.gpu&&!/swiftshader|software|llvmpipe/i.test(audit.identity.gpu),'Actual hardware rendering');
  audit.hardware={cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),memory_bytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),macos:execFileSync('/usr/bin/sw_vers',['-productVersion'],{encoding:'utf8'}).trim()};
  check(audit.hardware.cpu==='Apple M5'&&audit.hardware.memory_bytes===17179869184,'M5/16GiB benchmark device');
  cdp=await context.browser().newBrowserCDPSession();await memory();
  await page.screenshot({path:path.join(out,'ordinary_entry.png')});
  if(mode==='plain'){
   const flags=await page.evaluate(keys=>Object.fromEntries(keys.map(k=>[k,typeof window[k]])),[contract.probe.global,contract.probe.metrics_global]);check(Object.values(flags).every(v=>v==='undefined'),'No Godot observation globals on plain page');audit.plain_probe_flags=flags;
   // Passive browser-only rAF starts after the uninstrumented ordinary page
   // has loaded. It never creates the S14/S08 flags that enable Godot probes.
   await page.evaluate(installObserver,observerOptions);await phase('plain_warmup');await sleep(contract.runtime.warmup_seconds*1000);await phase('plain_1x');const begin=await page.evaluate(()=>performance.now()),wall=Date.now();while(Date.now()-wall<contract.runtime.plain_seconds*1000){await sleep(1000);await memory()}audit.phases.push({name:'plain_1x',browser_start_ms:begin,browser_end_ms:await page.evaluate(()=>performance.now()),wall_s:(Date.now()-wall)/1000,simulation_state_unobserved:true});
  }else{
   await until(v=>!!v?.state,60000);await phase('observed_warmup');await sleep(contract.runtime.warmup_seconds*1000);check(small(await view(),contract.bindings).speed===1,'Default observed comparison is 1x');await sample({seconds:contract.runtime.plain_seconds},'observed_default_1x');
   for(const test of contract.cases){
    await phase(test.key);const row={key:test.key,group:test.group,declared_features:test.features,passed:false};audit.cases.push(row);
    for(const [index,step]of test.steps.entries()){
     if(step.action==='menu')await choose(step);
     if(step.action==='button'){const v=await until(v=>v.state.buttons?.[step.label]);await point(v.state.buttons[step.label])}
     if(step.action==='control'){const v=await until(v=>at(v,step.path));await point(at(v,step.path))}
     if(step.action==='key'){
      if(step.focus)await point(step.focus);const before=small(await view(),contract.bindings);await page.keyboard.press(step.key);
      if(step.key==='KeyR'){await until(v=>small(v,contract.bindings).generation>before.generation);audit.restarts=(audit.restarts||0)+1}
      await sink.write('actions',{action:'key',key:step.key,before,after:small(await view(),contract.bindings),utc:new Date().toISOString()});
     }
     if(step.action==='wait')await until(v=>(step.conditions||[]).length>0&&step.conditions.every(condition=>matches(v,condition)),step.timeout_ms||30000);
     if(step.action==='sample')await sample(step,test.key+'_'+(step.name||index));
     if(step.action==='pause_check'){
      const name=test.key+'_sound_pause_'+index;await phase(name);const before=small(await view(),contract.bindings),start=await page.evaluate(()=>performance.now());check(before.paused&&before.sound,'Sound enabled before pause sample');await sleep(step.seconds*1000);const after=small(await view(),contract.bindings),end=await page.evaluate(()=>performance.now());check(after.tick===before.tick&&after.paused&&after.sound,'Paused tick stays frozen with sound enabled');audit.phases.push({name,wall_s:step.seconds,browser_start_ms:start,browser_end_ms:end,begin:before,end:after,sound_pause:true});
     }
     if(step.action==='screenshot'){if(!/^[a-z0-9_]+$/.test(step.name))throw Error('Invalid screenshot evidence name');await page.screenshot({path:path.join(out,test.key+'_'+step.name+'.png')})}
     if(step.action==='checkpoint'){const v=await view();check((step.conditions||[]).length>0&&step.conditions.every(condition=>matches(v,condition)),test.key+' checkpoint '+index);await sink.write('checkpoints',{case:test.key,index,view:v})}
    }row.passed=true;
   }
   const active=audit.phases.filter(p=>p.active).reduce((sum,p)=>sum+p.wall_s,0);check(active>=contract.acceptance.minimum_active_wall_s,'Required actual active 1x runtime');check(audit.restarts>=contract.acceptance.minimum_restarts,'Required real keyboard restarts');
  }
  await memory();
  await page.evaluate(()=>window.__S08X.flush());check(audit.errors.length===0&&!audit.console.some(v=>/SCRIPT ERROR|^\s*ERROR:|WebGL.*INVALID_|shader.*error/i.test(v.text)),'No page/Godot/rendering errors');audit.status='functional_steps_passed_performance_separate';
 }catch(error){audit.status='failed_or_incomplete';audit.failure=String(error.stack||error);if(page)try{await page.screenshot({path:path.join(out,'failure.png')})}catch{}}
 finally{
  clearTimeout(timer);for(const [signal,handler]of signals)process.removeListener(signal,handler);
  if(page)try{await page.evaluate(()=>window.__S08X?.flush())}catch(error){audit.flush_error=String(error);audit.status='failed_or_incomplete'}
  if(context)try{await context.close();audit.cleanup.chrome_closed=true}catch(error){audit.cleanup.chrome_error=String(error);audit.status='failed_or_incomplete'}
  if(server){server.closeAllConnections?.();if(server.listening)await new Promise(resolve=>server.close(resolve));audit.cleanup.server_closed=!server.listening}
  if(profile){await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profile_removed=true}
  try{audit.evidence=await sink.finish()}catch(error){audit.evidence_error=String(error);audit.status='failed_or_incomplete'}
  audit.ended_utc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2)+'\n');console.log(JSON.stringify({status:audit.status,cleanup:audit.cleanup,output:out}));
 }
 process.exitCode=audit.status.startsWith('functional_')?0:1;
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(error=>{console.error(String(error));process.exitCode=2});
