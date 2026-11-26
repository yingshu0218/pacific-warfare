const task = await taskSpace(PF01.spaceId);
const page = task.page("p1");

function installProbe() {
  window.PF01Probe = { samples: [], status: null };
  window.S08 = {
    ui() {},
    accept(result) {
      const { generation, tick, sim_s, pending_s, paused, speed, units, active_units,
        camera, counts, draw_calls, primitives, render_buffer } = result;
      const state = { generation, tick, sim_s, pending_s, paused, speed, units, active_units,
        camera, counts, draw_calls, primitives, render_buffer };
      window.PF01Probe.status = state;
      if (window.PF01Probe.collecting) window.PF01Probe.samples.push({ wall: performance.now(), state, frames: result.frames });
      return false;
    },
  };
}

await page.goto("about:blank");
let injection;
try {
  if (PF01.probe) {
    injection = await page.cdp("Page.addScriptToEvaluateOnNewDocument", { source: `(${installProbe.toString()})();` });
  }
  await page.goto(PF01.url, { timeout: 20000 });
  await page.waitForFunction(() => document.querySelector("canvas") && !document.querySelector("#status"), undefined, { timeout: 35000 });
  if (PF01.fighterButton) {
    const [x, y] = await page.evaluate(([x, y]) => {
      const rect = document.querySelector("canvas").getBoundingClientRect();
      return [rect.left + rect.width * x / 1280, rect.top + rect.height * y / 720];
    }, PF01.fighterButton);
    await page.mouse.click(x, y, { label: "Select fighter follow camera" });
  }
  if (PF01.paused) await page.keyboard.press("Space");
  if (PF01.probe) {
    await page.waitForFunction(({ paused, fighterButton }) => {
      const state = window.PF01Probe?.status;
      return state?.paused === paused && (!fighterButton || state.camera.mode === "fighter") && (paused || state.sim_s > 0);
    }, PF01, { timeout: 25000 });
    const status = await page.evaluate(() => window.PF01Probe.status);
    if (status.units !== 27 || status.speed !== 1) throw new Error(`Unexpected harbor state: ${JSON.stringify(status)}`);
  }

  await page.evaluate(({ durationMs, warmupMs, control }) => {
    const canvas = document.querySelector("canvas");
    const context = canvas.getContext(control ? "2d" : "webgl2");
    const measureState = () => ({
      visibility: document.visibilityState, focused: document.hasFocus(), canvasFocused: document.activeElement === canvas,
      viewport: [innerWidth, innerHeight], outer: [outerWidth, outerHeight], dpr: devicePixelRatio,
      visualViewport: [visualViewport.width, visualViewport.height, visualViewport.scale],
      cssCanvas: [canvas.getBoundingClientRect().width, canvas.getBoundingClientRect().height],
      canvasAttributes: [canvas.width, canvas.height],
      drawingBuffer: control ? [canvas.width, canvas.height] : context ? [context.drawingBufferWidth, context.drawingBufferHeight] : null,
    });
    const info = control ? null : context?.getExtension("WEBGL_debug_renderer_info");
    const result = window.PF01Result = { frames: [], done: false, browser: navigator.userAgent,
      renderer: info ? context.getParameter(info.UNMASKED_RENDERER_WEBGL) : null };
    let previous;
    let counter = 0;
    let request;
    const stop = () => {
      cancelAnimationFrame(request);
      result.endWall = performance.now();
      result.end = measureState();
      result.endGodot = window.PF01Probe?.status ?? null;
      result.gameSamples = window.PF01Probe?.samples ?? [];
      if (window.PF01Probe) window.PF01Probe.collecting = false;
      result.done = true;
    };
    const frame = (stamp) => {
      const dispatch = performance.now();
      if (control) {
        context.fillStyle = "#102331";
        context.fillRect((counter * 8) % canvas.width, 0, 8, 8);
        context.fillStyle = counter % 2 ? "#d4ebe1" : "#dda06a";
        context.fillRect(((counter + 1) * 8) % canvas.width, 0, 8, 8);
        counter += 1;
      }
      if (result.startWall !== undefined) {
        if (previous) result.frames.push([dispatch - previous[0], stamp - previous[1], document.visibilityState, document.hasFocus()]);
        previous = [dispatch, stamp];
      }
      request = requestAnimationFrame(frame);
    };
    request = requestAnimationFrame(frame);
    setTimeout(() => {
      result.startWall = performance.now();
      result.start = measureState();
      result.startGodot = window.PF01Probe?.status ?? null;
      if (window.PF01Probe) window.PF01Probe.collecting = true;
      setTimeout(stop, durationMs);
    }, warmupMs);
  }, PF01);
  await page.waitForFunction(() => window.PF01Result?.done, undefined, { timeout: PF01.durationMs + PF01.warmupMs + 15000 });
  console.log("PF01_JSON " + JSON.stringify(await page.evaluate(() => window.PF01Result)));
} finally {
  if (injection?.identifier) await page.cdp("Page.removeScriptToEvaluateOnNewDocument", { identifier: injection.identifier });
}
