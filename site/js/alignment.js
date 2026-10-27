// Orientation sources, calibration and guidance. Pure logic where possible.
import { norm180, norm360, DEG, angularSeparation } from './astro.js';

export const STALE_SENSOR_MS = 3000;
export const STALE_SOLVE_MS = 60000;
export const STALE_MANUAL_MS = 5 * 60000;

/** Signed shortest azimuth difference target - current, in (-180, 180]. */
export function azDelta(currentAz, targetAz) {
  const d = norm180(targetAz - currentAz);
  return d === -180 ? 180 : d;
}

/** Guidance from pointing (alt/az) to target (alt/az). */
export function computeGuidance(pointing, target, toleranceDeg = 1) {
  const dAz = azDelta(pointing.az, target.az);
  const dAlt = target.alt - pointing.alt;
  const separation = angularSeparation(pointing.alt, pointing.az, target.alt, target.az);
  const onTarget = separation <= toleranceDeg;
  const parts = [];
  if (Math.abs(dAz) * Math.cos(pointing.alt * DEG) > toleranceDeg / 2) {
    parts.push(`${dAz > 0 ? 'RIGHT' : 'LEFT'} ${Math.abs(dAz).toFixed(1)}°`);
  }
  if (Math.abs(dAlt) > toleranceDeg / 2) parts.push(`${dAlt > 0 ? 'UP' : 'DOWN'} ${Math.abs(dAlt).toFixed(1)}°`);
  const text = onTarget ? 'On target' : parts.length ? 'Move ' + parts.join(', ') : 'Fine-tune slightly';
  return { dAz, dAlt, separation, onTarget, text };
}

/** Pointing direction of a phone's back camera from DeviceOrientation angles (degrees). */
export function deviceToPointing(alpha, beta, gamma) {
  const a = alpha * DEG, b = beta * DEG, g = gamma * DEG;
  const e = -(Math.cos(a) * Math.sin(g) + Math.sin(a) * Math.sin(b) * Math.cos(g));
  const n = -(Math.sin(a) * Math.sin(g) - Math.cos(a) * Math.sin(b) * Math.cos(g));
  const u = -(Math.cos(b) * Math.cos(g));
  return { alt: Math.asin(Math.max(-1, Math.min(1, u))) / DEG, az: norm360(Math.atan2(e, n) / DEG) };
}

/**
 * Tracks where the telescope points. Priority: fresh plate solve > calibrated sensor > manual (static).
 * Sensors only give *relative* truth once an offset has been calibrated, so a sensor reading
 * without calibration is never used for guidance.
 */
export class Orientation {
  constructor(now = () => Date.now()) {
    this.now = now;
    this.raw = null;          // {alt, az, t} latest sensor reading
    this.offset = null;       // {alt, az} added to raw
    this.solve = null;        // {alt, az, t}
    this.manual = null;       // {alt, az, t}
    this.calibratedAt = null;
    this.calibrationRaw = null;
  }

  updateSensor(alt, az) { this.raw = { alt, az, t: this.now() }; }

  setPlateSolve(alt, az) {
    this.calibrate(alt, az);
    this.solve = { alt, az, t: this.now() };
  }

  /** Calibrate: the telescope is pointing at (alt, az) right now. */
  calibrate(alt, az) {
    const t = this.now();
    this.manual = { alt, az, t };
    this.calibratedAt = t;
    if (this.raw && t - this.raw.t < STALE_SENSOR_MS) {
      this.offset = { alt: alt - this.raw.alt, az: azDelta(this.raw.az, az) };
      this.calibrationRaw = { alt: this.raw.alt, az: this.raw.az };
    } else {
      this.offset = null;
      this.calibrationRaw = null;
    }
  }

  clear() { this.offset = null; this.solve = null; this.manual = null; this.calibratedAt = null; this.calibrationRaw = null; }

  /** @returns {{state:'none'|'ok', source?:string, alt?:number, az?:number, warnings:string[]}} */
  current() {
    const t = this.now();
    const warnings = [];
    if (this.solve && t - this.solve.t < STALE_SOLVE_MS) {
      return { state: 'ok', source: 'plate solve', alt: this.solve.alt, az: this.solve.az, warnings };
    }
    if (this.offset && this.raw) {
      if (t - this.raw.t > STALE_SENSOR_MS) {
        warnings.push('Orientation sensor data is stale — guidance may be wrong.');
      }
      const moved = this.calibrationRaw ? angularSeparation(this.raw.alt, this.raw.az, this.calibrationRaw.alt, this.calibrationRaw.az) : 0;
      if (moved > 30 && t - this.calibratedAt > STALE_MANUAL_MS) warnings.push('Telescope moved a long way since calibration — recalibrate.');
      return { state: 'ok', source: 'device sensors', alt: this.raw.alt + this.offset.alt, az: norm360(this.raw.az + this.offset.az), warnings };
    }
    if (this.manual) {
      warnings.push('Manual calibration is static — it does not follow the telescope. Recalibrate after moving.');
      if (t - this.manual.t > STALE_MANUAL_MS) warnings.push('Calibration is old — recalibrate before trusting guidance.');
      return { state: 'ok', source: 'manual calibration', alt: this.manual.alt, az: this.manual.az, warnings };
    }
    return { state: 'none', warnings };
  }
}
