# Telestronomy web app (PWA)

Plain HTML, CSS and ES modules — no build step, no CDN, system fonts only.

```bash
cd site
python -m http.server 8000   # then open http://localhost:8000
node --test                  # astronomy math / alignment / star-detection tests
```

Live site: https://campbellfahnestock.github.io/Telestronomy/ (deployed from `site/` by `.github/workflows/deploy-pages.yml`).

## Layout
| Path | Purpose |
|------|---------|
| `index.html`, `styles.css` | UI (dark theme, night-vision red theme) |
| `js/astro.js` | Julian date, GMST/LST, precession, RA/Dec→Alt/Az, Sun/Moon/planet ephemeris (Schlyter) |
| `js/catalogue.js`, `data/objects.json` | Offline catalogue (RA/Dec J2000 in decimal degrees; solar-system bodies use `ephemeris`) |
| `js/location.js` | GPS (user-initiated), manual entry, localStorage |
| `js/camera.js`, `js/starfinder.js` | Bridge client with auto-retry; star detection |
| `js/alignment.js` | Calibration, orientation sources, guidance |
| `sw.js`, `manifest.webmanifest` | Offline precache and installability (all paths relative) |

When you add or rename files, update the `PRECACHE` list in `sw.js`.

Camera bridge: see [`../docs/camera-bridge-api.md`](../docs/camera-bridge-api.md) and [`../bridge`](../bridge).
