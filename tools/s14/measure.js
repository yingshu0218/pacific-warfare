(() => {
 let last=null;
 window.S14={latest:null,data:{snapshots:[],events:[],raf:[],samples:[],phase:'loading'},accept(v){this.latest=v;this.data.events.push(...v.events);delete v.events;this.data.snapshots.push({now:performance.now(),phase:this.data.phase,...v})},phase(v){this.data.phase=v}};
 window.S08={accept(game){S14.data.samples.push({now:performance.now(),phase:S14.data.phase,game});return false}};
 function frame(now){if(last!==null&&S14.latest)S14.data.raf.push({now,ms:now-last,phase:S14.data.phase,visible:document.visibilityState,focused:document.hasFocus()});last=now;requestAnimationFrame(frame)}requestAnimationFrame(frame);
})();
