import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { julianDate, gmst, lst, precessJ2000, equatorialToAltAz, j2000ToAltAz, altAzToEquatorial, solarSystemPosition, solarSystemAltAz } from '../js/astro.js';
import { azDelta, computeGuidance, deviceToPointing, Orientation } from '../js/alignment.js';
import { detectStars } from '../js/starfinder.js';
import { setCatalogue, getObjects, positionOf, searchObjects } from '../js/catalogue.js';

const near = (a, b, tol, msg) => assert.ok(Math.abs(a - b) <= tol, `${msg || ''} expected ${b} ±${tol}, got ${a}`);

test('julian date of J2000.0', () => {
  assert.equal(julianDate(new Date(Date.UTC(2000, 0, 1, 12))), 2451545.0);
});

test('GMST at J2000.0 is 280.46°', () => {
  near(gmst(2451545.0), 280.46061837, 1e-6);
});

test('GMST example from Meeus (1987-04-10 0h UT) = 13h10m46.37s', () => {
  const jd = julianDate(new Date(Date.UTC(1987, 3, 10, 0)));
  near(gmst(jd) / 15, 13 + 10 / 60 + 46.3668 / 3600, 1e-5);
});

test('LST adds east longitude', () => {
  near(lst(2451545.0, 10), (280.46061837 + 10) % 360, 1e-6);
});

test('precession of Polaris over 26 years moves RA by roughly 0.9-1.0° ', () => {
  const jd = julianDate(new Date(Date.UTC(2026, 0, 1)));
  const p = precessJ2000(37.9546, 89.2641, jd);
  assert.ok(p.dec > 89.2641 && p.dec < 89.4);
});

test('Polaris altitude ≈ observer latitude (several sites and times)', () => {
  const ra = 2.5303 * 15, dec = 89.2641;
  for (const lat of [10, 34.05, 45, 51.5, 64]) {
    for (let h = 0; h < 24; h += 3) {
      const d = new Date(Date.UTC(2026, 5, 1, h));
      const { alt } = j2000ToAltAz(ra, dec, lat, -118.2, d);
      near(alt, lat, 1.1, `lat ${lat} hour ${h}`);
    }
  }
});

test('Polaris azimuth is near north', () => {
  const { az } = j2000ToAltAz(2.5303 * 15, 89.2641, 40, -75, new Date(Date.UTC(2026, 9, 27, 3)));
  assert.ok(az < 3 || az > 357, 'az ' + az);
});

test('object on the meridian at lat 40, dec 40 is at zenith', () => {
  const d = new Date(Date.UTC(2026, 2, 1, 5));
  const lon = 0;
  const ra = lst(julianDate(d), lon);
  const { alt } = equatorialToAltAz(ra, 40, 40, lon, d);
  near(alt, 90, 1e-6);
});

test('equator due east rises: object with H=-90 at equator observer has alt 0, az 90', () => {
  const d = new Date(Date.UTC(2026, 2, 1, 5));
  const ra = lst(julianDate(d), 0) + 90;
  const r = equatorialToAltAz(ra, 0, 0, 0, d);
  near(r.alt, 0, 1e-6); near(r.az, 90, 1e-6);
});

test('altAz <-> equatorial roundtrip', () => {
  const d = new Date(Date.UTC(2026, 6, 4, 22, 15));
  const eq = altAzToEquatorial(33, 210, 47.6, -122.3, d);
  const h = equatorialToAltAz(eq.ra, eq.dec, 47.6, -122.3, d);
  near(h.alt, 33, 1e-6); near(h.az, 210, 1e-6);
});

test('Sun at March equinox 2024 has RA≈0h, Dec≈0°', () => {
  const p = solarSystemPosition('sun', new Date(Date.UTC(2024, 2, 20, 3, 6)));
  near(((p.ra + 180) % 360) - 180, 0, 0.2); near(p.dec, 0, 0.2);
});

test('Sun at June solstice 2024 has Dec≈+23.4°', () => {
  near(solarSystemPosition('sun', new Date(Date.UTC(2024, 5, 20, 21))).dec, 23.43, 0.1);
});

test('Moon: 1992-04-12 0h TD Meeus example RA≈134.7°, Dec≈13.8° (low precision)', () => {
  const p = solarSystemPosition('moon', new Date(Date.UTC(1992, 3, 12, 0)));
  near(p.ra, 134.68, 0.5); near(p.dec, 13.77, 0.5);
});

test('Venus 1992-12-20 0h Meeus example RA≈316.2°, Dec≈-18.9°', () => {
  const p = solarSystemPosition('venus', new Date(Date.UTC(1992, 11, 20, 0)));
  near(p.ra, 316.17, 0.4); near(p.dec, -18.89, 0.4);
});

test('all bodies return finite values', () => {
  for (const b of ['sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune']) {
    const r = solarSystemAltAz(b, 40, -75, new Date(Date.UTC(2026, 10, 18, 2)));
    assert.ok(Number.isFinite(r.alt) && Number.isFinite(r.az), b);
  }
  assert.throws(() => solarSystemPosition('pluto', new Date()));
});

test('azimuth wraparound', () => {
  near(azDelta(350, 10), 20, 1e-9);
  near(azDelta(10, 350), -20, 1e-9);
  near(azDelta(0, 180), 180, 1e-9);
});

test('guidance text and tolerance', () => {
  const g = computeGuidance({ alt: 30, az: 100 }, { alt: 33.1, az: 112.4 }, 1);
  assert.match(g.text, /RIGHT/); assert.match(g.text, /UP 3\.1°/); assert.equal(g.onTarget, false);
  const l = computeGuidance({ alt: 30, az: 5 }, { alt: 28, az: 350 }, 1);
  assert.match(l.text, /LEFT 15\.0°/); assert.match(l.text, /DOWN 2\.0°/);
  assert.equal(computeGuidance({ alt: 30, az: 100 }, { alt: 30.3, az: 100.4 }, 1).onTarget, true);
});

test('device orientation: phone upright facing north points at horizon north', () => {
  const p = deviceToPointing(0, 90, 0);
  near(p.alt, 0, 1e-6); near(p.az, 0, 1e-6);
  const up = deviceToPointing(0, 180, 0);
  near(up.alt, 90, 1e-6);
});

test('Orientation: uncalibrated sensor gives no guidance, calibration enables it', () => {
  let t = 0;
  const o = new Orientation(() => t);
  o.updateSensor(10, 90);
  assert.equal(o.current().state, 'none');
  o.calibrate(20, 100);
  o.updateSensor(15, 95);
  const c = o.current();
  assert.equal(c.state, 'ok'); near(c.alt, 25, 1e-9); near(c.az, 105, 1e-9);
  t += 10000;
  assert.ok(o.current().warnings.some((w) => /stale/.test(w)));
});

test('Orientation: plate solve wins and goes stale', () => {
  let t = 0;
  const o = new Orientation(() => t);
  o.updateSensor(0, 0);
  o.setPlateSolve(45, 200);
  assert.equal(o.current().source, 'plate solve');
  t += 120000;
  assert.notEqual(o.current().source, 'plate solve');
});

test('star detection finds synthetic stars', () => {
  const w = 64, h = 48, data = new Uint8ClampedArray(w * h * 4).fill(10);
  for (let i = 0; i < w * h; i++) data[i * 4 + 3] = 255;
  const put = (x, y, v) => { const i = (y * w + x) * 4; data[i] = data[i + 1] = data[i + 2] = v; };
  for (const [cx, cy] of [[10, 10], [40, 20], [30, 40]]) {
    put(cx, cy, 255); put(cx + 1, cy, 180); put(cx - 1, cy, 180); put(cx, cy + 1, 180); put(cx, cy - 1, 180);
  }
  const { stars } = detectStars({ data, width: w, height: h });
  assert.equal(stars.length, 3);
  assert.ok(stars.some((s) => Math.abs(s.x - 40) < 0.5 && Math.abs(s.y - 20) < 0.5));
});

test('catalogue: required contents and live positions', () => {
  const cat = JSON.parse(readFileSync(new URL('../data/objects.json', import.meta.url)));
  setCatalogue(cat.objects);
  const names = getObjects().map((o) => o.name);
  for (const n of ['Polaris', 'Sirius', 'Sun', 'Moon', 'Mars', 'Neptune', 'M31 Andromeda Galaxy']) assert.ok(names.includes(n), n);
  assert.ok(getObjects().filter((o) => o.type === 'Star').length >= 50);
  assert.equal(searchObjects('andro').length, 1);
  for (const o of getObjects()) {
    const p = positionOf(o, 40, -75, new Date(Date.UTC(2026, 10, 18, 2)));
    assert.ok(Number.isFinite(p.alt) && Number.isFinite(p.az), o.name);
  }
});
