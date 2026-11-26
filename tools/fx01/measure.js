(() => {
  let last = null;
  window.FX01 = {
    commands: [], latest: null,
    data: {raf:[],samples:[],snapshots:[],phase:'loading'},
    accept(v) {this.latest=v;this.data.snapshots.push({now:performance.now(),phase:this.data.phase,...v});},
    phase(v) {this.data.phase=v;},
  };
  window.S08 = {accept(game) {FX01.data.samples.push({now:performance.now(),phase:FX01.data.phase,game});return false;}};
  function frame(now) {
    if(last!==null && FX01.latest) FX01.data.raf.push({now,ms:now-last,phase:FX01.data.phase,visible:document.visibilityState,focused:document.hasFocus()});
    last=now;requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
