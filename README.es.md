# rp_frontend_windows_flutter

## Descripción general

Aplicación de escritorio en Flutter para Windows (en adelante la **APP**) que inicia sesión con eSignet 2.0.0 (OpenID Connect) a través de un backend RP.

Actores:

- **APP**: este proyecto. Es quien usa la API del BACKEND.
- **BACKEND**: [rp_backend_dart_frog](https://github.com/alvaroecp/rp_backend_dart_frog). Es el RP frente a eSignet y el servidor frente a la APP.
- **NAVEGADOR**: el navegador web del sistema, donde el USUARIO se autentica en eSignet.
- **USUARIO**: la persona que inicia sesión.
- **eSignet**: el proveedor de identidad (servidor OpenID Connect).

Funcionalidad:

- Inicia sesión con eSignet a través del BACKEND. La APP nunca habla con eSignet ni ve los tokens de eSignet: solo guarda en memoria el `app_token` del BACKEND.
- Muestra el perfil: foto, nombre y correo.
- Muestra cuándo caduca la sesión, con una cuenta atrás en vivo que compara la hora de caducidad del BACKEND con el reloj del equipo. Cuando llega a cero, la APP cierra la sesión localmente.
- Cierra la sesión: la termina en el BACKEND y limpia el estado local de la APP.

Hecha con Flutter (escritorio Windows, Dart `^3.13.7`), `http` para las peticiones y `url_launcher` para abrir el NAVEGADOR.

**Estado.** Proyecto de aprendizaje. Funciona de punta a punta con el BACKEND en Windows. Limitaciones conocidas: la URL del BACKEND está fija en el código, no hay botón para cancelar mientras la APP espera al USUARIO (espera hasta que caduca el ticket, 300 s), los textos de la pantalla están en español y no tiene pruebas automáticas propias.

## Integración con el BACKEND

La APP solo habla con el BACKEND, por HTTP y con JSON. La URL del BACKEND es la constante `backendUrl` de `lib/services/auth_service.dart` (`http://localhost:3005`). La integración vive en ese archivo; la pantalla es `lib/screens/home_screen.dart`. Para ver la API completa, consulta el README del BACKEND.

| Paso | Qué hace la APP | Endpoint del BACKEND | Resultado |
| --- | --- | --- | --- |
| 1 | Pide un ticket | `POST /api/login/start` | `ticket`, `poll_secret`, `login_url`, `expires_in` e `interval` |
| 2 | Abre el `login_url` en el NAVEGADOR | — | El USUARIO se autentica allí con eSignet |
| 3 | Consulta el estado cada `interval` segundos | `GET /api/login/status?ticket=…` con la cabecera `X-Poll-Secret` | `pending`, hasta `complete` con el `app_token`, o `error` |
| 4 | Lee el perfil | `GET /api/me` con `Authorization: Bearer <app_token>` | Perfil, `sub` y `session_expires_at` |
| 5 | Cierra la sesión | `POST /api/logout` con `Authorization: Bearer <app_token>` | `204`. La APP limpia su estado local aunque la llamada falle |

El campo `picture` del perfil llega como una imagen en línea (`data:image/jpeg;base64,…`): la APP la decodifica y la dibuja desde la memoria.

Cuando algo falla:

| Situación | Qué hace la APP |
| --- | --- |
| `start` no devuelve `200` | Muestra un error con el código de estado |
| `status` no devuelve `200` (`403`, `404`, `410`…) | Deja de consultar y muestra un error |
| `status` devuelve `error` | Deja de consultar y muestra un error: el inicio de sesión falló en el proveedor |
| No llega `complete` tras `expires_in` segundos | Deja de consultar y muestra un error de tiempo agotado |
| `me` devuelve `401`, o la cuenta atrás llega a cero | Cierra la sesión localmente y pide al USUARIO que inicie sesión otra vez |

## Cómo ejecutarlo

Requisitos:

- [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop) (canal stable, Dart `^3.13.7`) con soporte para escritorio Windows. `flutter doctor` indica si la cadena de herramientas de Windows está lista.
- El BACKEND y eSignet en marcha. Consulta el README del BACKEND. El BACKEND puede ejecutarse en WSL: la APP lo alcanza por `localhost`.

La carpeta `windows/` (el proyecto nativo de Windows) no está en este repositorio, porque la genera Flutter. Tras clonarlo, créala una sola vez:

```bash
flutter create --platforms=windows .
```

Arranca primero el BACKEND y después ejecuta la APP desde la carpeta del proyecto:

```bash
flutter pub get
flutter run -d windows
```

Pulsa el botón de inicio de sesión: se abre el NAVEGADOR, el USUARIO se autentica en eSignet y la APP muestra el perfil.

Si el BACKEND no está en `http://localhost:3005`, cambia `backendUrl` en `lib/services/auth_service.dart`.
