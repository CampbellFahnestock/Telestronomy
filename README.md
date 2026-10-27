# my_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web app

A dependency-light offline PWA lives in [`site/`](site/README.md) (the Flutter code is untouched).

- Live: https://campbellfahnestock.github.io/Telestronomy/
- Run locally: `cd site && python -m http.server 8000`, open http://localhost:8000
- Tests: `node --test` (from the repo root or `site/`)
- Camera bridge (SV905C / mock mode): `cd bridge && pip install -r requirements.txt && python bridge.py --backend mock`,
  then open http://localhost:8080/. See [docs/camera-bridge-api.md](docs/camera-bridge-api.md).
