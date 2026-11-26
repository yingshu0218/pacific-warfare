/* Passive measurement, plus an explicit command queue for the isolated fixture. */
(() => {
  let last = null;
  const data = {raf: [], samples: [], snapshots: [], phase: 'loading'};
  window.S13 = {
    commands: [], latest: null, data,
    accept(value) { this.latest = value; data.snapshots.push({now:performance.now(),phase:data.phase,...value}); },
    phase(value) {data.phase = value;},
  };
  window.S08 = {accept(game) {data.samples.push({now:performance.now(),phase:data.phase,game});return false;}};
  function frame(now) {
    if (last !== null && window.S13.latest) data.raf.push({now,ms:now-last,phase:data.phase,visible:document.visibilityState,focused:document.hasFocus()});
    last = now;
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
