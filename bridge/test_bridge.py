import json
import unittest

from bridge import MockCamera, create_app, make_solver


class BridgeTests(unittest.TestCase):
    def setUp(self):
        cam = MockCamera()
        cam.open()
        self.client = create_app(cam, None, serve_site=False).test_client()

    def test_status(self):
        s = self.client.get("/status").get_json()
        self.assertTrue(s["mock"])
        self.assertTrue(s["capabilities"]["capture"])
        self.assertFalse(s["capabilities"]["solve"])

    def test_capture_is_jpeg(self):
        r = self.client.post("/capture")
        self.assertEqual(r.mimetype, "image/jpeg")
        self.assertTrue(r.data.startswith(b"\xff\xd8"))

    def test_settings_roundtrip_and_validation(self):
        r = self.client.post("/settings", data=json.dumps({"exposure_ms": 100, "gain": 10}), content_type="application/json")
        self.assertEqual(r.get_json()["exposure_ms"], 100)
        bad = self.client.post("/settings", data=json.dumps({"gain": "x"}), content_type="application/json")
        self.assertEqual(bad.status_code, 400)

    def test_solve_unavailable_then_mock(self):
        self.assertEqual(self.client.post("/solve").status_code, 501)
        cam = MockCamera()
        c2 = create_app(cam, make_solver((10.0, 20.0)), serve_site=False).test_client()
        r = c2.post("/solve").get_json()
        self.assertTrue(r["solved"])
        self.assertEqual(r["ra"], 10.0)

    def test_cors_header(self):
        self.assertEqual(self.client.get("/status").headers["Access-Control-Allow-Origin"], "*")


if __name__ == "__main__":
    unittest.main()
