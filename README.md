# SELOASA Evidencias
## Lanzamiento de versión 1.1.0: 04/05/2026


Aplicación Flutter para operación logística enfocada en captura de evidencias de entrega, reporte de incidencias y acceso rápido para personal de ruta dentro del ecosistema OneRoute/SELOASA.

Versión actual del proyecto: `1.1.0+1`

## Objetivo

Esta app centraliza cuatro flujos operativos:

1. Consulta de guías pendientes por usuario autenticado.
2. Consulta de órdenes de servicio por guía.
3. Captura y envío de evidencias de entrega con fotografía.
4. (beta) Checklist de inspección de salida/entrada de unidad y reporte de incidencias.

## Stack técnico

- `Flutter` / `Dart`
- `flutter_riverpod` para manejo de estado
- `go_router` para navegación
- `http` y `dio` para consumo HTTP
- `flutter_secure_storage` para persistencia segura
- `camera`, `image_picker`, `google_mlkit_document_scanner` para captura de evidencia
- `home_widget` para widget en Android
- `local_auth` para biometría
- `google_fonts` para tipografía

## Arquitectura actual

La app está organizada por features y capas ligeras:

- `lib/app`
  - `app_router.dart`: definición de rutas, redirect por autenticación y deep links.
  - `app_shell.dart`: contenedor de navegación principal.
  - `theme.dart` / `theme_provider.dart`: configuración visual y persistencia de tema.
- `lib/core`
  - `config/app_api_config.dart`: resolución de endpoints base.
  - `services/widget_service.dart`: integración con widget nativo.
- `lib/features/auth`
  - login, sesión persistente, auto-login y almacenamiento de token.
- `lib/features/home`
  - dashboard, rutas pendientes, detalle de ruta y envío de evidencias.
- `lib/features/checklist`
  - checklist de salida/entrada, selección de unidad y mapa de daños.
- `lib/features/incidents`
  - captura y envío de incidencias con foto opcional.
- `lib/features/settings`
  - tema, biometría y cierre de sesión.

## Funcionalidad implementada

### 1. Autenticación

- Login contra backend externo.
- Persistencia de token en almacenamiento seguro.
- Persistencia de usuario y contraseña para reingreso automático.
- Opción de acceso biométrico.

Archivo clave:

- [lib/features/auth/presentation/auth_provider.dart](seloasa_evidencias/lib/features/auth/presentation/auth_provider.dart)

### 2. Dashboard operativo

- Saludo contextual.
- Conteo de rutas pendientes.
- Acceso a incidencias.

Archivo clave:

- [lib/features/home/dashboard_screen.dart](seloasa_evidencias/lib/features/home/dashboard_screen.dart)

### 3. Consulta de guías y órdenes

- Listado de guías pendientes por usuario.
- Búsqueda local en memoria.
- Navegación a detalle de ruta.
- Consulta de órdenes de servicio por guía.

Archivos clave:

- [lib/features/home/pending_routes/home_screen.dart](seloasa_evidencias/lib/features/home/pending_routes/home_screen.dart)
- [lib/features/home/pending_routes/route_detail/route_detail_screen.dart](seloasa_evidencias/lib/features/home/pending_routes/route_detail/route_detail_screen.dart)
- [lib/features/home/data/route_service.dart](seloasa_evidencias/lib/features/home/data/route_service.dart)

### 4. Captura de evidencias

- Selección de orden de servicio.
- Formulario de evidencia.
- Soporte para fotografía por archivo, bytes o base64.
- Subida paralela al backend de evidencias y al portal SELOASA.

Archivo clave:

- [lib/features/home/data/route_service.dart](seloasa_evidencias/lib/features/home/data/route_service.dart)

### 5. Checklist de unidad (Beta)

- Checklist de salida.
- Checklist de entrada bloqueado hasta completar salida.
- Selección de unidad desde backend.
- Registro de observaciones.
- Mapa visual de daños sobre diagrama de camión.

Archivos clave:

- [lib/features/checklist/checklist_history_screen.dart](seloasa_evidencias/lib/features/checklist/checklist_history_screen.dart)
- [lib/features/checklist/checklist_screen.dart](seloasa_evidencias/lib/features/checklist/checklist_screen.dart)

### 6. Reporte de incidencias

- Tipificación por categoría.
- Comentarios libres.
- Captura documental/fotográfica.
- Envío manual o automático por deep link/widget.

Archivo clave:

- [lib/features/incidents/presentation/incident_report_screen.dart](seloasa_evidencias/lib/features/incidents/presentation/incident_report_screen.dart)

### 7. Widget e integración rápida

- Widget Android vía `home_widget`.
- Actualización de título de ruta.
- Deep link `/incident?type=...&auto=true` para disparar reporte automático.

Archivos clave:

- [lib/core/services/widget_service.dart](seloasa_evidencias/lib/core/services/widget_service.dart)
- [android/app/src/main/kotlin/com/seloasa/seloasa_evidencias/SeloasaWidgetProvider.kt](seloasa_evidencias/android/app/src/main/kotlin/com/seloasa/seloasa_evidencias/SeloasaWidgetProvider.kt)

## Endpoints y configuración real

La app contiene endpoints hardcodeados y también permite override por `--dart-define`.

### URLs base detectadas en código

Backend de evidencias:

- `http://evidenciasoneroute.seloasa.com.mx:3010/api/v1`

Backend de autenticación:

- `https://rutas.seloasa.com.mx/api/seloasa`

Endpoint adicional para subida de imagen al portal:

- `https://rutas.seloasa.com.mx/seloasa/subida-imagen`

### Dart defines soportados

Definidos en [lib/core/config/app_api_config.dart](seloasa_evidencias/lib/core/config/app_api_config.dart):

- `EVIDENCIAS_API_BASE_URL`
- `AUTH_API_BASE_URL`

Ejemplo:

```bash
flutter run ^
  --dart-define=EVIDENCIAS_API_BASE_URL=http://evidenciasoneroute.seloasa.com.mx:3010/api/v1 ^
  --dart-define=AUTH_API_BASE_URL=https://rutas.seloasa.com.mx/api/seloasa
```

## Endpoints consumidos

### Autenticación

- `POST https://rutas.seloasa.com.mx/api/seloasa/auth/login`

Payload esperado:

```json
{
  "user": "usuario",
  "password": "password"
}
```

### Evidencias / rutas

- `GET http://evidenciasoneroute.seloasa.com.mx:3010/api/v1/evidencias/pendientes/{userCode}?userRole={userRole}`
- `GET http://evidenciasoneroute.seloasa.com.mx:3010/api/v1/evidencias/detalle/{numGuia}`
- `POST http://evidenciasoneroute.seloasa.com.mx:3010/api/v1/evidencias/upload`
- `GET http://evidenciasoneroute.seloasa.com.mx:3010/api/v1/unidades`
- `POST http://evidenciasoneroute.seloasa.com.mx:3010/api/v1/api/seloasa/checklist/guardar`

### Portal SELOASA

- `POST https://rutas.seloasa.com.mx/seloasa/subida-imagen`

## Seguridad y persistencia

Persistencia detectada:

- Token: clave `auth_token`
- Tema: clave `app_theme`
- Usuario recordado: clave `saved_user`
- Password recordado: clave `saved_pass`
- Biometría: clave `use_biometrics`

Implementación:

- [lib/features/auth/data/token_storage.dart](seloasa_evidencias/lib/features/auth/data/token_storage.dart)
- [lib/features/settings/presentation/settings_screen.dart](/seloasa_evidencias/lib/features/settings/presentation/settings_screen.dart)


## Navegación

Rutas principales registradas en `GoRouter`:

- `/login`
- `/home`
- `/evidencias`
- `/checklist`
- `/route-detail`
- `/os-capture`
- `/checklist-detail`
- `/incident-report`
- `/incident`
- `/settings`
- `/notifications`

Referencia:

- [lib/app/app_router.dart](seloasa_evidencias/lib/app/app_router.dart)

## Requisitos de desarrollo

- Flutter SDK compatible con `sdk: ^3.9.2`
- Android SDK para compilación móvil
- Xcode para compilación iOS/macOS
- Acceso de red a:
  - `evidenciasoneroute.seloasa.com.mx`
  - `rutas.seloasa.com.mx`

## Instalación

```bash
flutter pub get
flutter run
```

Con configuración explícita:

```bash
flutter run ^
  --dart-define=EVIDENCIAS_API_BASE_URL=http://evidenciasoneroute.seloasa.com.mx:3010/api/v1 ^
  --dart-define=AUTH_API_BASE_URL=https://rutas.seloasa.com.mx/api/seloasa
```

## Build

Android APK:

```bash
flutter build apk
```

Android App Bundle:

```bash
flutter build appbundle
```

Web:

```bash
flutter build web
```

Windows:

```bash
flutter build windows
```

## Assets relevantes

- `assets/images/seloasa_logo.png`
- `assets/images/seloasa_warehouse.png`
- `assets/images/truck_diagram.jpg`
- `assets/images/login_banner.jpg`
- `assets/images/One Route.png`

## Estado actual de la versión 1.1

La versión `1.1.0+1` ya integra:

- flujo de autenticación persistente
- consulta de rutas pendientes
- consulta de órdenes por guía
- carga de evidencias con foto
- checklist de salida y entrada (Beta)
- captura de incidencias
- biometría
- soporte visual para tema claro/oscuro
- widget Android con deep link operativo

## Licencia

Este repositorio incluye archivo [LICENSE].
