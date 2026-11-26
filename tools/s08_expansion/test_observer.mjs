// Node-only synthetic tests. No Playwright, Chrome, HTTP, Godot or export.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {EvidenceSink,installObserver,matches,menuIndex,menuPoint} from './observer.mjs';
import {heldByParent} from './run_chrome.mjs';

let tests=0;
const test=async(name,fn)=>{await fn();tests++;console.log('PASS '+name)};
const folder=await fs.mkdtemp(path.join(os.tmpdir(),'s08x-synthetic-'));
try{
 await test('Final visible menu lookup is independent of candidate indices',()=>{
  const popup={count:3,labels:['B','A','C'],metadata:['b','a','c']};
  assert.equal(menuIndex(popup,{label:'A'}),1);assert.equal(menuIndex(popup,{metadata:'c'}),2);
  assert.throws(()=>menuIndex({...popup,labels:['A','A','C']},{label:'A'}),/ambiguous/);
  const p={count:32,position:[24,100],size:[310,580],row_height:28,padding_top:6,padding_bottom:6};
  assert(menuPoint(p,31).point[1]<680);assert(menuPoint(p,0).point[1]>100);
 });
 await test('Conditions do not execute arbitrary JavaScript',()=>{
  assert(matches({state:{speed:1}},{path:'state.speed',op:'eq',value:1}));
  assert(!matches({state:{}},{path:'state.ended',op:'falsy'}));
  assert.throws(()=>matches({}, {path:'x',op:'eval',value:'throw 1'}),/Unknown/);
 });
 await test('Evidence stream reports byte pressure instead of discarding frames',async()=>{
  const sink=new EvidenceSink(folder,{max_record_bytes:128,max_queued_bytes:256,max_evidence_bytes:256});
  await sink.write('frames',{ms:240});await assert.rejects(sink.write('frames',{text:'X'.repeat(200)}),/budget/);await assert.rejects(sink.finish(),/budget/);
  assert((await fs.readFile(path.join(folder,'frames.ndjson'),'utf8')).includes('240'));
 });
 await test('Shared verification lock must belong to the actual parent',async()=>{
  const file=path.join(folder,'lock.json');await fs.writeFile(file,JSON.stringify({status:'held',owner:'S08-test',pid:42}));
  await heldByParent(file,42);await assert.rejects(heldByParent(file,43),/direct child/);
 });
 await test('Only current state and changed orders are archived; event and generation identities remain real',async()=>{
  const records=[];let clock=0,raf;
  const sandbox={opts:{observed:true,probe:{protocol:'receive-events-v1',global:'FinalScene',metrics_global:'FinalMetrics'},budgets:{max_record_bytes:262144,max_wire_bytes:1048576}},TextEncoder,performance:{now:()=>clock},document:{visibilityState:'visible',hasFocus:()=>true},requestAnimationFrame:fn=>{raf=fn},WebAssembly:{Memory:class{constructor(){this.buffer=new ArrayBuffer(16)}}},_s08xWrite:async(channel,value)=>records.push({channel,value})};
  sandbox.window=sandbox;vm.createContext(sandbox);vm.runInContext('('+installObserver.toString()+')(opts)',sandbox);
  const event={generation:1,sequence:9,kind:'fixture_event',data:{actual:true}};
  sandbox.FinalScene.events([event]);sandbox.FinalScene.receive({generation:1,tick:1,orders:[{order_id:'fixture',status:'executing',history:Array(100).fill('X'.repeat(256))}],journal:Array(100).fill({repeated:true})});await sandbox.__S08X.flush();
  for(let i=0;i<100;i++){clock+=250;sandbox.FinalScene.receive({generation:1,tick:i+2,orders:[{order_id:'fixture',status:'executing',history:Array(100).fill('X'.repeat(256))}],journal:Array(100).fill({repeated:true})});sandbox.FinalScene.events([event]);await sandbox.__S08X.flush()}
  assert.equal(records.filter(x=>x.channel==='orders').length,1);assert.equal(records.filter(x=>x.channel==='events').length,1);assert.equal(sandbox.__S08X.tallies.fixture_event,1);
  assert(!JSON.stringify(records).includes('history'));assert(!JSON.stringify(records).includes('journal'));
  sandbox.FinalScene.events([{...event,generation:2}]);sandbox.FinalScene.receive({generation:2,orders:[]});await sandbox.__S08X.flush();assert.equal(sandbox.__S08X.tallies.fixture_event,1);
  raf(1000);raf(1240);raf(1256);await sandbox.__S08X.flush();assert(records.some(x=>x.channel==='frames'&&x.value.frames.some(f=>f.ms===240)));
  for(let i=0;i<20;i++)sandbox.FinalScene.receive({generation:2,orders:[]});assert.match(sandbox.__S08X.failure,/backpressure/);
 });
 console.log(JSON.stringify({synthetic_tests_passed:tests,Godot_started:false,Chrome_started:false,HTTP_started:false}));
}finally{await fs.rm(folder,{recursive:true,force:true})}
