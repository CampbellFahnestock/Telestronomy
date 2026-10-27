import { j2000ToAltAz, julianDate, lst } from './astro.js';
import { loadCatalogue, getObjects, positionOf, searchObjects } from './catalogue.js';
import { loadLocation, requestGps, setManualLocation } from './location.js';
import { BridgeClient, ConnectionMonitor, loadBridgeUrl, saveBridgeUrl, mixedContentWarning, normalizeBaseUrl } from './camera.js';
import { Orientation, computeGuidance, deviceToPointing } from './alignment.js';
import { detectStars } from './starfinder.js';

const $ = (id) => document.getElementById(id);
const store = {
  get: (k, d) => { try { const v = localStorage.getItem(k); return v === null ? d : v; } catch { return d; } },
  set: (k, v) => { try { localStorage.setItem(k, v); } catch { /* ignore */ } },
};

const state = {
  location: loadLocation(),
  target: null,
  orientation: new Orientation(),
  tolerance: parseFloat(store.get('telestronomy.tolerance', '1')) || 1,
  vibrate: store.get('telestronomy.vibrate', '1') === '1',
  cameraEnabled: false,
  cameraConnected: false,
  cameraInfo: null,
  sensorEnabled: false,
  wasOnTarget: false,
  lastCapture: null,
};
let client = null;
let monitor = null;

// ---------- navigation ----------
function showStep(step) {
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === 'step-' + step));
  document.querySelectorAll('.steps button').forEach((b) => b.classList.toggle('active', b.dataset.step === step));
  window.scrollTo(0, 0);
  refresh();
}
document.querySelectorAll('.steps button').forEach((b) => b.addEventListener('click', () => showStep(b.dataset.step)));
document.querySelectorAll('[data-goto]').forEach((b) => b.addEventListener('click', () => showStep(b.dataset.goto)));

// ---------- night mode / network ----------
function setNight(on) {
  document.body.classList.toggle('night', on);
  $('night-toggle').setAttribute('aria-pressed', String(on));
  store.set('telestronomy.night', on ? '1' : '0');
  document.querySelector('meta[name=theme-color]').content = on ? '#000000' : '#02040d';
}
$('night-toggle').addEventListener('click', () => setNight(!document.body.classList.contains('night')));
setNight(store.get('telestronomy.night', '0') === '1');

function updateNet() {
  const on = navigator.onLine;
  const b = $('net-badge');
  b.textContent = on ? 'Online' : 'Offline';
  b.classList.toggle('offline', !on);
}
addEventListener('online', updateNet); addEventListener('offline', updateNet); updateNet();

// ---------- location ----------
function describeLocation() {
  const l = state.location;
  if (!l) { $('loc-status').textContent = 'No location set. Use GPS or enter coordinates.'; return; }
  const src = l.source === 'gps' ? `GPS fix${l.accuracy ? ' (±' + Math.round(l.accuracy) + ' m)' : ''}` : 'manual entry';
  $('loc-status').textContent = `${l.lat.toFixed(4)}°, ${l.lon.toFixed(4)}° — ${src}, saved ${new Date(l.savedAt).toLocaleString()}`;
}
$('gps-btn').addEventListener('click', async () => {
  $('loc-error').textContent = '';
  $('gps-btn').disabled = true; $('loc-status').textContent = 'Requesting GPS…';
  try { state.location = await requestGps(); } catch (e) { $('loc-error').textContent = e.message; }
  $('gps-btn').disabled = false; describeLocation(); refresh();
});
$('manual-loc-btn').addEventListener('click', () => {
  $('loc-error').textContent = '';
  try { state.location = setManualLocation(parseFloat($('lat-input').value), parseFloat($('lon-input').value)); }
  catch (e) { $('loc-error').textContent = e.message; }
  describeLocation(); refresh();
});
if (state.location) { $('lat-input').value = state.location.lat; $('lon-input').value = state.location.lon; }
describeLocation();

// ---------- target list ----------
const rows = new Map();
function fmtPos(p) { return `Alt ${p.alt.toFixed(1)}° · Az ${p.az.toFixed(1)}°`; }

function buildList() {
  const list = $('object-list');
  list.textContent = '';
  rows.clear();
  const found = searchObjects($('search').value);
  if (!found.length) { const li = document.createElement('li'); li.className = 'muted'; li.textContent = 'No matching objects.'; list.append(li); return; }
  const now = new Date();
  const withPos = found.map((o) => ({ o, p: state.location ? positionOf(o, state.location.lat, state.location.lon, now) : null }));
  if (state.location) withPos.sort((a, b) => (b.p.alt > 0) - (a.p.alt > 0));
  for (const { o } of withPos) {
    const li = document.createElement('li');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.setAttribute('aria-pressed', String(state.target === o));
    const left = document.createElement('span');
    left.innerHTML = '<span class="name"></span><br><span class="type"></span>';
    left.querySelector('.name').textContent = o.name;
    left.querySelector('.type').textContent = o.type;
    const pos = document.createElement('span'); pos.className = 'pos';
    btn.append(left, pos); li.append(btn); list.append(li);
    rows.set(o, { btn, pos });
    btn.addEventListener('click', () => selectTarget(o));
  }
  updateList();
}
function updateList() {
  const now = new Date();
  for (const [o, { pos }] of rows) {
    if (!state.location) { pos.textContent = 'Set location'; continue; }
    const p = positionOf(o, state.location.lat, state.location.lon, now);
    const up = p.alt > 0;
    pos.innerHTML = `<span class="${up ? 'up' : 'down'}">${up ? '▲ Above horizon' : '▼ Below horizon'}</span><br>${fmtPos(p)}`;
  }
}
function selectTarget(o) {
  state.target = o;
  store.set('telestronomy.target', o.name);
  for (const [obj, { btn }] of rows) btn.setAttribute('aria-pressed', String(obj === o));
  state.wasOnTarget = false;
  refresh();
  showStep(state.orientation.current().state === 'ok' ? 'navigate' : 'calibrate');
}
$('search').addEventListener('input', buildList);

// ---------- orientation ----------
function targetPos(now = new Date()) {
  if (!state.target || !state.location) return null;
  return positionOf(state.target, state.location.lat, state.location.lon, now);
}
function calibrateWith(alt, az, note) {
  state.orientation.calibrate(alt, az);
  state.wasOnTarget = false;
  $('cal-error').textContent = '';
  refresh();
  if (note) $('cal-error').textContent = note;
}
$('sync-btn').addEventListener('click', syncToTarget);
$('nav-sync-btn').addEventListener('click', syncToTarget);
function syncToTarget() {
  const tp = targetPos();
  if (!state.location) { $('cal-error').textContent = 'Set your location first.'; return showStep('location'); }
  if (!tp) { $('cal-error').textContent = 'Select a target first, then point the telescope at it.'; return showStep('target'); }
  if (tp.alt < 0) { $('cal-error').textContent = 'The selected target is below the horizon — pick a visible target to sync.'; return; }
  calibrateWith(tp.alt, tp.az);
}
$('cal-btn').addEventListener('click', () => {
  const alt = parseFloat($('cal-alt').value), az = parseFloat($('cal-az').value);
  if (!Number.isFinite(alt) || !Number.isFinite(az) || alt < -90 || alt > 90 || az < 0 || az >= 360) {
    $('cal-error').textContent = 'Enter altitude between -90 and 90, and azimuth from 0 to under 360.'; return;
  }
  calibrateWith(alt, az);
});
$('clear-cal').addEventListener('click', () => { state.orientation.clear(); state.wasOnTarget = false; refresh(); });
$('recal-btn').addEventListener('click', () => showStep('calibrate'));

let lastSensorEvent = 0;
function onDeviceOrientation(e) {
  if (e.alpha === null || e.beta === null || e.gamma === null) return;
  let alpha = e.alpha;
  if (typeof e.webkitCompassHeading === 'number') alpha = 360 - e.webkitCompassHeading;
  const p = deviceToPointing(alpha, e.beta, e.gamma);
  state.orientation.updateSensor(p.alt, p.az);
  lastSensorEvent = Date.now();
}
$('sensor-btn').addEventListener('click', async () => {
  const note = $('sensor-status');
  if (typeof DeviceOrientationEvent === 'undefined') { note.textContent = 'This device/browser has no orientation sensors. Use manual calibration.'; return; }
  try {
    if (typeof DeviceOrientationEvent.requestPermission === 'function') {
      const r = await DeviceOrientationEvent.requestPermission();
      if (r !== 'granted') { note.textContent = 'Motion sensor permission denied. Use manual calibration.'; return; }
    }
  } catch (e) { note.textContent = 'Could not get sensor permission: ' + e.message; return; }
  if (!state.sensorEnabled) {
    const evt = 'ondeviceorientationabsolute' in window ? 'deviceorientationabsolute' : 'deviceorientation';
    addEventListener(evt, onDeviceOrientation);
    state.sensorEnabled = true;
  }
  note.textContent = 'Waiting for sensor data…';
  setTimeout(() => { if (!lastSensorEvent) note.textContent = 'No sensor data received (desktop or sensors disabled). Use manual calibration.'; }, 3000);
});

// ---------- camera ----------
$('bridge-url').value = loadBridgeUrl();
function setCamError(msg) { $('cam-error').textContent = msg || ''; }
function setSlider(range, valEl, spec, value) {
  if (!spec) { range.disabled = true; valEl.textContent = 'n/a'; return; }
  range.min = spec.min; range.max = spec.max; range.step = spec.step || 1;
  if (value !== undefined && document.activeElement !== range) range.value = value;
  range.disabled = false; valEl.textContent = range.value;
}
async function loadSettings() {
  const caps = state.cameraInfo?.capabilities || {};
  if (!caps.settings) { $('settings-note').textContent = 'Bridge does not report settings support: exposure/gain locked.'; setSlider($('exp-range'), $('exp-val')); setSlider($('gain-range'), $('gain-val')); return; }
  try {
    const s = await client.getSettings();
    setSlider($('exp-range'), $('exp-val'), s.exposure_ms_range && { min: s.exposure_ms_range[0], max: s.exposure_ms_range[1], step: 1 }, s.exposure_ms);
    setSlider($('gain-range'), $('gain-val'), s.gain_range && { min: s.gain_range[0], max: s.gain_range[1], step: 1 }, s.gain);
    $('settings-note').textContent = 'Settings supported by bridge.';
  } catch (e) { setCamError(e.message); }
}
function onBridge(ev) {
  const was = state.cameraConnected;
  state.cameraConnected = ev.connected;
  if (ev.connected) {
    state.cameraInfo = ev.status;
    const cam = ev.status.camera || {};
    $('cam-status').textContent = `Connected — ${cam.name || 'camera'} (${ev.status.backend || 'bridge'}${ev.status.mock ? ', MOCK images' : ''})`;
    setCamError(cam.connected === false ? 'Bridge is up but the camera is not connected to it.' : '');
    const caps = ev.status.capabilities || {};
    $('capture-btn').disabled = !caps.capture || cam.connected === false;
    $('solve-btn').disabled = !caps.solve;
    $('cal-solve-btn').disabled = !caps.solve;
    $('cal-solve-note').textContent = caps.solve ? 'Solves the next camera frame and calibrates from the result.' : 'Plate solve unavailable on this bridge — use manual calibration.';
    if (!was) {
      const feed = $('cam-feed');
      if (caps.stream) { feed.src = client.streamUrl(); feed.hidden = false; $('cam-feed-empty').hidden = true; }
      loadSettings();
    }
  } else {
    state.cameraInfo = null;
    $('cam-status').textContent = `Camera disconnected. Retrying in ${Math.round(ev.retryInMs / 1000)} s…`;
    setCamError(ev.error);
    $('capture-btn').disabled = true; $('solve-btn').disabled = true; $('cal-solve-btn').disabled = true;
    $('cal-solve-note').textContent = 'Plate solve unavailable — use manual calibration.';
    $('cam-feed').hidden = true; $('cam-feed').removeAttribute('src'); $('cam-feed-empty').hidden = false;
    setSlider($('exp-range'), $('exp-val')); setSlider($('gain-range'), $('gain-val'));
  }
  refresh();
}
$('cam-feed').addEventListener('error', () => { if (state.cameraConnected) setCamError('Live feed interrupted — retrying with the next status check.'); });
$('bridge-connect').addEventListener('click', () => {
  const url = normalizeBaseUrl($('bridge-url').value);
  if (!url) { setCamError('Enter the bridge URL.'); return; }
  $('bridge-url').value = url; saveBridgeUrl(url);
  const warn = mixedContentWarning(url);
  setCamError(warn || '');
  monitor?.stop();
  client = new BridgeClient(url);
  monitor = new ConnectionMonitor(client, onBridge);
  state.cameraEnabled = true; state.cameraConnected = false;
  $('cam-status').textContent = 'Connecting…';
  monitor.start();
});
$('bridge-disconnect').addEventListener('click', () => {
  monitor?.stop(); state.cameraEnabled = false; state.cameraConnected = false;
  $('cam-feed').hidden = true; $('cam-feed').removeAttribute('src'); $('cam-feed-empty').hidden = false;
  $('capture-btn').disabled = true; $('solve-btn').disabled = true; $('cal-solve-btn').disabled = true;
  $('cam-status').textContent = 'Camera not connected.'; setCamError('');
  refresh();
});
let settingsTimer = null;
function pushSettings() {
  $('exp-val').textContent = $('exp-range').value; $('gain-val').textContent = $('gain-range').value;
  clearTimeout(settingsTimer);
  settingsTimer = setTimeout(async () => {
    try { await client.setSettings({ exposure_ms: +$('exp-range').value, gain: +$('gain-range').value }); setCamError(''); }
    catch (e) { setCamError(e.message); }
  }, 300);
}
$('exp-range').addEventListener('input', pushSettings);
$('gain-range').addEventListener('input', pushSettings);

async function analyseBlob(blob) {
  const bmp = await createImageBitmap(blob);
  const scale = Math.min(1, 1280 / bmp.width);
  const w = Math.max(1, Math.round(bmp.width * scale)), h = Math.max(1, Math.round(bmp.height * scale));
  const cv = $('capture-canvas');
  cv.width = w; cv.height = h;
  const ctx = cv.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(bmp, 0, 0, w, h);
  const { stars } = detectStars(ctx.getImageData(0, 0, w, h));
  ctx.strokeStyle = '#3b82f6'; ctx.lineWidth = Math.max(1, w / 400);
  for (const s of stars) { ctx.beginPath(); ctx.arc(s.x, s.y, Math.max(6, Math.sqrt(s.size) * 3), 0, 2 * Math.PI); ctx.stroke(); }
  $('star-count').textContent = `${stars.length} star${stars.length === 1 ? '' : 's'} detected (${w}×${h}).`;
  bmp.close?.();
  return stars;
}
$('capture-btn').addEventListener('click', async () => {
  $('capture-btn').disabled = true; setCamError('');
  try {
    const blob = await client.capture();
    state.lastCapture = blob;
    const dl = $('download-link');
    if (dl.href.startsWith('blob:')) URL.revokeObjectURL(dl.href);
    dl.href = URL.createObjectURL(blob);
    dl.download = `telestronomy-${new Date().toISOString().replace(/[:.]/g, '-')}.jpg`;
    dl.hidden = false;
    await analyseBlob(blob);
    $('solve-btn').disabled = !state.cameraInfo?.capabilities?.solve;
  } catch (e) { setCamError('Capture failed: ' + e.message); }
  $('capture-btn').disabled = !state.cameraConnected;
});

async function plateSolve(statusEl) {
  statusEl.textContent = 'Solving…';
  if (!state.location) { statusEl.textContent = 'Set your location first (needed to convert the solution to Alt/Az).'; return; }
  if (!state.cameraInfo?.capabilities?.solve) { statusEl.textContent = 'Plate solve unavailable — use manual calibration.'; return; }
  try {
    const r = await client.solve({});
    if (!r.solved) { statusEl.textContent = 'Plate solve failed: ' + (r.error || 'no solution found') + '. Use manual calibration.'; return; }
    const h = j2000ToAltAz(r.ra, r.dec, state.location.lat, state.location.lon, new Date());
    state.orientation.setPlateSolve(h.alt, h.az);
    state.wasOnTarget = false;
    statusEl.textContent = `Solved: RA ${r.ra.toFixed(3)}°, Dec ${r.dec.toFixed(3)}°, roll ${Number(r.roll).toFixed(1)}°, FOV ${Number(r.fov_deg).toFixed(2)}° → Alt ${h.alt.toFixed(1)}°, Az ${h.az.toFixed(1)}°`;
    refresh();
  } catch (e) { statusEl.textContent = 'Plate solve error: ' + e.message + ' — use manual calibration.'; }
}
$('solve-btn').addEventListener('click', () => plateSolve($('solve-status')));
$('cal-solve-btn').addEventListener('click', () => plateSolve($('cal-error')));

// ---------- alignment display ----------
function css(name) { return getComputedStyle(document.body).getPropertyValue(name).trim(); }
function drawAlignment(g, pointingAlt) {
  const cv = $('align-canvas'), ctx = cv.getContext('2d');
  const W = cv.width, H = cv.height, cx = W / 2, cy = H / 2, R = W / 2 - 14;
  const fg = css('--text'), accent = css('--accent'), muted = css('--muted'), ok = css('--ok');
  ctx.clearRect(0, 0, W, H);
  ctx.fillStyle = css('--bg'); ctx.fillRect(0, 0, W, H);
  ctx.lineWidth = 1; ctx.strokeStyle = muted; ctx.fillStyle = muted; ctx.font = '12px system-ui';
  const range = 20; // degrees at the edge of the display
  for (const r of [0.25, 0.5, 0.75, 1]) { ctx.beginPath(); ctx.arc(cx, cy, R * r, 0, 2 * Math.PI); ctx.stroke(); }
  ctx.fillText(`${range}°`, cx + R - 24, cy - 4); ctx.fillText(`${range / 2}°`, cx + R / 2 - 14, cy - 4);
  ctx.strokeStyle = fg; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(cx - R, cy); ctx.lineTo(cx + R, cy); ctx.moveTo(cx, cy - R); ctx.lineTo(cx, cy + R); ctx.stroke();
  ctx.fillStyle = fg; ctx.font = 'bold 14px system-ui';
  ctx.fillText('U', cx - 4, cy - R - 2 + 12); ctx.fillText('D', cx - 4, cy + R - 2); ctx.fillText('L', cx - R + 4, cy + 5); ctx.fillText('R', cx + R - 14, cy + 5);
  if (!g) { ctx.fillStyle = muted; ctx.textAlign = 'center'; ctx.fillText('Not calibrated', cx, cy + R / 2); ctx.textAlign = 'left'; return; }
  const tolR = Math.max(4, (state.tolerance / range) * R);
  ctx.strokeStyle = g.onTarget ? ok : accent; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.arc(cx, cy, tolR, 0, 2 * Math.PI); ctx.stroke();
  // target offset on sky: azimuth difference shrinks with cos(altitude)
  let dx = (g.dAz * Math.cos((pointingAlt * Math.PI) / 180) / range) * R;
  let dy = (-g.dAlt / range) * R;
  const dist = Math.hypot(dx, dy);
  const clamped = dist > R;
  if (clamped) { dx *= R / dist; dy *= R / dist; }
  ctx.fillStyle = g.onTarget ? ok : accent;
  ctx.beginPath(); ctx.arc(cx + dx, cy + dy, 9, 0, 2 * Math.PI); ctx.fill();
  if (clamped) {
    ctx.strokeStyle = accent; ctx.lineWidth = 4; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + dx, cy + dy); ctx.stroke();
  }
}

// ---------- refresh (live) ----------
function renderWarnings(cur) {
  const w = [];
  if (!state.location) w.push('No location set — positions cannot be calculated.');
  else if (state.location.source !== 'gps') w.push('Using a manual/saved location, not a live GPS fix. Accuracy depends on what you entered.');
  if (state.cameraEnabled && !state.cameraConnected) w.push('Camera disconnected — plate solving and live feed are unavailable.');
  if (state.sensorEnabled && Date.now() - lastSensorEvent > 3000 && lastSensorEvent) w.push('Orientation sensor data is stale.');
  w.push(...cur.warnings.filter((x) => !(state.sensorEnabled && /stale/.test(x) && Date.now() - lastSensorEvent > 3000 && lastSensorEvent)));
  const tp = targetPos();
  if (tp && tp.alt < 0) w.push(`${state.target.name} is below the horizon right now.`);
  $('warnings').textContent = '';
  for (const t of [...new Set(w)]) { const d = document.createElement('div'); d.className = 'warn-item'; d.textContent = '⚠ ' + t; $('warnings').append(d); }
}

function refresh() {
  const now = new Date();
  $('utc').textContent = now.toISOString().replace('T', ' ').slice(0, 19);
  if (state.location) {
    const { lat, lon } = state.location;
    const p = j2000ToAltAz(2.5303 * 15, 89.2641, lat, lon, now);
    $('pol-alt').textContent = p.alt.toFixed(2) + '°' + (p.alt < 0 ? ' (below horizon)' : '');
    $('pol-az').textContent = p.az.toFixed(2) + '°';
    const l = lst(julianDate(now), lon);
    const hh = l / 15;
    $('lst').textContent = `${String(Math.floor(hh)).padStart(2, '0')}h ${String(Math.floor((hh % 1) * 60)).padStart(2, '0')}m ${String(Math.floor((((hh % 1) * 60) % 1) * 60)).padStart(2, '0')}s`;
  } else {
    $('pol-alt').textContent = $('pol-az').textContent = $('lst').textContent = 'Set location';
  }
  if (document.getElementById('step-target').classList.contains('active')) updateList();
  $('selected-line').textContent = state.target ? `Selected: ${state.target.name} (${state.target.type})` : 'No target selected.';

  const cur = state.orientation.current();
  const box = $('orient-status');
  if (cur.state === 'ok') { box.textContent = `Calibrated (${cur.source}): Alt ${cur.alt.toFixed(1)}°, Az ${cur.az.toFixed(1)}°`; box.className = 'status-box ok'; }
  else { box.textContent = 'Not calibrated'; box.className = 'status-box bad'; }
  if (state.sensorEnabled && lastSensorEvent) $('sensor-status').textContent = `Sensors active${cur.state === 'ok' ? '' : ' — calibrate to use them for guidance'}.`;

  const tp = targetPos(now);
  let g = null;
  if (!state.target) $('nav-target').textContent = 'Select a target first.';
  else $('nav-target').textContent = `Target: ${state.target.name}`;
  $('nav-target-pos').textContent = tp ? fmtPos(tp) : '—';
  if (cur.state === 'ok') { $('nav-pointing').textContent = `Alt ${cur.alt.toFixed(1)}° · Az ${cur.az.toFixed(1)}°`; $('nav-source').textContent = cur.source; }
  else { $('nav-pointing').textContent = 'Not calibrated'; $('nav-source').textContent = '—'; }

  const gEl = $('guidance');
  if (cur.state !== 'ok') { gEl.textContent = 'Not calibrated — calibrate first (step 3).'; }
  else if (!tp) { gEl.textContent = !state.location ? 'Set your location.' : 'Select a target.'; }
  else if (tp.alt < 0) { gEl.textContent = 'Target is below the horizon.'; }
  else {
    g = computeGuidance(cur, tp, state.tolerance);
    gEl.textContent = g.text;
  }
  $('on-target').hidden = !(g && g.onTarget);
  if (g && g.onTarget && !state.wasOnTarget && state.vibrate && navigator.vibrate) navigator.vibrate([200, 100, 200]);
  state.wasOnTarget = !!(g && g.onTarget);
  drawAlignment(g, cur.alt ?? 0);
  renderWarnings(cur);
}

$('tolerance').value = state.tolerance;
$('tolerance').addEventListener('change', () => {
  const v = parseFloat($('tolerance').value);
  state.tolerance = Number.isFinite(v) && v > 0 ? Math.min(v, 10) : 1;
  $('tolerance').value = state.tolerance; store.set('telestronomy.tolerance', String(state.tolerance)); refresh();
});
$('vibrate').checked = state.vibrate;
$('vibrate').addEventListener('change', () => { state.vibrate = $('vibrate').checked; store.set('telestronomy.vibrate', state.vibrate ? '1' : '0'); });

// ---------- start ----------
async function init() {
  try {
    await loadCatalogue();
  } catch (e) {
    const li = document.createElement('li');
    li.className = 'error';
    li.textContent = 'Could not load the object catalogue: ' + e.message;
    $('object-list').replaceChildren(li);
  }
  const saved = store.get('telestronomy.target', null);
  if (saved) state.target = getObjects().find((o) => o.name === saved) || null;
  buildList();
  refresh();
  setInterval(refresh, 1000);
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js').catch((e) => console.warn('Service worker registration failed:', e));
  }
}
init();
