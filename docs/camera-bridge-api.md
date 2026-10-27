# Telestronomy camera bridge API

The browser cannot talk to a USB astronomy camera (e.g. the **SVBONY SV905C**) directly. A small
**bridge** program runs on a computer or Raspberry Pi that has the camera attached and exposes
the HTTP API below on the local network. The reference implementation is [`bridge/bridge.py`](../bridge/bridge.py).

Base URL default: `http://raspberrypi.local:8080` (configurable in the app, saved in localStorage).

All responses carry CORS headers (`Access-Control-Allow-Origin: *`,
`Access-Control-Allow-Private-Network: true`). Errors are JSON: `{"error": "message"}`.
All angles are decimal degrees, equatorial coordinates are **J2000**.

## `GET /status`
```json
{
  "ok": true,
  "bridge_version": "1.0",
  "backend": "opencv",
  "mock": false,
  "camera": { "connected": true, "name": "UVC camera 0" },
  "capabilities": { "stream": true, "capture": true, "settings": true, "solve": false }
}
```
The UI polls this endpoint (backing off 2 s → 30 s while unreachable). `capabilities` controls which UI
controls are enabled: exposure/gain sliders need `settings`, plate solving needs `solve`.

## `GET /stream.mjpeg`
`multipart/x-mixed-replace; boundary=frame` stream of JPEG frames, usable directly as an `<img src>`.

## `POST /capture`
Takes a body of `{}` (optional). Returns one frame as `image/jpeg`. `503` with an error JSON if the camera is unavailable.

## `GET /settings`
```json
{ "exposure_ms": 500, "gain": 50, "exposure_ms_range": [1, 5000], "gain_range": [0, 100] }
```
`501` if the camera does not support settings.

## `POST /settings`
Body: `{ "exposure_ms": 200, "gain": 30 }` (either field optional; values are clamped to the ranges).
Returns the same JSON as `GET /settings`. `400` for non-numeric values.

## `POST /solve`
Plate-solves a fresh frame (body may be `{}`). Success:
```json
{ "solved": true, "ra": 37.95, "dec": 89.26, "roll": 12.3, "fov_deg": 2.1 }
```
Failure: `{ "solved": false, "error": "no solution" }`. `501` if the bridge has no solver
(`capabilities.solve` is `false`); the app then shows "plate solve unavailable" and offers manual calibration.

## Running the reference bridge
```bash
cd bridge
pip install -r requirements.txt
python bridge.py --backend mock                 # no hardware: generated star field
python bridge.py --backend opencv --device 0    # UVC camera
python bridge.py --backend mock --mock-solve 37.95,89.26   # demo-only fake plate solve
```
The bridge also serves `../site/` at `/`, so open `http://<bridge-host>:8080/` for a fully local install.

### SVBONY SV905C setup
The SV905C is a **UVC** (USB Video Class) camera, so it needs no vendor driver on Linux/macOS/Windows.
1. Plug it in and check: `lsusb` and `v4l2-ctl --list-devices` (package `v4l-utils`). Note the `/dev/videoN` index.
2. Add your user to the `video` group: `sudo usermod -aG video $USER` (re-login).
3. Run `python bridge.py --backend opencv --device 0`.
4. Exposure/gain through `CAP_PROP_EXPOSURE` / `CAP_PROP_GAIN` depend on the driver; check
   `v4l2-ctl -d /dev/video0 --list-ctrls`. Long exposures may need `v4l2-ctl --set-ctrl exposure_time_absolute=...`
   or a vendor SDK/INDI backend. Unsupported controls simply have no effect.

### Adding another backend (INDI, libcamera, ZWO/`zwoasi`, vendor SDK)
Subclass `CameraBackend` in `bridge.py` and implement `open`, `connected`, `get_settings`,
`set_settings`, `grab_jpeg` and `close`, then register it in `BACKENDS`. For plate solving,
pass a `solver(jpeg_bytes) -> {ra, dec, roll, fov_deg}` function to `create_app` (e.g. wrapping
astrometry.net `solve-field`, ASTAP or tetra3).

## HTTPS ↔ HTTP (mixed content)
The GitHub Pages site is served over **HTTPS**. Browsers block `http://` requests from an HTTPS page
("mixed content"), except to `localhost`. Options:
1. **Open the app from the bridge** — `http://raspberrypi.local:8080/` — the page and API share an origin
   and the service worker caches the app for offline use. (Installability needs a secure context, so use option 2 or `localhost` if you want to install it.)
2. **Serve the bridge over HTTPS**: `python bridge.py --cert cert.pem --key key.pem` (e.g. a certificate from
   [mkcert](https://github.com/FiloSottile/mkcert) trusted on your phone) and use `https://…` as the bridge URL.
3. Run the bridge on the same computer as the browser and use `http://localhost:8080`.
