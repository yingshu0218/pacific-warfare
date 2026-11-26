/* Opt-in, same-origin observation. No game commands or simulated battle data. */
(() => {
  const query = new URLSearchParams(location.search);
  if (!query.has('measure')) return;
  const run = query.get('measure').replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 100);
  const maxSeconds = Math.min(1500, Number(query.get('limit') || 1000));
  const started = performance.now();
  let ready = false, frames = [], lastFrame = null, capture = false, serial = 0;
  const contexts = [], audioNodes = new WeakSet();
  let audioSourcesCreated=0;
  navigator.userAgentData?.getHighEntropyValues(['fullVersionList','architecture','bitness']).then(value=>post('environment',{uaData:value}));
  const post = (kind, value) => {const body=JSON.stringify(value);return fetch(`/report/${run}/${kind}`, {method:'POST', body, headers:{'Content-Type':'application/json'}}).catch(error => {originalError('S08 report transport',kind,String(error));});};
  const memories=[];
  const RealMemory=WebAssembly.Memory;
  WebAssembly.Memory=new Proxy(RealMemory,{construct(target,args){const memory=Reflect.construct(target,args);memories.push(memory);return memory;}});
  for (const name of ['instantiate','instantiateStreaming']) {
    const original=WebAssembly[name];
    if (original) WebAssembly[name]=async function(...args) {
      const result=await original.apply(WebAssembly,args);
      const exports=(result.instance || result).exports;
      for (const value of Object.values(exports || {})) if (value instanceof RealMemory && !memories.includes(value)) memories.push(value);
      return result;
    };
  }
  const environment = () => {
    const canvas = document.querySelector('canvas');
    const bounds = canvas?.getBoundingClientRect();
    return {ua:navigator.userAgent, platform:navigator.platform, dpr:devicePixelRatio,
      css:bounds ? {width:bounds.width,height:bounds.height,x:bounds.x,y:bounds.y}:null,
      buffer:canvas ? {width:canvas.width,height:canvas.height}:null,
      drawingBuffer:canvas?.getContext('webgl2') ? {width:canvas.getContext('webgl2').drawingBufferWidth,height:canvas.getContext('webgl2').drawingBufferHeight}:null,
      screen:{width:screen.width,height:screen.height}, inner:{width:innerWidth,height:innerHeight},
      visibility:document.visibilityState, hasFocus:document.hasFocus(), wall_utc:new Date().toISOString()};
  };
  window.addEventListener('error', event => post('errors', {message:event.message, filename:event.filename, line:event.lineno, wall_utc:new Date().toISOString()}));
  window.addEventListener('unhandledrejection', event => post('errors', {message:String(event.reason)}));
  const originalError = console.error.bind(console);
  console.error = (...args) => {post('console', {level:'error',args:args.map(String)});originalError(...args);};
  const originalWarn = console.warn.bind(console);
  console.warn = (...args) => {post('console', {level:'warn',args:args.map(String)});originalWarn(...args);};
  const contextClass = window.AudioContext || window.webkitAudioContext;
  const realCreateBufferSource=contextClass.prototype.createBufferSource;
  contextClass.prototype.createBufferSource=function(...args){audioSourcesCreated++;return realCreateBufferSource.apply(this,args);};
  const realConnect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function(destination, ...rest) {
    const result = realConnect.call(this, destination, ...rest);
    if (destination === this.context.destination && !audioNodes.has(this)) {
      audioNodes.add(this);
      let item = contexts.find(v => v.context === this.context);
      if (!item) {
        const context = this.context, analyser = context.createAnalyser();
        analyser.fftSize = 2048;
        const stream = context.createMediaStreamDestination();
        item = {context,analyser,stream,samples:new Float32Array(2048),recorded:false};
        contexts.push(item);
      }
      // Passive branches from the real output; audible destination stays untouched.
      realConnect.call(this, item.analyser);
      realConnect.call(this, item.stream);
    }
    return result;
  };
  function audioSnapshot() {
    return contexts.map(item => {
      item.analyser.getFloatTimeDomainData(item.samples);
      let sum = 0, peak = 0;
      for (const value of item.samples) {sum += value * value; peak = Math.max(peak, Math.abs(value));}
      if (!item.recorded && peak > 0.00001 && item.context.state === 'running' && window.MediaRecorder) {
        item.recorded = true;
        const recorder = new MediaRecorder(item.stream.stream), chunks = [];
        recorder.ondataavailable = e => {if (e.data.size) chunks.push(e.data);};
        recorder.onstop = () => {const blob = new Blob(chunks, {type:recorder.mimeType});fetch(`/report/${run}/audio`, {method:'POST',body:blob,headers:{'Content-Type':blob.type}}).catch(()=>{});};
        recorder.start();setTimeout(()=>recorder.stop(), 8000);
      }
      return {state:item.context.state, sampleRate:item.context.sampleRate, currentTime:item.context.currentTime,
        rms:Math.sqrt(sum / item.samples.length),peak,recorded:item.recorded};
    });
  }
  let audioFrames = [];
  function raf(now) {
    if (ready && lastFrame !== null) frames.push([now, now-lastFrame, document.visibilityState, document.hasFocus()]);
    if (ready && contexts.length) audioFrames.push([now,audioSnapshot()]);
    lastFrame = now;
    if ((now-started)/1000 < maxSeconds) requestAnimationFrame(raf);
  }
  requestAnimationFrame(raf);
  window.S08 = {
    accept(game) {
      ready = true;
      post('samples', {serial:serial++, now_ms:performance.now(), elapsed_s:(performance.now()-started)/1000,
        environment:environment(), raf:frames, audio:audioFrames, audio_sources_created:audioSourcesCreated, game, wasm_memory_bytes:memories.map(m=>m.buffer.byteLength),
        js_heap:performance.memory ? {used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize,limit:performance.memory.jsHeapSizeLimit}:null});
      frames=[];audioFrames=[];
      const requested = capture;capture=false;return requested;
    },
    image(base64) {post('image',{base64,serial,environment:environment()});},
    mark(label) {capture=true;post('actions',{label,now_ms:performance.now(),environment:environment()});}
  };
  document.addEventListener('DOMContentLoaded', () => {
    const button=document.createElement('button');button.textContent='保存验收截图';
    button.style='position:fixed;right:5px;top:3px;z-index:100;font-size:12px;opacity:.8';
    button.onclick=()=>window.S08.mark('manual_capture');document.body.appendChild(button);
  });
  document.addEventListener('visibilitychange',()=>post('visibility',environment()));
  document.addEventListener('pointerdown',e=>post('actions',{label:'pointerdown',button:e.button,x:e.clientX,y:e.clientY,now_ms:performance.now()}));
  document.addEventListener('keydown',e=>post('actions',{label:'keydown',key:e.code,now_ms:performance.now()}));
  post('environment', environment());
  setTimeout(async()=>{post('stop',{reason:'bounded_timeout',environment:environment()});
    try {await window.showcaseEngine?.requestQuit();} finally {location.replace('about:blank');}},maxSeconds*1000);
})();
