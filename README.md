# Tideline Mobile App

A Flutter mobile client for **Tideline**, a community platform for reporting coastal and marine
pollution and organising clean-up projects in Sri Lanka. It talks to a Spring Boot REST API and
offers the same workflows as the Tideline website.

> **The Spring Boot backend is maintained separately and is not included in this repository.**
> You need a running Tideline API to sign in and load data (see [Connecting to the API](#connecting-to-the-api)).

## Objectives

- Let anyone browse public pollution reports, clean-up projects and national statistics.
- Let members report pollution (with photos and location), confirm and discuss reports, and join clean-ups.
- Give administrators and government officers the tools to verify accounts and review reports.
- Use real data from the API only: nothing is hard-coded or mocked in the app.

## Features

Everything below is implemented in `lib/` and covered by the tests in `test/`.

- **Public landing page** shown to signed-out visitors, with live figures from the API.
- **Accounts**: sign in (with "remember me"), registration with certificate/licence uploads for
  verified roles, password reset from an emailed link, profile viewing and editing, avatar upload.
- **Demo Accounts shortcut** on the sign-in screen: lists accounts the server chooses to offer (role and
  email only) and fills in the email; the password is never filled in.
- **Pollution reports**: feed with filters, create a report with photos and a "use my current
  location" option, report details, confirm / dispute votes, threaded comments with reactions,
  and answering information requests.
- **Clean-up projects**: browse by province, project details and updates, join a project with a role,
  like and comment on updates, plan resources.
- **Calls for help and alerts**: notifications with unread count, and replying to a nearby call
  to join a clean-up.
- **Opportunities**: list, apply, and manage applications.
- **Analytics dashboard**: totals, status bar chart, reports by district, stages, provinces and an
  attention list, with a district filter and automatic refresh.
- **Administrator / government officer consoles**: review queues for reports, account verification
  with document viewing, and user suspension.
- Role-based navigation: guest, member, and console shells.

## Technology stack

| Area | Technology |
| --- | --- |
| Language / framework | Dart (SDK `^3.11`), Flutter, Material 3 |
| Networking | `http` |
| Secure session storage | `flutter_secure_storage` |
| Media | `image_picker`, `file_picker`, `http_parser` |
| Location | `geolocator` |
| Typefaces | Sora, Instrument Sans, JetBrains Mono (bundled, SIL Open Font License) |
| Quality | `flutter_lints`, `flutter_test` |

## Architecture

The app is organised in layers under `lib/`:

- `core/` – API client, configuration, theme, formatting, location and upload helpers, alert polling.
- `auth/` – `AuthController`, a `ChangeNotifier` holding the session and signed-in user.
- `models/` – plain Dart models parsed defensively from the API's JSON.
- `screens/` – one file per screen, plus the navigation shells.
- `widgets/` – shared UI pieces (brand, cards, pickers, resource planner).

State is kept with `ChangeNotifier` controllers and `setState`; there is no additional state-management package.

## Folder structure

```
.
├── android/          Android project
├── web/              Web runner (used for development in Chrome)
├── assets/fonts/     Bundled typefaces
├── lib/
│   ├── main.dart
│   ├── auth/  core/  models/  screens/  widgets/
├── test/             Widget and unit tests (test/e2e needs a live API, see below)
├── pubspec.yaml
└── analysis_options.yaml
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart 3.11 or newer
- Android Studio (Android SDK, emulator) for Android, or Chrome for web
- A running Tideline API (separate repository / deployment)
- JDK 21 for Android builds with Gradle 8.14. If Flutter's bundled JDK is newer than Gradle supports,
  point Gradle at JDK 21 with `org.gradle.java.home` in your own `~/.gradle/gradle.properties`.

## Getting started

```bash
git clone https://github.com/Rasanga086/Tideline-mobile-app.git
cd Tideline-mobile-app
flutter pub get
flutter run
```

## Connecting to the API

The API address is chosen at build time with `--dart-define=API_BASE_URL=...` (see `lib/core/config.dart`).

| Where it runs | Command |
| --- | --- |
| Chrome (Flutter web) | `flutter run -d chrome` uses `http://localhost:8083` |
| Android emulator | `flutter run` uses `http://10.0.2.2:8083` (the host computer) |
| Physical Android phone | `flutter run --dart-define=API_BASE_URL=http://<your-computer-LAN-IP>:8083` |
| Release build | `flutter build apk --dart-define=API_BASE_URL=https://<production-api>` |

**Physical device:** the phone and the computer must be on the same Wi-Fi network, and port 8083 must be
allowed through the computer's firewall. Find the LAN address with `ipconfig` (IPv4 Address).

**Release builds** have no development fallback; one built without `API_BASE_URL` reports that instead of
guessing an address. Plain HTTP is allowed only in debug builds
(`android/app/src/debug/AndroidManifest.xml`); release builds need HTTPS. The release build is currently
signed with the debug key (see `android/app/build.gradle.kts`); add your own signing config before publishing.

When running in Chrome, the API must allow the page's origin (CORS). Run Flutter web on a fixed port that
your API allows, for example `flutter run -d chrome --web-port=4173`.

## Tests and checks

```bash
flutter analyze
flutter test
```

`test/e2e/` contains browser end-to-end tests that need a disposable API and are not part of `flutter test`:

```bash
flutter test --platform chrome test/e2e --dart-define=API_BASE_URL=http://localhost:8084
```

They create new accounts on the target API; never point them at a database you care about. `workflows_web_e2e_test.dart` also needs `--dart-define=E2E_PASSWORD=<password of the seeded demo accounts on that disposable API>`.

## Screenshots

Screenshots have not been added yet.

## Author

**Rasanga086** – [github.com/Rasanga086](https://github.com/Rasanga086)
