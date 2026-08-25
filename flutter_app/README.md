# GuardianEye AI — Flutter Mobile App

Native Flutter Android dashboard for the GuardianEye/JARVIS system.

## Backend contract

The app polls:

`GET /api/alert`

Expected JSON fields:

- `id`
- `type`
- `raw_message`
- `speech`
- `received_at`

The app deliberately does **not** show an alert on startup/refresh. It displays the alert overlay only when the `id` changes.

## Cloudflare

The first server URL is the current Quick Tunnel used during development. Quick Tunnel URLs can change, so the app has a settings button that lets the server URL be changed and saved on the phone.

## Build

From this directory:

```bash
flutter create --platforms=android .
flutter pub get
flutter run
```
