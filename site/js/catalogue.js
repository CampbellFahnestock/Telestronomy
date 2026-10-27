// Offline catalogue loader and position resolver.
import { j2000ToAltAz, solarSystemAltAz } from './astro.js';

let objects = [];

export async function loadCatalogue(url = './data/objects.json') {
  const res = await fetch(url);
  if (!res.ok) throw new Error('Catalogue load failed: HTTP ' + res.status);
  const data = await res.json();
  setCatalogue(data.objects);
  return objects;
}

export function setCatalogue(list) { objects = list; }
export function getObjects() { return objects; }

/** Alt/Az (and ra/dec where known) of a catalogue entry for the given observer and time. */
export function positionOf(obj, lat, lon, date) {
  if (obj.ephemeris) return solarSystemAltAz(obj.ephemeris, lat, lon, date);
  return j2000ToAltAz(obj.ra, obj.dec, lat, lon, date);
}

export function searchObjects(query, list = objects) {
  const q = query.trim().toLowerCase();
  if (!q) return list;
  return list.filter((o) => o.name.toLowerCase().includes(q) || o.type.toLowerCase().includes(q));
}
