// Local astronomy math. No network, no dependencies.
// Angles are in degrees unless noted. Accuracy notes are per function.

export const DEG = Math.PI / 180;
export const norm360 = (x) => ((x % 360) + 360) % 360;
export const norm180 = (x) => { const v = norm360(x); return v > 180 ? v - 360 : v; };
const sin = (d) => Math.sin(d * DEG);
const cos = (d) => Math.cos(d * DEG);
const tan = (d) => Math.tan(d * DEG);
const atan2d = (y, x) => Math.atan2(y, x) / DEG;

/** Julian date from a JS Date (UTC). Exact to the millisecond. */
export function julianDate(date) {
  return date.getTime() / 86400000 + 2440587.5;
}

/** Greenwich mean sidereal time in degrees (IAU 1982 polynomial, sub-arcsecond over decades). */
export function gmst(jd) {
  const d = jd - 2451545.0;
  const T = d / 36525;
  return norm360(280.46061837 + 360.98564736629 * d + 0.000387933 * T * T - (T * T * T) / 38710000);
}

/** Local sidereal time in degrees; east longitude positive. */
export function lst(jd, lonDeg) {
  return norm360(gmst(jd) + lonDeg);
}

/**
 * Precess J2000 equatorial coordinates to the mean equator/equinox of `date`.
 * Simple linear-rate method (Meeus 21.1 low-order); good to ~a few arcseconds within
 * a few decades of J2000, which is far below naked-eye/phone-sensor accuracy.
 */
export function precessJ2000(raDeg, decDeg, jd) {
  const years = (jd - 2451545.0) / 365.25;
  const T = years / 100;
  const m = 3.07496 + 0.00186 * T; // seconds of time per year
  const n = 20.0431 - 0.0085 * T; // arcsec per year
  const dRa = (m + (n / 15) * sin(raDeg) * tan(decDeg)) * years * 15 / 3600;
  const dDec = (n * cos(raDeg) * years) / 3600;
  return { ra: norm360(raDeg + dRa), dec: Math.max(-90, Math.min(90, decDeg + dDec)) };
}

/**
 * Equatorial (of date) -> horizontal. Azimuth measured from North through East.
 * No atmospheric refraction is applied (≤0.5° near the horizon).
 */
export function equatorialToAltAz(raDeg, decDeg, latDeg, lonDeg, date) {
  const jd = julianDate(date);
  const H = lst(jd, lonDeg) - raDeg;
  const sinAlt = sin(decDeg) * sin(latDeg) + cos(decDeg) * cos(latDeg) * cos(H);
  const alt = Math.asin(Math.max(-1, Math.min(1, sinAlt))) / DEG;
  const az = atan2d(-cos(decDeg) * sin(H), sin(decDeg) * cos(latDeg) - cos(decDeg) * sin(latDeg) * cos(H));
  return { alt, az: norm360(az) };
}

/** J2000 RA/Dec -> Alt/Az, including precession. */
export function j2000ToAltAz(raDeg, decDeg, latDeg, lonDeg, date) {
  const p = precessJ2000(raDeg, decDeg, julianDate(date));
  return equatorialToAltAz(p.ra, p.dec, latDeg, lonDeg, date);
}

/** Inverse of equatorialToAltAz: returns RA/Dec of date. */
export function altAzToEquatorial(altDeg, azDeg, latDeg, lonDeg, date) {
  const jd = julianDate(date);
  const sinDec = sin(altDeg) * sin(latDeg) + cos(altDeg) * cos(latDeg) * cos(azDeg);
  const dec = Math.asin(Math.max(-1, Math.min(1, sinDec))) / DEG;
  const H = atan2d(-sin(azDeg) * cos(altDeg), sin(altDeg) * cos(latDeg) - cos(altDeg) * sin(latDeg) * cos(azDeg));
  return { ra: norm360(lst(jd, lonDeg) - H), dec };
}

/** Angular separation between two alt/az directions, degrees. */
export function angularSeparation(alt1, az1, alt2, az2) {
  const c = sin(alt1) * sin(alt2) + cos(alt1) * cos(alt2) * cos(az1 - az2);
  return Math.acos(Math.max(-1, Math.min(1, c))) / DEG;
}

// ---------------------------------------------------------------------------
// Compact ephemeris: Paul Schlyter "How to compute planetary positions".
// Accuracy: Sun ~1 arcmin; Moon ~2 arcmin in longitude (≈0.1° worst case after the
// topocentric correction); Mercury–Mars ~1–2 arcmin; Jupiter/Saturn/Uranus ~1–2 arcmin
// with the included perturbation terms; Neptune ~1 arcmin. Valid roughly 1900–2100.
// Results are geocentric RA/Dec of date (no precession needed).
// ---------------------------------------------------------------------------

const ELEMENTS = {
  mercury: (d) => ({ N: 48.3313 + 3.24587e-5 * d, i: 7.0047 + 5.0e-8 * d, w: 29.1241 + 1.01444e-5 * d, a: 0.387098, e: 0.205635 + 5.59e-10 * d, M: 168.6562 + 4.0923344368 * d }),
  venus: (d) => ({ N: 76.6799 + 2.4659e-5 * d, i: 3.3946 + 2.75e-8 * d, w: 54.891 + 1.38374e-5 * d, a: 0.72333, e: 0.006773 - 1.302e-9 * d, M: 48.0052 + 1.6021302244 * d }),
  mars: (d) => ({ N: 49.5574 + 2.11081e-5 * d, i: 1.8497 - 1.78e-8 * d, w: 286.5016 + 2.92961e-5 * d, a: 1.523688, e: 0.093405 + 2.516e-9 * d, M: 18.6021 + 0.5240207766 * d }),
  jupiter: (d) => ({ N: 100.4542 + 2.76854e-5 * d, i: 1.303 - 1.557e-7 * d, w: 273.8777 + 1.64505e-5 * d, a: 5.20256, e: 0.048498 + 4.469e-9 * d, M: 19.895 + 0.0830853001 * d }),
  saturn: (d) => ({ N: 113.6634 + 2.3898e-5 * d, i: 2.4886 - 1.081e-7 * d, w: 339.3939 + 2.97661e-5 * d, a: 9.55475, e: 0.055546 - 9.499e-9 * d, M: 316.967 + 0.0334442282 * d }),
  uranus: (d) => ({ N: 74.0005 + 1.3978e-5 * d, i: 0.7733 + 1.9e-8 * d, w: 96.6612 + 3.0565e-5 * d, a: 19.18171 - 1.55e-8 * d, e: 0.047318 + 7.45e-9 * d, M: 142.5905 + 0.011725806 * d }),
  neptune: (d) => ({ N: 131.7806 + 3.0173e-5 * d, i: 1.77 - 2.55e-7 * d, w: 272.8461 - 6.027e-6 * d, a: 30.05826 + 3.313e-8 * d, e: 0.008606 + 2.15e-9 * d, M: 260.2471 + 0.005995147 * d }),
};

function solveKepler(Mdeg, e) {
  let E = Mdeg + (e / DEG) * sin(Mdeg) * (1 + e * cos(Mdeg));
  for (let k = 0; k < 10; k++) {
    const dE = (E - (e / DEG) * sin(E) - Mdeg) / (1 - e * cos(E));
    E -= dE;
    if (Math.abs(dE) < 1e-9) break;
  }
  return E;
}

// Returns heliocentric (or geocentric for the Moon) ecliptic rectangular coordinates.
function orbitPosition(el) {
  const E = solveKepler(el.M, el.e);
  const xv = el.a * (cos(E) - el.e);
  const yv = el.a * Math.sqrt(1 - el.e * el.e) * sin(E);
  const v = atan2d(yv, xv);
  const r = Math.hypot(xv, yv);
  const u = v + el.w;
  return {
    r, v,
    x: r * (cos(el.N) * cos(u) - sin(el.N) * sin(u) * cos(el.i)),
    y: r * (sin(el.N) * cos(u) + cos(el.N) * sin(u) * cos(el.i)),
    z: r * sin(u) * sin(el.i),
  };
}

function sunElements(d) {
  return { N: 0, i: 0, w: 282.9404 + 4.70935e-5 * d, a: 1, e: 0.016709 - 1.151e-9 * d, M: 356.047 + 0.9856002585 * d };
}

function sunEcliptic(d) {
  const el = sunElements(d);
  const p = orbitPosition(el);
  const lon = norm360(p.v + el.w);
  return { x: p.r * cos(lon), y: p.r * sin(lon), r: p.r, lon, M: el.M, w: el.w };
}

function eclipticToEquatorial(x, y, z, d) {
  const ecl = 23.4393 - 3.563e-7 * d;
  const ye = y * cos(ecl) - z * sin(ecl);
  const ze = y * sin(ecl) + z * cos(ecl);
  return { ra: norm360(atan2d(ye, x)), dec: atan2d(ze, Math.hypot(x, ye)) };
}

function moonPosition(d) {
  const el = { N: 125.1228 - 0.0529538083 * d, i: 5.1454, w: 318.0634 + 0.1643573223 * d, a: 60.2666, e: 0.0549, M: 115.3654 + 13.0649929509 * d };
  const p = orbitPosition(el);
  const sun = sunEcliptic(d);
  const Mm = el.M, Ms = sun.M;
  const Ls = Ms + sun.w, Lm = Mm + el.w + el.N;
  const D = Lm - Ls, F = Lm - el.N;
  let lon = atan2d(p.y, p.x), lat = atan2d(p.z, Math.hypot(p.x, p.y)), r = p.r;
  lon += -1.274 * sin(Mm - 2 * D) + 0.658 * sin(2 * D) - 0.186 * sin(Ms) - 0.059 * sin(2 * Mm - 2 * D)
    - 0.057 * sin(Mm - 2 * D + Ms) + 0.053 * sin(Mm + 2 * D) + 0.046 * sin(2 * D - Ms) + 0.041 * sin(Mm - Ms)
    - 0.035 * sin(D) - 0.031 * sin(Mm + Ms) - 0.015 * sin(2 * F - 2 * D) + 0.011 * sin(Mm - 4 * D);
  lat += -0.173 * sin(F - 2 * D) - 0.055 * sin(Mm + F - 2 * D) - 0.046 * sin(Mm - F - 2 * D) + 0.033 * sin(F + 2 * D) + 0.017 * sin(2 * Mm + F);
  r += -0.58 * cos(Mm - 2 * D) - 0.46 * cos(2 * D);
  const x = r * cos(lon) * cos(lat), y = r * sin(lon) * cos(lat), z = r * sin(lat);
  return { ...eclipticToEquatorial(x, y, z, d), distEarthRadii: r };
}

function planetPosition(name, d) {
  const el = ELEMENTS[name](d);
  const p = orbitPosition(el);
  let x = p.x, y = p.y, z = p.z;
  if (name === 'jupiter' || name === 'saturn' || name === 'uranus') {
    const Mj = ELEMENTS.jupiter(d).M, Ms = ELEMENTS.saturn(d).M, Mu = ELEMENTS.uranus(d).M;
    let lon = atan2d(y, x), lat = atan2d(z, Math.hypot(x, y));
    const r = p.r;
    if (name === 'jupiter') {
      lon += -0.332 * sin(2 * Mj - 5 * Ms - 67.6) - 0.056 * sin(2 * Mj - 2 * Ms + 21) + 0.042 * sin(3 * Mj - 5 * Ms + 21)
        - 0.036 * sin(Mj - 2 * Ms) + 0.022 * cos(Mj - Ms) + 0.023 * sin(2 * Mj - 3 * Ms + 52) - 0.016 * sin(Mj - 5 * Ms - 69);
    } else if (name === 'saturn') {
      lon += 0.812 * sin(2 * Mj - 5 * Ms - 67.6) - 0.229 * cos(2 * Mj - 4 * Ms - 2) + 0.119 * sin(Mj - 2 * Ms - 3)
        + 0.046 * sin(2 * Mj - 6 * Ms - 69) + 0.014 * sin(Mj - 3 * Ms + 32);
      lat += -0.02 * cos(2 * Mj - 4 * Ms - 2) + 0.018 * sin(2 * Mj - 6 * Ms - 49);
    } else {
      lon += 0.04 * sin(Ms - 2 * Mu + 6) + 0.035 * sin(Ms - 3 * Mu + 33) - 0.015 * sin(Mj - Mu + 20);
    }
    x = r * cos(lon) * cos(lat); y = r * sin(lon) * cos(lat); z = r * sin(lat);
  }
  const sun = sunEcliptic(d);
  return eclipticToEquatorial(x + sun.x, y + sun.y, z, d);
}

/** Geocentric RA/Dec (degrees, of date) for 'sun' | 'moon' | planet name. */
export function solarSystemPosition(name, date) {
  const d = julianDate(date) - 2451543.5; // days since 1999-12-31 0h UT
  if (name === 'sun') { const s = sunEcliptic(d); return eclipticToEquatorial(s.x, s.y, 0, d); }
  if (name === 'moon') return moonPosition(d);
  if (ELEMENTS[name]) return planetPosition(name, d);
  throw new Error('Unknown solar system body: ' + name);
}

/** Alt/Az of a solar-system body. The Moon gets a simple topocentric parallax correction. */
export function solarSystemAltAz(name, latDeg, lonDeg, date) {
  const eq = solarSystemPosition(name, date);
  const h = equatorialToAltAz(eq.ra, eq.dec, latDeg, lonDeg, date);
  if (name === 'moon') {
    const parallax = Math.asin(1 / eq.distEarthRadii) / DEG;
    h.alt -= parallax * cos(h.alt);
  }
  return { ...h, ra: eq.ra, dec: eq.dec };
}
