// Run only through tools/verify.py exec; owns a private Chrome profile and server.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const controlsOnly = process.argv.includes("--controls-only");
const fogReview = process.argv.includes("--fog-review");
const option = (name, fallback) => process.argv.find(value=>value.startsWith('--' + name + '='))?.slice(name.length + 3) || fallback;
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const out = path.resolve(root, option('evidence-dir', 'docs/showcase/evidence/S13/chrome'));
const pack = path.resolve(root, option('pack-dir', 'build/s13-web'));
const {chromium} = await import(process.env.S13_PLAYWRIGHT || '/Users/infinity/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
await fs.mkdir(out, {recursive:true});
const profile = await fs.mkdtemp(path.join(root, '.local/s13-chrome-'));
const audit = {browserPath:'Google Chrome, private profile, headful', browserPlugin:'Browser plugin not available',
  viewport:{width:1280,height:720}, deviceScaleFactor:1, controlsOnly, checks:[], interactions:[], measurements:[],
  console:[], pageErrors:[], startedUtc:new Date().toISOString(), cleanup:{}};
let context, page, commandId = 0;
const check = (passed, name, detail=null) => {audit.checks.push({name,passed,detail});if (!passed) throw Error(name);};
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const mime = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server = http.createServer(async (req, res) => {
  try {
    const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (name === '/favicon.ico') {res.writeHead(204);res.end();return;}
    const target = path.resolve(pack, '.' + name);
    if (!target.startsWith(pack + '/')) throw Error('outside pack');
    const bytes = await fs.readFile(target);
    res.writeHead(200, {'Content-Type':mime[path.extname(target)] || 'application/octet-stream','Cache-Control':'no-store'});
    res.end(bytes);
  } catch {res.writeHead(404);res.end('not found');}
});
await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
const url = 'http://127.0.0.1:' + server.address().port + '/index.html';
audit.url = url;
try {
  audit.hardware = {
    cpu:execFileSync('/usr/sbin/sysctl',['-n','machdep.cpu.brand_string'],{encoding:'utf8'}).trim(),
    memoryBytes:Number(execFileSync('/usr/sbin/sysctl',['-n','hw.memsize'],{encoding:'utf8'})),
    os:os.release(), node:process.version,
  };
  context = await chromium.launchPersistentContext(profile, {
    executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless:false, viewport:{width:1280,height:720}, deviceScaleFactor:1,
    args:['--window-position=-1600,0','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows'],
  });
  audit.launchFlags = ['headful','private user-data-dir','offscreen position','background/occlusion throttling disabled equally for all comparisons'];
  page = context.pages()[0] || await context.newPage();
  page.on('console', message => {if (['warning','error'].includes(message.type())) audit.console.push({type:message.type(),text:message.text()});});
  page.on('pageerror', error => audit.pageErrors.push(String(error)));
  await page.goto(url, {waitUntil:'load',timeout:60000});
  await page.waitForFunction(() => window.S13?.latest?.game_children > 0, null, {timeout:60000});
  audit.browserVersion = await context.browser()?.version();
  audit.identity = await page.evaluate(() => {
    const c=document.querySelector('canvas'), gl=c.getContext('webgl2'), ext=gl.getExtension('WEBGL_debug_renderer_info'), rect=c.getBoundingClientRect();
    return {title:document.title,url:location.href,ua:navigator.userAgent,
      canvas:{width:c.width,height:c.height,cssWidth:rect.width,cssHeight:rect.height},
      webgl:gl.getParameter(gl.VERSION),gpu:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,
      visible:document.visibilityState,focused:document.hasFocus()};
  });
  check(audit.identity.url === url && audit.identity.title.includes('S13'), 'page identity');
  check(audit.identity.canvas.width === 1280 && audit.identity.canvas.height === 720, '1280x720 actual render buffer');
  check(audit.identity.gpu && !/swiftshader|llvmpipe|software/i.test(audit.identity.gpu), 'hardware accelerated WebGL');
  const snap = () => page.evaluate(() => window.S13.latest);
  const command = async (kind, value) => {
    const id = ++commandId;
    await page.evaluate(c => window.S13.commands.push(c), {kind,value,id});
    await page.waitForFunction(id => window.S13.latest.command_id >= id, id, {timeout:10000});
    return snap();
  };
  const shot = async (label, name=label) => {
    await command('shot', label);
    await sleep(350);
    await page.screenshot({path:path.join(out,name + '.png')});
  };
  const sample = async (label, seconds) => {
    if (controlsOnly) return;
    await page.evaluate(label => window.S13.phase(label + '_warmup'),label);
    await sleep(1500);
    await page.evaluate(label => window.S13.phase(label),label);
    const begin = await snap();
    await sleep(seconds * 1000);
    const end = await snap();
    audit.measurements.push({label,requestedSeconds:seconds,begin,end});
    await page.evaluate(() => window.S13.phase('between'));
    console.log('S13 measured',label,seconds + 's');
  };
  // Actual entry renders the production game, its units, terrain and normal HUD.
  await shot('ship_low','normal_ui');
  check((await snap()).environment.sky_time_s === (await snap()).environment.water_time_s, 'live sky and sea clocks agree');
  await page.keyboard.press('KeyH'); // Real cinema control.
  await sleep(300);
  await shot('ship_low');
  await sample('new_live_ship',fogReview ? 8 : 15);
  await shot('air_high');
  await sample('new_live_air',fogReview ? 8 : 10);
  await shot('harbor');
  await shot('far_edge');
  await shot('sky');
  // Real Space and dropdown events exercise normal production control paths.
  await page.keyboard.press('Space');
  await page.waitForFunction(() => window.S13.latest.paused);
  await sleep(1000); // Let the normal UI refresh complete before pixel comparison.
  const pausedBefore = await snap();
  await page.mouse.move(1,1);
  const first = await page.screenshot({path:path.join(out,'paused_sky.png')});
  await sleep(1200);
  const second = await page.screenshot();
  const pausedAfter = await snap();
  check(pausedBefore.sim_s === pausedAfter.sim_s && pausedBefore.environment.time_s === pausedAfter.environment.time_s, 'Space freezes simulation and both materials');
  check(createHash('sha256').update(first).digest('hex') === createHash('sha256').update(second).digest('hex'), 'paused sky/sea pixels remain identical');
  audit.interactions.push({action:'Space pause',before:pausedBefore,after:pausedAfter});
  await command('shot','ship_low');
  if (!fogReview) {
  await command('visual','legacy');
  await sample('legacy_paused',10);
  await page.screenshot({path:path.join(out,'legacy_same_world.png')});
  await command('visual','new');
  await sample('new_paused',10);
  await page.screenshot({path:path.join(out,'new_same_world.png')});
  await command('visual','no_clouds');
  await sample('new_no_clouds_paused',8);
  await command('visual','new');
  await command('environment_only',true);
  await sample('new_environment_only',8);
  await command('environment_only',false);
  }
  await page.keyboard.press('KeyH');
  await sleep(300);
  const controlState = await snap();
  await page.mouse.click(...controlState.speed_control);
  await page.waitForFunction(() => window.S13.latest.speed_popup.visible);
  await page.screenshot({path:path.join(out,'speed_popup.png')});
  const popup = (await snap()).speed_popup;
  await page.mouse.click(popup.position[0] + popup.size[0] * .5, popup.position[1] + popup.size[1] * .875);
  await page.waitForFunction(() => window.S13.latest.speed === 4);
  await page.keyboard.press('Space');
  await page.waitForFunction(() => !window.S13.latest.paused);
  const speedBegin = await snap();
  await sleep(1200);
  const speedEnd = await snap();
  check(speedEnd.environment.time_s > speedBegin.environment.time_s && speedEnd.environment.time_s === speedEnd.sim_s, '4x dropdown resumes a shared simulation clock');
  audit.interactions.push({action:'Actual dropdown popup click last item -> 4x -> Space resume',before:speedBegin,after:speedEnd});
  const resourceIds = [speedEnd.environment.sky_id,speedEnd.environment.water_id];
  const counts = [];
  for (let index=0; index<3; index++) {
    const old = await snap();
    await page.keyboard.press('KeyR');
    await page.waitForFunction(generation => window.S13.latest.generation > generation,old.generation);
    const current = await snap();
    check(current.sim_s < 1 && current.environment.time_s === current.sim_s, 'restart resets cloud and sea phase ' + index);
    check(current.environment.sky_id === resourceIds[0] && current.environment.water_id === resourceIds[1], 'restart retains material resources ' + index);
    counts.push(current);
  }
  check(new Set(counts.map(v=>v.game_children)).size === 1 && new Set(counts.map(v=>v.node_count)).size === 1, 'three restarts keep node counts stable');
  audit.interactions.push({action:'Three actual R restarts',snapshots:counts});
  await page.screenshot({path:path.join(out,'after_restarts.png')});
  audit.data = await page.evaluate(() => window.S13.data);
  check(audit.pageErrors.length === 0, 'no page runtime errors');
  check(!audit.console.some(v=>/shader error|shader compilation|SCRIPT ERROR|^\s*ERROR:|WebGL.*INVALID_/i.test(v.text)), 'no Godot/shader/WebGL errors');
  audit.passed = true;
} catch (error) {
  audit.passed = false;
  audit.failure = String(error?.stack || error);
  if (page) {
    try {audit.data = await page.evaluate(() => window.S13?.data);await page.screenshot({path:path.join(out,'failure.png')});} catch {}
  }
} finally {
  if (context) {
    try {await context.close();audit.cleanup.chromeClosed=true;} catch(error) {audit.cleanup.chromeError=String(error);}
  }
  await new Promise(resolve => server.close(resolve));
  audit.cleanup.serverClosed = true;
  await fs.rm(profile,{recursive:true,force:true});
  audit.cleanup.profileRemoved = true;
  audit.endedUtc = new Date().toISOString();
  await fs.writeFile(path.join(out,'run.json'),JSON.stringify(audit,null,2));
  console.log(JSON.stringify({passed:audit.passed,checks:audit.checks.length,failure:audit.failure,cleanup:audit.cleanup}));
}
process.exitCode = audit.passed ? 0 : 1;
