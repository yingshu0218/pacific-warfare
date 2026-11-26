// Targeted protocol2 tests only. No game, HTTP, browser, export or Playwright.
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {EvidenceSink,installObserver} from './observer.mjs';

let passed=0;
async function test(name,body){await body();passed++;console.log('PASS '+name)}
function fixture(protocol=2,budget={}){
 const records=[],calls=[];let clock=0,raf;
 const sandbox={opts:{observed:true,probe:{protocol,global:'Scene',metrics_global:'Metrics'},budgets:{max_record_bytes:262144,max_wire_bytes:1048576,...budget}},TextEncoder,performance:{now:()=>clock},document:{visibilityState:'visible',hasFocus:()=>true},requestAnimationFrame:fn=>{raf=fn},WebAssembly:{Memory:class{constructor(){this.buffer=new ArrayBuffer(16)}}},_s08xWrite:async(channel,value)=>{calls.push(channel);for(const row of Array.isArray(value)?value:[value])records.push({channel,value:row})}};
 sandbox.window=sandbox;vm.createContext(sandbox);vm.runInContext('('+installObserver.toString()+')(opts)',sandbox);
 return {scene:sandbox.Scene,metrics:sandbox.Metrics,capture:sandbox.__S08X,records,calls,flush:()=>sandbox.__S08X.flush(),frame:now=>{clock=now;raf(now)}};
}
const state=(generation,extra={})=>({protocol:2,generation,tick:1,time_s:1,paused:false,speed:1,ended:'',...extra});
const delta=(generation,upserts=[],removed=[],total_orders=100,limit=48)=>({generation,upserts,removed,total_orders,limit});
const order=(id,status='executing')=>({order_id:id,status,execution:{member:{status,reason:'actual_fixture'}}});
const event=(generation,sequence,kind='fired')=>({generation,sequence,kind,time_s:1,data:{fixture:true}});

await test('Protocol2 numeric handshake, required callbacks and bounded order additions/removals',async()=>{
 const f=fixture();assert.equal(f.scene.protocol,2);for(const key of ['reset','orders_delta','receive','events'])assert.equal(typeof f.scene[key],'function');
 f.scene.reset(7);f.scene.orders_delta(delta(7,[order('a'),order('b')]));f.scene.receive(state(7));await f.flush();
 assert.deepEqual(Array.from(f.capture.orders.keys()),['a','b']);assert.equal(f.capture.latest.orders_meta.total_orders,100);assert.equal(f.capture.latest.orders_meta.cached_orders,2);
 f.scene.orders_delta(delta(7,[order('a','completed')],['b'],101));f.scene.receive(state(7,{orders:[]}));await f.flush();
 assert.deepEqual(Array.from(f.capture.orders.keys()),['a']);assert.equal(f.capture.latest.orders[0].status,'completed');assert.equal(f.capture.latest.orders_meta.total_orders,101);
 const before=f.records.filter(x=>x.channel==='orders').length;f.scene.orders_delta(delta(7,[order('a','completed')],['b'],101));await f.flush();assert.equal(f.records.filter(x=>x.channel==='orders').length,before);
 assert(f.records.some(x=>x.channel==='orders'&&x.value.removed.includes('b')&&x.value.scope==='probe-selected-order-window'));
});
await test('A full order-window replacement is atomic and repeated receive never resends history',async()=>{
 const f=fixture(),old=Array.from({length:48},(_,i)=>order('old'+i)),next=Array.from({length:48},(_,i)=>order('new'+i));
 f.scene.reset(1);f.scene.orders_delta(delta(1,old,[],96));await f.flush();
 f.scene.orders_delta(delta(1,next,old.map(x=>x.order_id),96));f.scene.receive(state(1));await f.flush();
 assert.equal(f.capture.orders.size,48);assert(!f.capture.orders.has('old0'));assert(f.capture.orders.has('new47'));
 const count=f.records.filter(x=>x.channel==='orders').length;
 for(let i=0;i<60;i++){f.scene.receive(state(1,{tick:i+2}));await f.flush()}
 assert.equal(f.records.filter(x=>x.channel==='orders').length,count);assert(!JSON.stringify(f.records).includes('history'));
 const before=Array.from(f.capture.orders.keys());f.scene.orders_delta(delta(1,[order('overflow')],[],96));assert.match(f.capture.failure,/exceeds declared window/);assert.deepEqual(Array.from(f.capture.orders.keys()),before);
});
await test('Reset clears old state/caches once; duplicate and stale resets cannot erase current data',async()=>{
 const f=fixture();f.scene.reset(1);f.scene.orders_delta(delta(1,[order('old')]));f.scene.receive(state(1));f.scene.events([event(1,9)]);f.metrics.ui(state(1));await f.flush();
 f.scene.reset(2);assert.equal(f.capture.latest,null);assert.equal(f.capture.ui,null);assert.equal(f.capture.metrics,null);assert.equal(f.capture.orders.size,0);assert.equal(f.capture.eventKeys.size,0);assert.equal(Object.keys(f.capture.tallies).length,0);assert.equal(f.capture.orderMeta.total_orders,null);await f.flush();
 f.scene.orders_delta(delta(2,[order('current')]));f.scene.receive(state(2));f.scene.events([event(2,1)]);await f.flush();
 f.scene.reset(2);f.scene.reset(1);f.scene.orders_delta(delta(1,[],['current']));f.scene.receive(state(1,{speed:4}));f.scene.events([event(1,1,'old_kind')]);await f.flush();
 assert.equal(f.capture.generation,2);assert.equal(f.capture.latest.speed,1);assert(f.capture.orders.has('current'));assert.equal(f.capture.tallies.fired,1);assert(f.capture.staleMessages>=4);
});
await test('Event identities merge metrics/scene overlap, retain out-of-order unique sequences and reject conflicting kinds',async()=>{
 const f=fixture();f.scene.reset(5);f.scene.events([event(5,30)]);await f.flush();
 assert.equal(f.metrics.accept({generation:5,events:[event(5,30),event(5,12,'damage_phase'),event(5,40,'aircraft_exit')],frames:[[240,1]]}),false);await f.flush();
 f.scene.events([event(5,12,'damage_phase')]);await f.flush();assert.equal(f.records.filter(x=>x.channel==='events').length,3);assert.equal(f.capture.tallies.damage_phase,1);
 f.scene.reset(6);f.scene.events([event(6,12,'hit')]);await f.flush();assert.equal(f.capture.tallies.hit,1);
 f.scene.events([event(6,12,'fired')]);assert.match(f.capture.failure,/Conflicting event kinds/);
});
await test('Auxiliary metrics/UI may arrive before reset acknowledgement, without leaking previous-generation orders',async()=>{
 const f=fixture();f.scene.reset(2);f.scene.orders_delta(delta(2,[order('old')]));f.scene.receive(state(2));await f.flush();
 f.metrics.ui(state(3));f.metrics.accept({generation:3,events:[event(3,1,'bomb_released')],frames:[[700,1]]});await f.flush();
 assert.equal(f.capture.latest,null);assert.equal(f.capture.orders.size,0);assert.equal(f.capture.ui.generation,3);
 f.scene.reset(3);f.scene.receive(state(3));f.scene.events([event(3,1,'bomb_released')]);await f.flush();
 assert.equal(f.capture.latest.orders.length,0);assert.equal(f.capture.tallies.bomb_released,1);assert.equal(f.capture.metrics.generation,3);
 f.metrics.ui(state(2));f.metrics.accept({generation:2,events:[],frames:[]});await f.flush();assert.equal(f.capture.ui.generation,3);assert.equal(f.capture.metrics.generation,3);
});
await test('A valid burst of 64 real sequence events uses one binding call and retains every event',async()=>{
 const f=fixture();f.scene.reset(1);await f.flush();const before=f.calls.length;
 f.scene.events(Array.from({length:64},(_,i)=>event(1,i+1)));await f.flush();
 assert.equal(f.calls.length-before,1);assert.equal(f.records.filter(x=>x.channel==='events').length,64);assert.equal(f.capture.tallies.fired,64);assert.equal(f.capture.failure,null);
});
await test('Malformed order envelopes, missing reset and invalid event sequence fail closed',async()=>{
 for(const bad of [delta(1,[order('a')],['a']),delta(1,[order('a'),order('a')]),delta(1,[],[],0,0),delta(1,[order('a')],[],0)]){
  const f=fixture();f.scene.reset(1);f.scene.orders_delta(bad);assert(f.capture.failure);assert.equal(f.capture.orders.size,0);
 }
 const missing=fixture();missing.scene.receive(state(1));assert.match(missing.capture.failure,/before reset/);
 const seq=fixture();seq.scene.reset(1);seq.scene.events([event(1,0)]);assert.match(seq.capture.failure,/Event identity/);
 const version=fixture();version.scene.reset(1);version.scene.receive({...state(1),protocol:1});assert.match(version.capture.failure,/version mismatch/);
});
await test('Protocol2 retains slow frames across reset and still stops on record/wire/backpressure limits',async()=>{
 const f=fixture();f.frame(0);f.frame(16);f.scene.reset(1);await f.flush();f.frame(716);await f.flush();
 assert(f.records.some(x=>x.channel==='frames'&&x.value.frames.some(frame=>frame.ms===700)));
 const wire=fixture(2,{max_wire_bytes:64});wire.scene.reset(1);wire.scene.receive(state(1,{text:'X'.repeat(100)}));assert.match(wire.capture.failure,/wire budget/);
 const record=fixture(2,{max_record_bytes:256});record.scene.reset(1);await record.flush();record.scene.receive(state(1,{text:'X'.repeat(1024)}));assert.match(record.capture.failure,/Record budget/);
 const pressure=fixture();pressure.scene.reset(1);await pressure.flush();for(let i=0;i<12;i++)pressure.scene.receive(state(1));assert.match(pressure.capture.failure,/backpressure/);
});
await test('NDJSON batch writing preserves one event per line and rejects an oversized batch atomically',async()=>{
 const folder=await fs.mkdtemp(path.join(os.tmpdir(),'s08x-protocol2-'));
 try{
  const sink=new EvidenceSink(folder,{max_record_bytes:128,max_queued_bytes:1024,max_evidence_bytes:4096});
  await sink.write('events',[{sequence:1},{sequence:2},{sequence:3}]);await sink.finish();
  assert.equal((await fs.readFile(path.join(folder,'events.ndjson'),'utf8')).trim().split('\n').length,3);assert.equal(sink.records,3);
  await assert.rejects(sink.write('events',[{sequence:4},{text:'X'.repeat(200)}]),/budget/);assert.equal(sink.records,3);assert.equal((await fs.readFile(path.join(folder,'events.ndjson'),'utf8')).trim().split('\n').length,3);
 }finally{await fs.rm(folder,{recursive:true,force:true})}
});
await test('Legacy receive/events and original S08 metrics/ui remain supported',async()=>{
 const f=fixture('receive-events-v1');assert.equal(f.scene.protocol,undefined);
 f.scene.receive({generation:1,orders:[order('legacy')]});f.metrics.ui({generation:1,paused:true});f.metrics.accept({generation:1,events:[event(1,1)],frames:[[55,1]]});await f.flush();
 assert.equal(f.capture.latest.orders[0].order_id,'legacy');assert.equal(f.capture.ui.paused,true);assert(f.records.some(x=>x.channel==='metrics'));assert(f.records.some(x=>x.channel==='engine_frames'&&x.value.frames[0][0]===55));
});
console.log(JSON.stringify({protocol2_synthetic_tests_passed:passed,Godot_started:false,HTTP_started:false,Chrome_started:false,export_started:false}));
