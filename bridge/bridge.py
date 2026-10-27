#!/usr/bin/env python3
"""Telestronomy camera bridge: reference implementation of docs/camera-bridge-api.md.

Run without hardware:   python bridge.py --backend mock
Run with a UVC camera:  python bridge.py --backend opencv --device 0
Also serves ../site/ so a fully local install works (open http://<host>:8080/).
"""
import argparse
import io
import math
import os
import random
import threading
import time

from flask import Flask, Response, jsonify, request, send_from_directory
from PIL import Image, ImageDraw, ImageFilter

SITE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "site")


# --------------------------------------------------------------------------
# Camera backend interface. Implement these methods to add INDI, libcamera,
# a vendor SDK, etc.; then register the class in BACKENDS below.
# --------------------------------------------------------------------------
class CameraBackend:
    name = "base"
    mock = False
    camera_name = "unknown"
    # {"exposure_ms": (min, max), "gain": (min, max)}; empty dict => settings unsupported
    ranges = {}

    def open(self):
        """Open the device. Raise RuntimeError with a readable message on failure."""

    def connected(self):
        return True

    def get_settings(self):
        return {}

    def set_settings(self, exposure_ms=None, gain=None):
        """Apply settings (clamped to ranges); return the resulting settings dict."""
        return self.get_settings()

    def grab_jpeg(self):
        """Return one frame as JPEG bytes."""
        raise NotImplementedError

    def close(self):
        pass


class MockCamera(CameraBackend):
    """Generates a deterministic-ish star field so the whole stack can be demoed without hardware."""
    name = "mock"
    mock = True
    camera_name = "Mock camera (generated test image)"
    ranges = {"exposure_ms": (1, 5000), "gain": (0, 100)}

    def __init__(self, width=640, height=480):
        self.w, self.h = width, height
        self.settings = {"exposure_ms": 500, "gain": 50}
        rnd = random.Random(42)
        self.stars = [(rnd.uniform(10, width - 10), rnd.uniform(10, height - 10), rnd.uniform(0.2, 1.0)) for _ in range(60)]
        self.frame_no = 0

    def get_settings(self):
        return dict(self.settings)

    def set_settings(self, exposure_ms=None, gain=None):
        if exposure_ms is not None:
            self.settings["exposure_ms"] = min(max(int(exposure_ms), 1), 5000)
        if gain is not None:
            self.settings["gain"] = min(max(int(gain), 0), 100)
        return self.get_settings()

    def grab_jpeg(self):
        self.frame_no += 1
        brightness = min(1.0, 0.25 + self.settings["exposure_ms"] / 2500 * (0.5 + self.settings["gain"] / 100))
        img = Image.new("L", (self.w, self.h), 8)
        d = ImageDraw.Draw(img)
        drift = math.sin(self.frame_no / 10.0) * 2  # slight motion so the stream visibly updates
        for x, y, mag in self.stars:
            r = 1.5 + 2.5 * mag
            v = int(255 * min(1.0, mag * brightness + 0.2))
            d.ellipse([x + drift - r, y - r, x + drift + r, y + r], fill=v)
        img = img.filter(ImageFilter.GaussianBlur(0.8)).convert("RGB")
        d = ImageDraw.Draw(img)
        d.text((8, 8), "MOCK  exp=%dms gain=%d  #%d" % (self.settings["exposure_ms"], self.settings["gain"], self.frame_no), fill=(90, 140, 255))
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=85)
        return buf.getvalue()


class OpenCVCamera(CameraBackend):
    """UVC cameras such as the SVBONY SV905C via OpenCV (V4L2 on Linux). Exposure/gain support
    depends on the driver; unsupported properties are ignored and reported via /settings."""
    name = "opencv"

    def __init__(self, device=0, width=None, height=None):
        self.device, self.width, self.height = device, width, height
        self.cap = None
        self.settings = {}
        self.lock = threading.Lock()

    def open(self):
        try:
            import cv2  # noqa: F401
        except ImportError as e:
            raise RuntimeError("opencv-python is not installed (pip install opencv-python)") from e
        import cv2
        self.cv2 = cv2
        self.cap = cv2.VideoCapture(self.device)
        if not self.cap.isOpened():
            self.cap = None
            raise RuntimeError("Could not open camera device %r. Check USB, permissions (video group) and `v4l2-ctl --list-devices`." % (self.device,))
        if self.width:
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        if self.height:
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
        self.camera_name = "UVC camera %r" % (self.device,)
        self.ranges = {"exposure_ms": (1, 1000), "gain": (0, 255)}

    def connected(self):
        return self.cap is not None and self.cap.isOpened()

    def get_settings(self):
        if not self.connected():
            return {}
        cv2 = self.cv2
        exp = self.cap.get(cv2.CAP_PROP_EXPOSURE)
        gain = self.cap.get(cv2.CAP_PROP_GAIN)
        return {"exposure_ms": self.settings.get("exposure_ms", exp), "gain": self.settings.get("gain", gain)}

    def set_settings(self, exposure_ms=None, gain=None):
        cv2 = self.cv2
        with self.lock:
            if exposure_ms is not None:
                # V4L2 manual exposure mode (1) then absolute exposure in 100 µs units.
                self.cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 1)
                self.cap.set(cv2.CAP_PROP_EXPOSURE, float(exposure_ms) * 10)
                self.settings["exposure_ms"] = exposure_ms
            if gain is not None:
                self.cap.set(cv2.CAP_PROP_GAIN, float(gain))
                self.settings["gain"] = gain
        return self.get_settings()

    def grab_jpeg(self):
        with self.lock:
            ok, frame = self.cap.read() if self.connected() else (False, None)
        if not ok:
            raise RuntimeError("Camera returned no frame (disconnected?)")
        ok, buf = self.cv2.imencode(".jpg", frame, [self.cv2.IMWRITE_JPEG_QUALITY, 90])
        if not ok:
            raise RuntimeError("JPEG encoding failed")
        return buf.tobytes()

    def close(self):
        if self.cap is not None:
            self.cap.release()
            self.cap = None


BACKENDS = {"mock": MockCamera, "opencv": OpenCVCamera}


# --------------------------------------------------------------------------
# Plate solving: optional. `solve_image(jpeg_bytes)` should return a dict with ra, dec, roll,
# fov_deg (J2000 degrees) or raise RuntimeError. Hook up astrometry.net / tetra3 / ASTAP here.
# --------------------------------------------------------------------------
def make_solver(mock_solve):
    if mock_solve:
        ra, dec = mock_solve

        def solve_image(_jpeg):
            return {"ra": ra, "dec": dec, "roll": 0.0, "fov_deg": 2.0, "mock": True}
        return solve_image
    return None


def create_app(camera, solver=None, serve_site=True):
    app = Flask(__name__)
    state = {"solver": solver}

    @app.after_request
    def cors(resp):
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        resp.headers["Access-Control-Allow-Private-Network"] = "true"
        resp.headers["Cache-Control"] = "no-store"
        return resp

    @app.route("/status")
    def status():
        ok = camera.connected()
        return jsonify({
            "ok": True,
            "bridge_version": "1.0",
            "backend": camera.name,
            "mock": camera.mock,
            "camera": {"connected": ok, "name": camera.camera_name},
            "capabilities": {
                "stream": True, "capture": True,
                "settings": bool(camera.ranges), "solve": state["solver"] is not None,
            },
        })

    @app.route("/settings", methods=["GET", "POST", "OPTIONS"])
    def settings():
        if request.method == "OPTIONS":
            return ("", 204)
        if not camera.ranges:
            return jsonify({"error": "settings not supported by this camera"}), 501
        if request.method == "POST":
            body = request.get_json(silent=True) or {}
            try:
                exp = body.get("exposure_ms")
                gain = body.get("gain")
                if exp is not None:
                    exp = float(exp)
                if gain is not None:
                    gain = float(gain)
            except (TypeError, ValueError):
                return jsonify({"error": "exposure_ms and gain must be numbers"}), 400
            camera.set_settings(exposure_ms=exp, gain=gain)
        s = camera.get_settings()
        s["exposure_ms_range"] = list(camera.ranges["exposure_ms"])
        s["gain_range"] = list(camera.ranges["gain"])
        return jsonify(s)

    @app.route("/capture", methods=["POST", "OPTIONS"])
    def capture():
        if request.method == "OPTIONS":
            return ("", 204)
        try:
            return Response(camera.grab_jpeg(), mimetype="image/jpeg")
        except Exception:  # noqa: BLE001 - report any backend failure to the client
            app.logger.exception("capture failed")
            return jsonify({"error": "camera unavailable or returned no frame"}), 503

    @app.route("/stream.mjpeg")
    def stream():
        def gen():
            while True:
                try:
                    frame = camera.grab_jpeg()
                except Exception:  # noqa: BLE001
                    return  # camera gone: end the stream; the client reconnects
                yield b"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: " + str(len(frame)).encode() + b"\r\n\r\n" + frame + b"\r\n"
                time.sleep(0.2)
        return Response(gen(), mimetype="multipart/x-mixed-replace; boundary=frame")

    @app.route("/solve", methods=["POST", "OPTIONS"])
    def solve():
        if request.method == "OPTIONS":
            return ("", 204)
        if state["solver"] is None:
            return jsonify({"solved": False, "error": "plate solving not available on this bridge"}), 501
        try:
            result = state["solver"](camera.grab_jpeg())
        except Exception:  # noqa: BLE001
            app.logger.exception("solve failed")
            return jsonify({"solved": False, "error": "plate solve failed or no solution found"}), 200
        result["solved"] = True
        return jsonify(result)

    if serve_site and os.path.isdir(SITE_DIR):
        @app.route("/")
        def index():
            return send_from_directory(SITE_DIR, "index.html")

        @app.route("/<path:path>")
        def static_files(path):
            return send_from_directory(SITE_DIR, path)

    return app


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--backend", choices=sorted(BACKENDS), default="mock")
    ap.add_argument("--device", default="0", help="opencv backend: camera index or /dev/videoN")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--cert", help="TLS certificate (PEM) to serve HTTPS")
    ap.add_argument("--key", help="TLS private key (PEM)")
    ap.add_argument("--no-site", action="store_true", help="do not serve ../site/")
    ap.add_argument("--mock-solve", metavar="RA,DEC", help="demo only: /solve always returns this J2000 position (degrees)")
    args = ap.parse_args()

    if args.backend == "opencv":
        dev = int(args.device) if args.device.isdigit() else args.device
        camera = OpenCVCamera(dev)
    else:
        camera = MockCamera()
    try:
        camera.open()
    except RuntimeError as e:
        print("Camera error:", e)
        print("Starting anyway; /status will report the camera as disconnected.")
    mock_solve = tuple(float(x) for x in args.mock_solve.split(",")) if args.mock_solve else None
    app = create_app(camera, make_solver(mock_solve), serve_site=not args.no_site)
    ssl_ctx = (args.cert, args.key) if args.cert and args.key else None
    print("Bridge on %s://%s:%d" % ("https" if ssl_ctx else "http", args.host, args.port))
    app.run(host=args.host, port=args.port, threaded=True, ssl_context=ssl_ctx)


if __name__ == "__main__":
    main()
