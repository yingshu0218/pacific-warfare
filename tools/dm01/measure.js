/* Isolated review controls and passive real-frame timing; never present in Showcase. */
(()=>{
 const data={raf:[],snapshots:[],phase:'loading',productionSamples:[]};let last=null,sequence=0;
 window.DM01={commands:[],latest:null,data,phase(value){data.phase=value},
 accept(value){this.latest=value;data.snapshots.push({now:performance.now(),phase:data.phase,...value})},
 command(kind,value=null){const id=++sequence;this.commands.push({kind,value,id});return id}};
 window.S08={accept(value){data.productionSamples.push({now:performance.now(),phase:data.phase,...value});return false}};
 requestAnimationFrame(function frame(now){if(last!==null&&window.DM01.latest)data.raf.push({now,ms:now-last,phase:data.phase,visible:document.visibilityState,focused:document.hasFocus()});last=now;requestAnimationFrame(frame)});
 addEventListener('DOMContentLoaded',()=>{
  const controls=document.createElement('div');controls.id='dm-controls';
  controls.style.cssText='position:fixed;bottom:0;left:0;right:0;padding:6px;display:flex;gap:5px;justify-content:center;background:#182a34;color:#fff;font:12px sans-serif;z-index:10';
  controls.innerHTML='<button id="normal">Default battle</button><span>Controlled projectiles:</span><select id="aircraft"><option value="us_f6f5_1944">F6F-5</option><option value="jp_a6m5a_1944">A6M5a</option></select><button data-case="engine">Engine</button><button data-case="wing_left">Left wing</button><button data-case="wing_right">Right wing</button><button data-case="breakup">Breakup/water</button><button id="review-pause">Pause review</button><select id="review-speed"><option value="1">1× review</option><option value="2">2× review</option></select><button id="review-reset">Reset review</button>';
  document.body.append(controls);
  controls.querySelector('#normal').onclick=()=>window.DM01.command('normal');
  controls.querySelectorAll('[data-case]').forEach(b=>b.onclick=()=>window.DM01.command('review',{definition_id:controls.querySelector('#aircraft').value,case:b.dataset.case}));
  controls.querySelector('#review-pause').onclick=()=>window.DM01.command('review_pause');
  controls.querySelector('#review-reset').onclick=()=>window.DM01.command('review_restart');
  controls.querySelector('#review-speed').onchange=e=>window.DM01.command('review_speed',Number(e.target.value));
 });
})();
