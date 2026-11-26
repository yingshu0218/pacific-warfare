// Isolated acceptance observer. No simulation setters, game commands, or eval.
import fs from 'node:fs/promises';
import path from 'node:path';

export class EvidenceSink {
 constructor(directory, budgets) { this.directory=directory;this.budgets=budgets;this.bytes=0;this.queued=0;this.records=0;this.tail=Promise.resolve();this.failure=null; }
 write(channel, value) {
  if(this.failure) return Promise.reject(new Error(this.failure));
  if(!/^[a-z_]+$/.test(channel)) return Promise.reject(new Error('Invalid evidence channel'));
  const rows=Array.isArray(value)?value:[value],lines=rows.map(row=>JSON.stringify(row)+'\n');
  const line=lines.join(''), bytes=Buffer.byteLength(line);
  if(lines.some(row=>Buffer.byteLength(row)>this.budgets.max_record_bytes)||this.queued+bytes>this.budgets.max_queued_bytes||this.bytes+bytes>this.budgets.max_evidence_bytes) {
   this.failure='Evidence budget exceeded; run is incomplete, no frames silently discarded';
   return Promise.reject(new Error(this.failure));
  }
  this.bytes+=bytes;this.queued+=bytes;this.records+=rows.length;
  const job=this.tail.then(()=>fs.appendFile(path.join(this.directory,channel+'.ndjson'),line));
  this.tail=job.catch(error=>{this.failure=String(error)}).finally(()=>{this.queued-=bytes});
  return job;
 }
 async finish() { await this.tail;if(this.failure)throw Error(this.failure);return {bytes:this.bytes,records:this.records,queue_bytes:this.queued}; }
}

// Passed verbatim to addInitScript/evaluate. No imports or external variables.
export function installObserver(options) {
 const {observed,probe,budgets,audioEnabled=false}=options,protocol=probe.protocol;
 const capture={latest:null,metrics:null,ui:null,phase:'loading',receivedAt:null,failure:null,tallies:{},orders:new Map(),eventKeys:new Map(),generation:null,resetGeneration:null,orderMeta:{total_orders:null,limit:null},staleMessages:0};
 let frames=[],audio=[],previous=null,pending=new Set(),lastFlush=performance.now(),stopped=false;
 const omitted=new Set(['history','journal']);
 const compact=value=>{
  if(Array.isArray(value))return value.map(compact);
  if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).filter(([key])=>!omitted.has(key)).map(([key,item])=>[key,compact(item)]));
  return value;
 };
 function fatal(error) {capture.failure=String(error);stopped=true;}
 function emit(channel,value) {
  if(stopped)return;
  const many=Array.isArray(value),rows=(many?value:[value]).map(row=>({browser_ms:performance.now(),phase:capture.phase,...row}));
  if(rows.some(row=>new TextEncoder().encode(JSON.stringify(row)).byteLength>budgets.max_record_bytes)){fatal('Record budget exceeded; incomplete evidence');return}
  if(pending.size>=8){fatal('Browser evidence backpressure; incomplete evidence');return}
  let job;job=window._s08xWrite(channel,many?rows:rows[0]).catch(fatal).finally(()=>pending.delete(job));pending.add(job);
 }
 function boundedWire(value) {
  const size=new TextEncoder().encode(JSON.stringify(value)).byteLength;
  if(size>budgets.max_wire_bytes){fatal('Probe wire budget exceeded; compact S14 contract required');return false}
  return true;
 }
 function generation(value,source,requireReset=false) {
  if(!Number.isSafeInteger(value)||value<0){fatal('Invalid generation from '+source);return false}
  if(capture.generation!==null&&value<capture.generation){
   capture.staleMessages++;if(capture.staleMessages<=8)emit('protocol',{event:'stale_message',source,generation:value,current_generation:capture.generation});return false;
  }
  if(value!==capture.generation){
   capture.generation=value;capture.resetGeneration=null;capture.orders.clear();capture.eventKeys.clear();capture.tallies={};
   capture.orderMeta={total_orders:null,limit:null};capture.latest=null;capture.metrics=null;capture.ui=null;capture.receivedAt=null;
   emit('protocol',{event:'generation',generation:value,source});
  }
  if(requireReset&&capture.resetGeneration!==value){fatal('Protocol2 scene message before reset');return false}
  return true;
 }
 function reset(value) {
  if(stopped||!generation(value,'reset')||capture.resetGeneration===value)return;
  capture.resetGeneration=value;emit('protocol',{event:'reset',generation:value});
 }
 function events(rows,source,fallback=null) {
  if(stopped||!Array.isArray(rows)){if(!stopped)fatal('Invalid event batch');return}
  const accepted=[];
  for(const event of rows){
   const gen=event.generation??(source==='metrics'?fallback:protocol===2?undefined:capture.generation);
   if(!generation(gen,source,protocol===2&&source==='scene')){if(stopped)return;continue}
   if(!Number.isSafeInteger(event.sequence)||event.sequence<=0||typeof event.kind!=='string'||!event.kind){fatal('Event identity missing; final event adapter required');return}
   const key=event.sequence;
   if(capture.eventKeys.has(key)){
    if(capture.eventKeys.get(key)!==event.kind){fatal('Conflicting event kinds for one generation/sequence');return}
    continue;
   }
   if(capture.eventKeys.size>=32768){fatal('Event identity budget exceeded; incomplete evidence');return}
   capture.eventKeys.set(key,event.kind);capture.tallies[event.kind]=(capture.tallies[event.kind]||0)+1;
   accepted.push({source,generation:gen,event:{...compact(event),generation:gen}});
  }
  if(accepted.length)emit('events',accepted.length===1?accepted[0]:accepted);
 }
 function orderView() {
  if(capture.latest){capture.latest.orders=Array.from(capture.orders.values());capture.latest.orders_meta={...capture.orderMeta,cached_orders:capture.orders.size}}
 }
 function ordersDelta(value) {
  if(stopped||!boundedWire(value)||!generation(value.generation,'orders_delta',true))return;
  const {upserts,removed,total_orders:total,limit}=value;
  if(!Array.isArray(upserts)||!Array.isArray(removed)||!Number.isSafeInteger(total)||total<0||!Number.isSafeInteger(limit)||limit<=0||limit>4096||upserts.length>limit||removed.length>4096){fatal('Invalid protocol2 order delta or limit');return}
  const changed=compact(upserts),ids=changed.map(order=>order.order_id);
  if(ids.some(id=>typeof id!=='string'||!id)||removed.some(id=>typeof id!=='string'||!id)||new Set(ids).size!==ids.length||new Set(removed).size!==removed.length||removed.some(id=>ids.includes(id))){fatal('Ambiguous protocol2 order delta');return}
  const next=new Map(capture.orders);let dirty=total!==capture.orderMeta.total_orders||limit!==capture.orderMeta.limit;
  for(const id of removed){if(next.delete(id))dirty=true}
  for(const order of changed){if(JSON.stringify(next.get(order.order_id))!==JSON.stringify(order)){dirty=true;next.set(order.order_id,order)}}
  if(next.size>limit||next.size>total){fatal('Protocol2 order cache exceeds declared window');return}
  capture.orders=next;capture.orderMeta={total_orders:total,limit};orderView();
  if(dirty)emit('orders',{generation:value.generation,type:'delta',upserts:changed,removed,total_orders:total,limit,scope:'probe-selected-order-window'});
 }
 function receive(value) {
  if(stopped||!boundedWire(value))return;
  if(protocol===2&&value.protocol!==2){fatal('Protocol2 state version mismatch');return}
  if(!generation(value.generation,'receive',protocol===2))return;
  const state=compact(value);capture.latest=state;capture.receivedAt=performance.now();
  if(protocol===2)orderView();
  else for(const order of state.orders||[]){
   const id=order.order_id;if(!id){fatal('Order identity missing');return}
   if(JSON.stringify(capture.orders.get(id))!==JSON.stringify(order)){capture.orders.set(id,order);emit('orders',{generation:capture.generation,order})}
  }
  if(capture.orders.size>4096){fatal('Order cache budget exceeded');return}
  const {orders,journal,events:ignored,...snapshot}=state;
  emit('states',{state:snapshot,order_count:(orders||[]).length});
 }
 const memories=[],contexts=[];let created=0,recorded=false;
 if(observed){
  if(!/^[A-Za-z_$][\w$]*$/.test(probe.global)||!/^[A-Za-z_$][\w$]*$/.test(probe.metrics_global)){throw Error('Unsafe bridge identifier')}
  if(protocol!==2&&protocol!=='receive-events-v1')throw Error('Unbound or unsupported observer protocol');
  window[probe.global]={...(protocol===2?{protocol:2,reset,orders_delta:ordersDelta}:{}),receive,events(rows){if(!stopped&&boundedWire(rows))events(rows,'scene')}};
  window[probe.metrics_global]={ui(value){if(!stopped&&boundedWire(value)&&generation(value.generation,'ui'))capture.ui=compact(value)},image(){},accept(value){
   if(stopped||!boundedWire(value)||!generation(value.generation,'metrics'))return false;
   events(value.events||[],'metrics',value.generation);if(stopped||capture.generation!==value.generation)return false;
   const {events:ignored,frames:engineFrames,...game}=compact(value);capture.metrics=game;
   emit('metrics',{game,wasm_bytes:memories.map(m=>m.buffer.byteLength)});
   if(engineFrames?.length)emit('engine_frames',{generation:game.generation,frames:engineFrames});
   return false;
  }};
  const RealMemory=WebAssembly.Memory;
  WebAssembly.Memory=new Proxy(RealMemory,{construct(target,args){const value=Reflect.construct(target,args);memories.push(value);return value}});
  for(const method of ['instantiate','instantiateStreaming']){
   const original=WebAssembly[method];if(!original)continue;
   WebAssembly[method]=async function(...args){const result=await original.apply(WebAssembly,args);for(const value of Object.values((result.instance||result).exports||{}))if(value instanceof RealMemory&&!memories.includes(value))memories.push(value);return result};
  }
 }
 if(audioEnabled){
  const Audio=window.AudioContext||window.webkitAudioContext;
  const makeSource=Audio.prototype.createBufferSource;
  Audio.prototype.createBufferSource=function(...args){created++;return makeSource.apply(this,args)};
  const connect=AudioNode.prototype.connect,seen=new WeakSet();
  AudioNode.prototype.connect=function(destination,...rest){
   const result=connect.call(this,destination,...rest);
   if(destination===this.context.destination&&!seen.has(this)){
    seen.add(this);let item=contexts.find(x=>x.ctx===this.context);
    if(!item){const ctx=this.context,analyser=ctx.createAnalyser();analyser.fftSize=2048;item={ctx,analyser,stream:ctx.createMediaStreamDestination(),data:new Float32Array(2048)};contexts.push(item)}
    connect.call(this,item.analyser);connect.call(this,item.stream);
   }return result;
  };
 }
 function flush() {
  if(frames.length)emit('frames',{frames:frames.splice(0),js_heap_bytes:performance.memory?.usedJSHeapSize??null});
  if(audio.length)emit('audio',{samples:audio.splice(0),native_sources_created:created});
 }
 function raf(now) {
  if(stopped)return;
  if(previous!==null)frames.push({at:now,ms:now-previous,phase:capture.phase,visible:document.visibilityState,focused:document.hasFocus()});previous=now;
  for(const item of contexts){
   item.analyser.getFloatTimeDomainData(item.data);let sum=0,peak=0;
   for(const value of item.data){sum+=value*value;peak=Math.max(peak,Math.abs(value))}
   audio.push({at:now,phase:capture.phase,state:item.ctx.state,time:item.ctx.currentTime,rms:Math.sqrt(sum/item.data.length),peak});
   if(!recorded&&peak>1e-5&&item.ctx.state==='running'){
    recorded=true;const recorder=new MediaRecorder(item.stream.stream),parts=[];let bytes=0;
    recorder.ondataavailable=event=>{bytes+=event.data.size;if(bytes>2*1024*1024){fatal('Audio evidence budget exceeded');return}parts.push(event.data)};
    recorder.onstop=async()=>{try{const data=new Uint8Array(await new Blob(parts).arrayBuffer());let text='';for(let i=0;i<data.length;i+=32768)text+=String.fromCharCode(...data.subarray(i,i+32768));await window._s08xAudio({base64:btoa(text),mime:recorder.mimeType})}catch(error){fatal(error)}};
    recorder.start();setTimeout(()=>{if(recorder.state==='recording')recorder.stop()},8000);
   }
  }
  if(now-lastFlush>=1000){flush();lastFlush=now}
  if(frames.length>1000||audio.length>4000){fatal('Frame/audio buffer exceeded; incomplete evidence');return}
  requestAnimationFrame(raf);
 }
 capture.flush=async()=>{flush();while(pending.size)await Promise.all([...pending]);if(capture.failure)throw Error(capture.failure)};
 capture.setPhase=value=>{capture.phase=value};
 window.__S08X=capture;requestAnimationFrame(raf);
}

export function at(value, pointer) {
 return pointer.split('.').reduce((item,key)=>item?.[key],value);
}

export function matches(value, condition) {
 const actual=at(value,condition.path),expected=condition.value;
 switch(condition.op){
  case 'eq':return JSON.stringify(actual)===JSON.stringify(expected);
  case 'gte':return typeof actual==='number'&&actual>=expected;
  case 'gt':return typeof actual==='number'&&actual>expected;
  case 'contains':return typeof actual==='string'&&actual.includes(expected);
  case 'truthy':return !!actual;
  case 'falsy':return actual!==undefined&&!actual;
  default:throw Error('Unknown assertion operator; no arbitrary code is evaluated');
 }
}

export function menuIndex(popup, step) {
 const rows=step.label?popup.labels:popup.metadata;
 if(!Array.isArray(rows)||rows.length!==popup.count)throw Error('Final menu labels/metadata unavailable');
 const wanted=step.label??step.metadata,indices=rows.map((value,index)=>value===wanted?index:-1).filter(index=>index>=0);
 if(indices.length!==1)throw Error('Final menu value missing or ambiguous: '+wanted);
 return indices[0];
}

export function menuPoint(popup, index) {
 const height=popup.row_height,top=popup.padding_top,bottom=popup.padding_bottom;
 if(![height,top,bottom,...popup.position,...popup.size].every(Number.isFinite)||height<=0)throw Error('Final popup geometry unavailable');
 const content=popup.count*height+top+bottom,scroll=Math.max(0,content-popup.size[1]);
 const fromBottom=index*height>=scroll,offset=fromBottom?scroll:0;
 const y=popup.position[1]+top+(index+.5)*height-offset;
 if(y<=popup.position[1]||y>=popup.position[1]+popup.size[1])throw Error('Item not reachable with measured popup scroll');
 return {point:[popup.position[0]+popup.size[0]*.5,y],wheel:fromBottom?2400:-2400};
}
