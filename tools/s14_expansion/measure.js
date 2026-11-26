window.S14X={latest:null,lastArchive:-Infinity,data:{snapshots:[],events:[],raf:[],samples:[],phase:'loading'},receive(value){
 this.latest=value;const now=performance.now();if(now-this.lastArchive<500)return;this.lastArchive=now;
 const {journal,orders,...state}=value;
 this.data.snapshots.push({now,phase:this.data.phase,...state,orders:orders.map(({history,...order})=>order)});
},events(rows){this.data.events.push(...rows);},phase(value){this.data.phase=value;}};
window.S08={ui(){},image(){},accept(value){window.S14X.data.samples.push({now:performance.now(),phase:window.S14X.data.phase,game:value});return false;}};
let previous=performance.now();function sample(now){window.S14X.data.raf.push({now,ms:now-previous,phase:window.S14X.data.phase,visible:document.visibilityState,focused:document.hasFocus()});previous=now;requestAnimationFrame(sample);}requestAnimationFrame(sample);
