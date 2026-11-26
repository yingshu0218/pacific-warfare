// Use only through tools/verify.py exec. Owns one private offscreen Chrome and HTTP server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const controlledOnly=process.argv.includes('--controlled-only');
const option=(key,fallback)=>process.argv.find(v=>v.startsWith('--'+key+'='))?.slice(key.length+3)||fallback;
const out=path.resolve(root,option('evidence','docs/showcase/evidence/DM01/chrome'));
const pack=path.resolve(root,option('pack','build/dm01-web'));
const {chromium}=await import('/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'.local/dm01-chrome-'));
const audit={browserPlugin:'Browser plugin not available',browserPath:'Actual Google Chrome, headful, private offscreen profile',scope:'Bounded desktop integrated review; default battle is natural, controlled projectile cases clearly labelled; not S08 ten-minute/scale acceptance',viewport:{width:1280,height:780},checks:[],interactions:[],console:[],pageErrors:[],cleanup:{},startedUtc:new Date().toISOString()};
let context,page;
const check=(passed,name,detail=null)=>{audit.checks.push({name,passed,detail});if(!passed)throw Error(name)};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server=http.createServer(async(req,res)=>{try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(name==='/favicon.ico'){res.writeHead(204);res.end();return}const file=path.resolve(pack,'.'+name);if(!file.startsWith(pack+'/'))throw Error('outside pack');const data=await fs.readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store'});res.end(data)}catch{res.writeHead(404);res.end('not found')}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const url='http://127.0.0.1:'+server.address().port+'/index.html';audit.url=url;
try{
 audit.hardware={cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),os:os.release()};
 context=await chromium.launchPersistentContext(profile,{executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,viewport:audit.viewport,deviceScaleFactor:1,args:['--window-position=-1800,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 page=context.pages()[0]||await context.newPage();
 page.on('console',m=>{if(['warning','error'].includes(m.type()))audit.console.push({type:m.type(),text:m.text()})});
 page.on('pageerror',e=>audit.pageErrors.push(String(e)));
 await page.goto(url,{waitUntil:'load',timeout:60000});
 await page.waitForFunction(()=>window.DM01?.latest?.models===15,null,{timeout:60000});
 audit.browserVersion=await context.browser()?.version();
 audit.identity=await page.evaluate(()=>{const c=document.querySelector('canvas'),gl=c.getContext('webgl2'),e=gl.getExtension('WEBGL_debug_renderer_info'),r=c.getBoundingClientRect();return{title:document.title,url:location.href,ua:navigator.userAgent,canvas:{width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height},gpu:e?gl.getParameter(e.UNMASKED_RENDERER_WEBGL):null,webgl:gl.getParameter(gl.VERSION),visible:document.visibilityState}});
 check(audit.identity.url===url&&audit.identity.title.includes('DM01'),'Page identity');
 check(audit.identity.canvas.width===1280&&audit.identity.canvas.height===720,'1280x720 real render buffer');
 check(audit.identity.gpu&&!/swiftshader|llvmpipe|software/i.test(audit.identity.gpu),'Hardware WebGL on M5');
 const snap=()=>page.evaluate(()=>window.DM01.latest);
 const wait=async(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:20000});
 const phase=label=>page.evaluate(label=>window.DM01.phase(label),label);
 const shot=async name=>page.screenshot({path:path.join(out,name+'.png')});
 const gameClick=async point=>{const r=await page.locator('canvas').boundingBox();await page.mouse.click(r.x+point[0]*r.width/1280,r.y+point[1]*r.height/720)};
 const focusCanvas=async()=>{await gameClick([900,400]);};
 await sleep(1800);
 let state=await snap();
 check(state.models===15&&Object.keys(state.units).length===15&&state.orders>0,'Nonblank latest ground/air/ship battle and real commander UI');
 await shot('normal_ui');
 if(!controlledOnly){
 await phase('normal_1x');await sleep(5000);await phase('between');
 await focusCanvas();await page.keyboard.press('Space');await wait(()=>window.DM01.latest.paused);
 const paused=await snap();await sleep(700);const after=await snap();
 check(paused.time_s===after.time_s&&paused.environment.time_s===after.environment.time_s,'Normal Space freezes simulation and S13 time');
 await gameClick(after.speed_control);await wait(()=>window.DM01.latest.speed_popup.visible);
 const popup=(await snap()).speed_popup;
 await gameClick([popup.position[0]+popup.size[0]*.5,popup.position[1]+popup.size[1]*.875]);
 await wait(()=>window.DM01.latest.speed===4);
 await focusCanvas();await page.keyboard.press('Space');await wait(()=>!window.DM01.latest.paused);
 const speedStart=await snap(),speedWallStart=Date.now();
 await phase('normal_4x');await sleep(6000);await phase('between');
 state=await snap();const speedWallS=(Date.now()-speedWallStart)/1000;
 audit.acceleration={requested:4,simulationSeconds:state.time_s-speedStart.time_s,wallSeconds:speedWallS,achievedRate:(state.time_s-speedStart.time_s)/speedWallS,begin:speedStart,end:state};
 audit.performanceFindings=[];if(audit.acceleration.achievedRate<3.6)audit.performanceFindings.push('Requested 4x is CPU/tick-budget limited; achieved '+audit.acceleration.achievedRate.toFixed(2)+'x. This is not a 4x performance pass; hand off to S08 with production timing/backlog.');
 check(state.time_s>speedStart.time_s+2&&state.speed===4&&state.environment.time_s===state.time_s,'Requested 4x advances one consistent clock; achieved acceleration assessed separately');
 await shot('natural_damage_ui');audit.natural=state;
 const restarts=[];
 for(let i=0;i<3;i++){const old=await snap();await page.keyboard.press('KeyR');await wait(g=>window.DM01.latest.generation>g,old.generation);restarts.push(await snap());}
 check(new Set(restarts.map(s=>s.node_count)).size===1&&restarts.every(s=>s.global_fragment_nodes===0&&s.models===15),'Three normal R restarts restore geometry and stable nodes');
 audit.interactions.push({action:'Production Space, actual speed dropdown, three R restarts',snapshots:restarts});
 }
 for(const definition_id of ['us_f6f5_1944','jp_a6m5a_1944']){
  await page.selectOption('#aircraft',definition_id);
  for(const case_name of ['engine','wing_left','wing_right','breakup']){
   await page.locator('[data-case="'+case_name+'"]').click();
   await wait(v=>window.DM01.latest.mode==='controlled'&&window.DM01.latest.definition_id===v.definition_id&&window.DM01.latest.case===v.case_name,{definition_id,case_name});
   await wait(()=>window.DM01.latest.time_s>1.8);
   await phase(definition_id+'_'+case_name);await sleep(1500);await phase('between');
   state=await snap();const damage=state.target.module_data.damage;
   check(Math.abs(state.projected_center[0]-640)<2&&Math.abs(state.projected_center[1]-360)<2,'Target projects into viewport center '+definition_id+'/'+case_name,state.projected_center);
   const counts=state.event_counts;
   check(counts.fired===(case_name==='engine'?14:case_name==='breakup'?1:6)&&counts.hit>0&&counts.damaged>0,'Real fired/hit/damaged in release '+definition_id+'/'+case_name,counts);
   check(state.effects.visible_instances>0&&state.visible_effect_kinds.smoke>0,'Visible live damage smoke in release '+definition_id+'/'+case_name,state.visible_effect_kinds);
   if(case_name!=='engine')check(counts.aircraft_part_detached>0,'Real detachment event in release '+definition_id+'/'+case_name);
   if(case_name==='engine')check(state.target.active&&damage.parts.engine===0&&damage.propulsion_factor===0&&damage.aircraft.detached_parts.length===0,'Engine-only glide '+definition_id);
   else if(case_name==='breakup')check(!state.target.active&&damage.aircraft.breakup&&damage.aircraft.detached_parts.length===3,'Real severe breakup '+definition_id);
   else check(!state.target.active&&damage.aircraft.detached_parts.length===1&&damage.aircraft.detached_parts[0]===case_name&&state.model.fragment_nodes===1,'Correct detached wing '+definition_id+'/'+case_name);
   check(state.effects.render_instances<=384&&state.effects.visible_instances<=384&&state.model.fragment_nodes<=3&&state.global_fragment_nodes<=48,'Actual effects/debris allocation caps '+definition_id+'/'+case_name);
   await shot(definition_id+'_'+case_name);
   if(case_name==='wing_left'){
    await page.locator('#review-pause').click();await wait(()=>window.DM01.latest.paused);await sleep(300);await page.mouse.move(1,1);
    const begin=await snap(),imageA=await shot(definition_id+'_paused');await sleep(700);const end=await snap(),imageB=await page.screenshot();
    check(begin.tick===end.tick&&begin.environment.time_s===end.environment.time_s&&JSON.stringify(begin.target)===JSON.stringify(end.target),'Pause freezes fragment/propeller/environment '+definition_id);
    check(createHash('sha256').update(imageA).digest('hex')===createHash('sha256').update(imageB).digest('hex'),'Paused damage pixels identical '+definition_id);
    await page.selectOption('#review-speed','2');await page.locator('#review-pause').click();await wait(()=>!window.DM01.latest.paused&&window.DM01.latest.speed===2);
    const speedBefore=await snap();await sleep(550);const speedAfter=await snap();check(speedAfter.time_s-speedBefore.time_s>.7,'2x real review clock '+definition_id);
    await page.selectOption('#review-speed','1');
   }
   if(case_name==='breakup'){
    await wait(()=>window.DM01.latest.impact_count===1);await sleep(1600);state=await snap();
    check(state.surface_contact_count===1&&state.impact_count===1&&state.breakup_count===1&&state.target.module_data.damage.effect_emitters.length===0&&state.target.module_data.damage.aircraft.contact_surface==='sea','One real sea impact and no new underwater aerial emitters '+definition_id);
    check(state.event_counts.unit_surface_contact===1&&state.event_counts.unit_impact===1&&state.visible_effect_kinds.water>0&&state.visible_effect_kinds.foam>0,'Visible real-contact water and foam in release '+definition_id,state.visible_effect_kinds);
    await shot(definition_id+'_water');
   }
   audit.interactions.push({action:'Controlled production-projectile '+definition_id+'/'+case_name,state:await snap()});
   await page.locator('#review-reset').click();await wait(()=>window.DM01.latest.time_s<.8&&window.DM01.latest.target.active&&window.DM01.latest.model.fragment_nodes===0);
   check((await snap()).target.module_data.damage.aircraft.detached_parts.length===0,'Review reset restores approved full model '+definition_id+'/'+case_name);
  }
 }
 audit.data=await page.evaluate(()=>window.DM01.data);
 const samples=audit.data.raf.filter(v=>v.phase!=='between'&&v.phase!=='loading');
 const summary={};for(const name of new Set(samples.map(v=>v.phase))){const ms=samples.filter(v=>v.phase===name).map(v=>v.ms).sort((a,b)=>a-b);const mean=ms.reduce((a,b)=>a+b,0)/ms.length;summary[name]={frames:ms.length,meanMs:mean,p95Ms:ms[Math.min(ms.length-1,Math.floor(ms.length*.95))],maxMs:ms.at(-1),meanFps:1000/mean};}audit.frameSummary=summary;
 check(audit.pageErrors.length===0,'No browser runtime errors');
 check(!audit.console.some(v=>/shader error|shader compilation|SCRIPT ERROR|^\s*ERROR:|WebGL.*INVALID_/i.test(v.text)),'No Godot/shader/WebGL error overlay or diagnostics');
 audit.passed=true;
}catch(error){audit.passed=false;audit.failure=String(error?.stack||error);if(page){try{audit.last=await page.evaluate(()=>window.DM01?.latest);audit.data=await page.evaluate(()=>window.DM01?.data);await page.screenshot({path:path.join(out,'failure.png')})}catch{}}}
finally{
 if(context){try{await context.close();audit.cleanup.chromeClosed=true}catch(e){audit.cleanup.chromeError=String(e)}}
 await new Promise(r=>server.close(r));audit.cleanup.serverClosed=true;await fs.rm(profile,{recursive:true,force:true});audit.cleanup.profileRemoved=true;audit.endedUtc=new Date().toISOString();await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify({passed:audit.passed,checks:audit.checks.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode=audit.passed?0:1;
