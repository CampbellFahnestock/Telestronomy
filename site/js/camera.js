// Client for the local camera-control bridge (see docs/camera-bridge-api.md).
const KEY = 'telestronomy.bridgeUrl';
export const DEFAULT_BRIDGE_URL = 'http://raspberrypi.local:8080';

export function normalizeBaseUrl(input) {
  let u = (input || '').trim();
  if (!u) return '';
  if (!/^https?:\/\//i.test(u)) u = 'http://' + u;
  return u.replace(/\/+$/, '');
}

export function loadBridgeUrl() {
  try { return localStorage.getItem(KEY) || DEFAULT_BRIDGE_URL; } catch { return DEFAULT_BRIDGE_URL; }
}
export function saveBridgeUrl(url) {
  try { localStorage.setItem(KEY, url); } catch { /* ignore */ }
}

/** Browsers block http:// requests from an https:// page (mixed content), except localhost. */
export function mixedContentWarning(baseUrl, pageProtocol = globalThis.location?.protocol) {
  if (pageProtocol !== 'https:' || !/^http:/i.test(baseUrl)) return null;
  try {
    const host = new URL(baseUrl).hostname;
    if (host === 'localhost' || host === '127.0.0.1' || host === '[::1]') return null;
  } catch { return null; }
  return 'This page is HTTPS but the bridge URL is plain HTTP, so the browser will block it (mixed content). ' +
    'Run the bridge with HTTPS (--cert/--key), or open the app from the bridge itself (e.g. ' + baseUrl + '/).';
}

export class BridgeError extends Error {}

export class BridgeClient {
  constructor(baseUrl) { this.baseUrl = normalizeBaseUrl(baseUrl); }

  async request(path, { method = 'GET', body, timeout = 6000, raw = false } = {}) {
    if (!this.baseUrl) throw new BridgeError('No bridge URL set.');
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeout);
    try {
      const res = await fetch(this.baseUrl + path, {
        method, signal: ctl.signal,
        headers: body !== undefined ? { 'Content-Type': 'application/json' } : undefined,
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });
      if (!res.ok) {
        let detail = '';
        try { detail = (await res.json()).error || ''; } catch { /* not json */ }
        const e = new BridgeError(`Bridge error ${res.status}${detail ? ': ' + detail : ''}`);
        e.status = res.status;
        throw e;
      }
      return raw ? res.blob() : res.json();
    } catch (e) {
      if (e instanceof BridgeError) throw e;
      if (e.name === 'AbortError') throw new BridgeError('Bridge did not respond (timeout).');
      throw new BridgeError('Cannot reach the bridge at ' + this.baseUrl + '. Is it running and on the same network?');
    } finally {
      clearTimeout(timer);
    }
  }

  status() { return this.request('/status'); }
  getSettings() { return this.request('/settings'); }
  setSettings(s) { return this.request('/settings', { method: 'POST', body: s }); }
  capture() { return this.request('/capture', { method: 'POST', body: {}, raw: true, timeout: 30000 }); }
  solve(body = {}) { return this.request('/solve', { method: 'POST', body, timeout: 60000 }); }
  streamUrl() { return this.baseUrl + '/stream.mjpeg?t=' + Date.now(); }
}

/** Polls /status; on failure retries with exponential backoff (2s → 30s). Never throws. */
export class ConnectionMonitor {
  constructor(client, onChange) {
    this.client = client; this.onChange = onChange;
    this.timer = null; this.delay = 2000; this.running = false; this.connected = false;
  }
  start() { this.stop(); this.running = true; this.delay = 2000; this.tick(); }
  stop() { this.running = false; clearTimeout(this.timer); }
  async tick() {
    if (!this.running) return;
    try {
      const status = await this.client.status();
      this.connected = true; this.delay = 5000;
      this.onChange({ connected: true, status });
    } catch (e) {
      this.connected = false;
      this.onChange({ connected: false, error: e.message, retryInMs: this.delay });
      this.delay = Math.min(this.delay * 2, 30000);
    }
    if (this.running) this.timer = setTimeout(() => this.tick(), this.delay);
  }
}
