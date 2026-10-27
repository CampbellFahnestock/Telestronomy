// Observer location: GPS (only on explicit user action), manual entry, localStorage persistence.
const KEY = 'telestronomy.location';

export function validateCoords(lat, lon) {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return 'Enter numeric latitude and longitude.';
  if (lat < -90 || lat > 90) return 'Latitude must be between -90 and 90.';
  if (lon < -180 || lon > 180) return 'Longitude must be between -180 and 180.';
  return null;
}

export function loadLocation(storage = globalThis.localStorage) {
  try {
    const loc = JSON.parse(storage.getItem(KEY));
    if (loc && !validateCoords(loc.lat, loc.lon)) return loc;
  } catch { /* corrupt or unavailable storage */ }
  return null;
}

export function saveLocation(loc, storage = globalThis.localStorage) {
  try { storage.setItem(KEY, JSON.stringify(loc)); } catch { /* storage full/blocked: keep in memory */ }
}

export function setManualLocation(lat, lon) {
  const err = validateCoords(lat, lon);
  if (err) throw new Error(err);
  const loc = { lat, lon, source: 'manual', savedAt: Date.now() };
  saveLocation(loc);
  return loc;
}

const GEO_ERRORS = {
  1: 'Location permission was denied. Allow location access in your browser settings, or enter coordinates manually.',
  2: 'Your position is unavailable (no GPS fix). Try again outdoors, or enter coordinates manually.',
  3: 'Getting your position timed out. Try again, or enter coordinates manually.',
};

/** Must be called from a user gesture (button tap). Never call on page load. */
export function requestGps() {
  return new Promise((resolve, reject) => {
    if (!('geolocation' in navigator)) {
      reject(new Error('This device/browser has no geolocation support. Enter coordinates manually.'));
      return;
    }
    if (!globalThis.isSecureContext) {
      reject(new Error('GPS requires a secure (HTTPS or localhost) page. Enter coordinates manually.'));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const loc = { lat: pos.coords.latitude, lon: pos.coords.longitude, accuracy: pos.coords.accuracy, source: 'gps', savedAt: Date.now() };
        saveLocation(loc);
        resolve(loc);
      },
      (err) => reject(new Error(GEO_ERRORS[err.code] || 'Could not get location: ' + err.message)),
      { enableHighAccuracy: true, timeout: 20000, maximumAge: 30000 }
    );
  });
}
