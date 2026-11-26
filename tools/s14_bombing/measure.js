window.S14X={protocol:2,latest:null,generation:-1,orderMap:new Map(),lastEventSequence:0,lastArchive:-Infinity,data:{snapshots:[],order_changes:[],events:[],raf:[],samples:[],phase:'loading'},
 reset(generation){if(this.generation===generation)return;this.generation=generation;this.orderMap.clear();this.lastEventSequence=0;this.data.order_changes.push({reset:true,generation,now:performance.now()});},
 orders_delta(delta){this.reset(delta.generation);for(const id of delta.removed)this.orderMap.delete(id);for(const row of delta.upserts)this.orderMap.set(row.order_id,row);this.data.order_changes.push({now:performance.now(),...delta});if(this.latest?.generation===delta.generation)this.latest.orders=[...this.orderMap.values()];},
 receive(state){this.reset(state.generation);this.latest={...state,orders:[...this.orderMap.values()]};const now=performance.now();if(now-this.lastArchive<500)return;this.lastArchive=now;this.data.snapshots.push({now,phase:this.data.phase,...state,order_ids:[...this.orderMap.keys()]});},
 events(rows){for(const row of rows){this.reset(row.generation);if(row.sequence<=this.lastEventSequence)continue;this.lastEventSequence=row.sequence;this.data.events.push(row);}},
 phase(value){this.data.phase=value;}
};
window.S08={ui(){},image(){},accept(value){const {events,...sample}=value;window.S14X.data.samples.push({now:performance.now(),phase:window.S14X.data.phase,game:sample});return false;}};
let previous=performance.now();function frame(now){window.S14X.data.raf.push({now,ms:now-previous,phase:window.S14X.data.phase,visible:document.visibilityState,focused:document.hasFocus()});previous=now;requestAnimationFrame(frame);}requestAnimationFrame(frame);
