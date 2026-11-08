# rp_frontend_windows_flutter

## Overview

Flutter desktop application for Windows (hereafter the **APP**) that signs in with eSignet 2.0.0 (OpenID Connect) through an RP backend.

Actors:

- **APP**: this project. It is the one that uses the BACKEND's API.
- **BACKEND**: [rp_backend_dart_frog](https://github.com/alvaroecp/rp_backend_dart_frog). It is the RP towards eSignet and the server towards the APP.
- **BROWSER**: the system's web browser, where the USER authenticates with eSignet.
- **USER**: the person who signs in.
- **eSignet**: the identity provider (OpenID Connect server). The local installation used in the tests is described in [esignet_local_docker](https://github.com/alvaroecp/esignet_local_docker).

Features:

- Signs in with eSignet through the BACKEND. The APP does not talk to eSignet directly and does not receive its tokens: it only holds the BACKEND's `app_token`, in memory.
- Shows the profile: photo, name and email.
- Shows when the session expires, with a live countdown that compares the BACKEND's expiry time with the computer's clock. When it reaches zero, the APP signs out locally.
- Signs out: ends the session in the BACKEND and clears the APP's local state.

Built with Flutter (Windows desktop, Dart `^3.13.7`), `http` for the requests and `url_launcher` to open the BROWSER.

**Status.** Learning project. In the tests it worked end to end with the BACKEND on Windows. Known limitations: the BACKEND's URL is fixed in the code, there is no cancel button while the APP waits for the USER (it waits until the ticket expires, 300 s), the texts on the screen are in Spanish, and it has no automated tests of its own.

## Integration with the BACKEND

The APP talks only to the BACKEND, by HTTP and JSON. The BACKEND's URL is the constant `backendUrl` in `lib/services/auth_service.dart` (`http://localhost:3005`). The integration lives in that file; the screen is `lib/screens/home_screen.dart`. For the full API, see the BACKEND's README.

| Step | What the APP does | BACKEND endpoint | Result |
| --- | --- | --- | --- |
| 1 | Asks for a ticket | `POST /api/login/start` | `ticket`, `poll_secret`, `login_url`, `expires_in` and `interval` |
| 2 | Opens the `login_url` in the BROWSER | — | The USER authenticates with eSignet there |
| 3 | Polls the status every `interval` seconds | `GET /api/login/status?ticket=…` with the `X-Poll-Secret` header | `pending`, until `complete` with the `app_token`, or `error` |
| 4 | Reads the profile | `GET /api/me` with `Authorization: Bearer <app_token>` | Profile, `sub` and `session_expires_at` |
| 5 | Signs out | `POST /api/logout` with `Authorization: Bearer <app_token>` | `204`. The APP clears its local state even if the call fails |

In the tests, the `picture` field of the profile arrived as an inline image (`data:image/jpeg;base64,…`): the APP decodes it and draws it from memory.

When something goes wrong:

| Situation | What the APP does |
| --- | --- |
| `start` does not return `200` | Shows an error with the status code |
| `status` does not return `200` (`403`, `404`, `410`…) | Stops polling and shows an error |
| `status` returns `error` | Stops polling and shows an error: the sign-in failed at the provider |
| No `complete` after `expires_in` seconds | Stops polling and shows a timeout error |
| `me` returns `401`, or the countdown reaches zero | Signs out locally and asks the USER to sign in again |

## Running

Requirements:

- [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop) (stable channel, Dart `^3.13.7`) with Windows desktop support. `flutter doctor` shows whether the Windows toolchain is ready.
- The BACKEND and eSignet running. See the BACKEND's README, which also says how to create the keys and register the client. In the tests, the BACKEND ran in WSL and the APP reached it through `localhost`.

The `windows/` folder (the native Windows project) is not in this repository, because Flutter generates it. After cloning, create it once:

```bash
flutter create --platforms=windows .
```

Start the BACKEND first, then run the APP from the project folder:

```bash
flutter pub get
flutter run -d windows
```

Press the sign-in button: the BROWSER opens, the USER authenticates with eSignet, and the APP shows the profile.

If the BACKEND is not at `http://localhost:3005`, change `backendUrl` in `lib/services/auth_service.dart`.
