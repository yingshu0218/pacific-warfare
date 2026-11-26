// Actual Chrome, normal user PCK and default URL. No alternate scene or battle writes.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const opt=(key,def)=>process.argv.find(v=>v.startsWith('--'+key+'='))?.slice(key.length+3)||def;
const baseline=process.argv.includes('--baseline');
const plain=process.argv.includes('--plain');
const out=path.resolve(root,opt('evidence',baseline?'docs/showcase/evidence/S08/final-20261111/baseline':'docs/showcase/evidence/S08/final-20261111/chrome'));
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/s08-chrome-'));
const audit={startedUtc:new Date().toISOString(),baseline,browserPlugin:'Browser plugin not available; actual Chrome via existing Playwright runtime',normalUrl:'http://127.0.0.1:8765/index.html',entry:'res://showcase/all_units.tscn',checks:[],interactions:[],phases:[],console:[],errors:[],cleanup:{},profile};
let context,page,server,browserCDP,phaseName='loading',lastMemory=0,writing=Promise.resolve(),peakFragments=0;
const samples=[],audio=[];
for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>{context?.close().catch(()=>{});if(server&&server.exitCode===null)server.kill('SIGTERM')});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const check=(value,name,detail=null)=>{audit.checks.push({name,passed:!!value,detail});if(!value)throw Error(name)};
const saveLine=(file,data)=>{writing=writing.then(()=>fs.appendFile(path.join(out,file),JSON.stringify(data)+'\n'));return writing};
const snap=()=>page.evaluate(()=>window.S08.latest);
const wait=(fn,arg=null,timeout=30000)=>page.waitForFunction(fn,arg,{timeout});
const click=async point=>{const r=await page.locator('canvas').boundingBox();audit.interactions.push({action:'click',point,phase:phaseName,utc:new Date().toISOString()});await page.mouse.click(r.x+point[0]*r.width/1280,r.y+point[1]*r.height/720);const after=await page.evaluate(()=>performance.now()+120);await wait(at=>window.S08.latest.browser_at_ms>at,after)};
const key=async key=>{audit.interactions.push({action:'key',key,phase:phaseName,utc:new Date().toISOString()});await page.keyboard.press(key)};
const button=async label=>{const s=await snap();check(!!s.buttons[label],'Button visible '+label);await click(s.buttons[label])};
const choose=async(name,index)=>{let s=await snap();await click(s.controls[name]);await wait(k=>window.S08.latest.popups[k].visible,name);s=await snap();const p=s.popups[name];check(index>=0&&index<p.count,'Option exists '+name+'/'+index);await click([p.position[0]+p.size[0]*.5,p.position[1]+p.size[1]*(index+.5)/p.count]);await wait(k=>!window.S08.latest.popups[k].visible,name)};
const focus=()=>click([640,585]);
const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
async function memory(){if(!browserCDP||Date.now()-lastMemory<5000)return;lastMemory=Date.now();const info=await browserCDP.send('SystemInfo.getProcessInfo');const ids=info.processInfo.map(p=>String(p.id));const values=JSON.parse(execFileSync('/usr/bin/python3',[path.join(root,'tools/s08/owned_memory.py'),...ids],{encoding:'utf8',timeout:4000}));await saveLine('memory.ndjson',{utc:new Date().toISOString(),phase:phaseName,scope:'Only PIDs from this isolated Chrome browser CDP session',processes:info.processInfo,memory:values})}
async function phase(name,seconds,stopOnFragments=false){phaseName=name;await page.evaluate(n=>window.S08.phase=n,name);const begin=await snap(),wall=Date.now();console.log('S08 phase '+name);await fs.writeFile(path.join(out,'progress.json'),JSON.stringify({phase:name,utc:new Date().toISOString(),begin}));while(Date.now()-wall<seconds*1000){await sleep(Math.min(1000,seconds*1000-(Date.now()-wall)));await memory();if(stopOnFragments&&(await snap()).fragments>0)break}const end=await snap();const result={name,wall_s:(Date.now()-wall)/1000,begin,end,actual_scale:(end.time_s-begin.time_s)/((Date.now()-wall)/1000)};audit.phases.push(result);return result}
try{
 audit.buildManifest=JSON.parse(await fs.readFile(path.join(root,'build/first-playable/build_manifest.json'),'utf8'));
 const html=await fs.readFile(path.join(root,'build/first-playable/index.html'),'utf8');check(!html.includes('measure.js')&&!html.includes('s14_web'),'Ordinary shell without validation JS or test entry');
 server=spawn('/usr/bin/python3',[path.join(root,'tools/serve_first_playable.py'),'--seconds',baseline?'200':'1100','--evidence',path.join(out,'server')],{cwd:root,stdio:['ignore','pipe','pipe']});audit.serverPid=server.pid;let ready='';server.stdout.on('data',b=>{ready+=b;fs.appendFile(path.join(out,'server.log'),b)});server.stderr.on('data',b=>fs.appendFile(path.join(out,'server.log'),b));
 const until=Date.now()+10000;while(!ready.includes('Open Chrome:')&&Date.now()<until){if(server.exitCode!==null)throw Error('Preview exited before listening');await sleep(100)}check(ready.includes('Open Chrome:'),'Normal preview is listening on default port');
 context=await chromium.launchPersistentContext(profile,{executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,viewport:{width:1280,height:720},deviceScaleFactor:1,args:['--window-position=-1800,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 page=context.pages()[0]||await context.newPage();page.on('console',m=>{if(['error','warning'].includes(m.type()))audit.console.push({type:m.type(),text:m.text()})});page.on('pageerror',e=>audit.errors.push(String(e)));
 if(plain){
  await page.goto(audit.normalUrl,{waitUntil:'load',timeout:60000});
  await page.waitForFunction(()=>!document.getElementById('status'),null,{timeout:60000});await sleep(1500);
  audit.plain=await page.evaluate(()=>{const c=document.querySelector('canvas'),g=c.getContext('webgl2');return{url:location.href,title:document.title,buffer:[g.drawingBufferWidth,g.drawingBufferHeight],S08:typeof window.S08,S14:typeof window.S14,buttons:[...document.querySelectorAll('button')].map(x=>x.textContent)}});
  check(audit.plain.S08==='undefined'&&audit.plain.S14==='undefined','Plain user page has no measurement globals');
  check(audit.plain.buffer[0]===1280&&audit.plain.buffer[1]===720,'Plain user page renders 1280x720');await shot('plain_user_page');
  check(audit.errors.length===0&&!audit.console.some(x=>/SCRIPT ERROR|^\s*ERROR:/i.test(x.text)),'Plain page loads without errors');audit.passed=true;
 }else{
 await page.exposeBinding('_s08Record',(_,data)=>{data.phase=phaseName;samples.push(data);peakFragments=Math.max(peakFragments,data.game.fragments);return saveLine('samples.ndjson',data)});
 await page.exposeBinding('_s08Audio',async(_,data)=>{const name='actual-output.'+(data.mime.includes('mp4')?'mp4':'webm');await fs.writeFile(path.join(out,name),Buffer.from(data.base64,'base64'));audit.audioFile=name;audit.audioMime=data.mime});
 await page.addInitScript(()=>{
  const memories=[],RealMemory=WebAssembly.Memory;WebAssembly.Memory=new Proxy(RealMemory,{construct(target,args){const m=Reflect.construct(target,args);memories.push(m);return m}});
  for(const name of ['instantiate','instantiateStreaming']){const original=WebAssembly[name];if(original)WebAssembly[name]=async function(...args){const r=await original.apply(WebAssembly,args);for(const value of Object.values((r.instance||r).exports||{}))if(value instanceof RealMemory&&!memories.includes(value))memories.push(value);return r}}
  let last=null,frames=[],audioRows=[],created=0,recorded=false;const contexts=[];const seen=new WeakSet();const cls=window.AudioContext||window.webkitAudioContext;const source=cls.prototype.createBufferSource;cls.prototype.createBufferSource=function(...args){created++;return source.apply(this,args)};
  const connect=AudioNode.prototype.connect;AudioNode.prototype.connect=function(destination,...rest){const result=connect.call(this,destination,...rest);if(destination===this.context.destination&&!seen.has(this)){seen.add(this);let item=contexts.find(x=>x.ctx===this.context);if(!item){const ctx=this.context,analyser=ctx.createAnalyser(),stream=ctx.createMediaStreamDestination();analyser.fftSize=2048;item={ctx,analyser,stream,buffer:new Float32Array(2048)};contexts.push(item)}connect.call(this,item.analyser);connect.call(this,item.stream)}return result};
  function raf(now){if(last!==null&&window.S08.latest)frames.push({at:now,ms:now-last,phase:window.S08.phase,visible:document.visibilityState,focused:document.hasFocus()});last=now;for(const item of contexts){item.analyser.getFloatTimeDomainData(item.buffer);let sum=0,peak=0;for(const v of item.buffer){sum+=v*v;peak=Math.max(peak,Math.abs(v))}audioRows.push({at:now,phase:window.S08.phase,state:item.ctx.state,time:item.ctx.currentTime,rms:Math.sqrt(sum/item.buffer.length),peak});if(!recorded&&peak>1e-5&&item.ctx.state==='running'){recorded=true;const rec=new MediaRecorder(item.stream.stream),parts=[];rec.ondataavailable=e=>parts.push(e.data);rec.onstop=async()=>{const b=new Uint8Array(await new Blob(parts).arrayBuffer());let value='';for(let i=0;i<b.length;i+=32768)value+=String.fromCharCode(...b.subarray(i,i+32768));await window._s08Audio({base64:btoa(value),mime:rec.mimeType})};rec.start();setTimeout(()=>rec.stop(),8000)}}requestAnimationFrame(raf)}requestAnimationFrame(raf);
  window.S08={latest:null,phase:'loading',ui(data){data.browser_at_ms=performance.now();this.latest=data},accept(game){window._s08Record({now_ms:performance.now(),utc:new Date().toISOString(),game,raf:frames.splice(0),audio:audioRows.splice(0),audio_sources_created:created,wasm_bytes:memories.map(m=>m.buffer.byteLength),js_heap:performance.memory?performance.memory.usedJSHeapSize:null});return false},image(){}};
 });
 await page.goto(audit.normalUrl,{waitUntil:'load',timeout:60000});await wait(()=>window.S08.latest?.models===19,null,60000);
 audit.identity=await page.evaluate(async()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect(),g=c.getContext('webgl2'),e=g.getExtension('WEBGL_debug_renderer_info');return{url:location.href,title:document.title,dpr:devicePixelRatio,canvas:{width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height,bufferWidth:g.drawingBufferWidth,bufferHeight:g.drawingBufferHeight},gpu:e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):null,ua:navigator.userAgent,uaData:await navigator.userAgentData?.getHighEntropyValues(['fullVersionList','architecture','bitness']),validationFixture:typeof window.S14}});
 audit.hardware={cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),macos:execFileSync('/usr/bin/sw_vers',['-productVersion'],{encoding:'utf8'}).trim()};
 browserCDP=await context.browser().newBrowserCDPSession();
 check(audit.identity.canvas.bufferWidth===1280&&audit.identity.canvas.bufferHeight===720,'Real 1280x720 rendering buffer');check(audit.identity.gpu&&!/swiftshader|llvmpipe|software/i.test(audit.identity.gpu),'Hardware renderer');check(audit.identity.validationFixture==='undefined','No S14 fixture in ordinary page');await shot('normal');
 await phase('warmup',8);
 if(baseline){
  await phase('baseline_1x',30);await choose('speed',2);await wait(()=>window.S08.latest.speed===2);await phase('baseline_2x',10);await choose('speed',3);await wait(()=>window.S08.latest.speed===4);await phase('baseline_4x',12);
 }else{
  await button('启用声音');await wait(()=>window.S08.latest.sound);await phase('audible',10);await button('暂停');await wait(()=>window.S08.latest.paused&&window.S08.latest.sound);const before=await snap();await phase('sound_enabled_pause',3);const after=await snap();check(before.tick===after.tick&&after.sound,'Enabled sound survives pause while tick freezes');await shot('sound_paused');await button('继续');await wait(()=>!window.S08.latest.paused&&window.S08.latest.sound);
  await button('恢复信息');await wait(()=>!window.S08.latest.ui.cinema);await button('指挥态势');await wait(()=>window.S08.latest.ui.expanded&&window.S08.latest.ui.both_cards&&window.S08.latest.ui.timeline&&window.S08.latest.timeline_buttons.length>0);await shot('commands');let s=await snap();await click(s.timeline_buttons[0]);await wait(()=>window.S08.latest.ui.detail!=='选择一条指令查看各成员执行进度。');await button('定位受令编组');await button('定位任务目标');await shot('execution_detail');
  await button('指挥态势');await button('收起信息');
  s=await snap();await choose('weapon',1);await wait(()=>window.S08.latest.gallery_index===0);check((await snap()).generation===s.generation,'Weapon inspection does not reset the simulation');await shot('weapon_inspection');
  s=await snap();await choose('segment',s.modes.indexOf('train_us_axial_roll'));await wait(()=>window.S08.latest.exercise==='train_us_axial_roll'&&window.S08.latest.label.includes('完整轴向滚转'));await shot('training_selection');
  s=await snap();await choose('unit',s.popups.unit.metadata.indexOf('us_sb2c_1'));await button('跟随');await wait(()=>window.S08.latest.followed_id==='us_sb2c_1'&&window.S08.latest.camera_mode==='follow');await shot('sb2c_follow');
  for(const origin of ['follow','auto']){
   if(origin==='auto'){await button('自动电影');await wait(()=>window.S08.latest.camera_mode==='auto')}
   await focus();const drag0=await snap();await page.mouse.move(750,350);await page.mouse.down({button:'right'});await page.mouse.move(790,365,{steps:4});await sleep(250);const drag1=await snap();await page.mouse.move(830,385,{steps:4});await sleep(250);const drag2=await snap();await page.mouse.up({button:'right'});audit.interactions.push({action:'continuous_right_drag',origin,before:drag0,first:drag1,second:drag2});const expected=origin==='follow'?'follow':'free';check(drag1.camera_mode===expected&&drag2.camera_mode===expected&&drag1.yaw!==drag0.yaw&&drag2.yaw!==drag1.yaw&&(origin!=='follow'||drag2.followed_id===drag0.followed_id),'Continuous right-drag '+(origin==='follow'?'orbits followed unit':'takes over auto'));
  }
  await key('KeyC');await wait(()=>window.S08.latest.camera_mode==='auto');
  await choose('speed',0);await wait(()=>window.S08.latest.speed===.5);await phase('half_speed',4);await choose('speed',1);await wait(()=>window.S08.latest.speed===1);
  s=await snap();await choose('segment',s.modes.indexOf('fire'));await wait(()=>window.S08.latest.exercise==='fire');
  const live=await phase('natural_fire_until_live_fragment',100,true);check(live.end.fragments>0,'Natural combat produces a live fragment before restart');
  const liveGen=live.end.generation;await focus();await key('KeyR');await wait(g=>window.S08.latest.generation>g,liveGen);check((await snap()).fragments===0,'R releases live natural fragment nodes');audit.interactions.push({action:'restart_live_fragment',before:live.end,after:await snap()});
  for(let round=0;round<4;round++){
   await phase('natural_1x_round_'+round,round===0?180-live.wall_s:round<3?180:75);await shot('natural_round_'+round);if(round>0&&round<3){const old=await snap();await focus();await key('KeyR');await wait(g=>window.S08.latest.generation>g,old.generation);const current=await snap();check(current.models===19&&current.fragments===0&&current.speed===1,'R clears fragments and retains 19 models '+round);audit.interactions.push({action:'restart',before:old,after:current})}
  }
  await choose('speed',2);await wait(()=>window.S08.latest.speed===2);await phase('request_2x',10);await choose('speed',3);await wait(()=>window.S08.latest.speed===4);await phase('request_4x',12);await button('结束');await wait(()=>window.S08.latest.ended&&window.S08.latest.ui.report);await shot('report');await focus();const old=(await snap()).generation;await key('KeyR');await wait(g=>window.S08.latest.generation>g,old);check((await snap()).fragments===0,'Final restart releases remnants');
 }
 check(audit.errors.length===0,'No page exceptions');check(!audit.console.some(x=>/SCRIPT ERROR|^\s*ERROR:|WebGL.*INVALID_|shader.*error/i.test(x.text)),'No Godot or rendering errors');
 audit.peakFragments=peakFragments;audit.final=await snap();audit.passed=true;
 }
}catch(error){audit.passed=false;audit.failure=String(error.stack||error);if(page){try{audit.last=await snap();await shot('failure')}catch{}}}
finally{
 if(context){try{await context.close();audit.cleanup.chromeClosed=true}catch(e){audit.cleanup.chromeError=String(e)}}
 if(server&&server.exitCode===null){server.kill('SIGTERM');await Promise.race([new Promise(r=>server.once('exit',r)),sleep(5000)]);audit.cleanup.serverExited=server.exitCode!==null}
 await writing;await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profileRemoved=true;audit.endedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify({passed:audit.passed,phases:audit.phases.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode=audit.passed?0:1;
