# 🏃 SportBoard

<p align="left">
  <img src="https://img.shields.io/badge/iOS-SwiftUI-blue?logo=swift" alt="iOS SwiftUI" />
  <img src="https://img.shields.io/badge/Language-Swift%205-orange?logo=swift" alt="Swift 5" />
  <img src="https://img.shields.io/badge/Architecture-MVVM%20%2B%20SwiftData-6f42c1" alt="MVVM + SwiftData" />
  <img src="https://img.shields.io/badge/Data-Strava%20API-FC4C02?logo=strava" alt="Strava API" />
  <img src="https://img.shields.io/badge/Status-Active%20Development-brightgreen" alt="Active Development" />
</p>

Aplicación iOS para **sincronizar, analizar y entender entrenamientos (especialmente running) desde Strava**, con métricas, inteligencia local y vistas accionables para mejorar constancia, fatiga y progresión.

---

## ✨ ¿Qué es SportBoard y para quién es?

**SportBoard** está pensado para deportistas (sobre todo runners) que quieren algo más que el resumen básico de Strava:

- Ver sus datos de forma clara y útil.
- Entender tendencias de entrenamiento.
- Detectar señales de fatiga/inconsistencia.
- Obtener recomendaciones simples para el siguiente entreno.

Ideal para quien quiere una “segunda capa” de análisis sobre su historial de actividad.

---

## 🚀 Funcionalidades principales

- **Login OAuth con Strava** (`ASWebAuthenticationSession` + Keychain).
- **Sincronización incremental e histórica** de actividades.
- **Gestión de límites de API** (rate limits, pausas/reintentos).
- **Dashboard** con métricas agregadas (distancia, tiempo, elevación, HR).
- **Vista de inteligencia** con:
  - clasificación de entrenos,
  - consistencia semanal,
  - fatiga estimada,
  - narrativa semanal,
  - sugerencia de próximo entrenamiento,
  - alertas silenciosas.
- **Detalle de actividad** con splits/laps y reflexión post-entreno.
- **Exportación JSON para web**.
- **Suite de tests** con fixtures y golden files.

---

## 🧱 Stack técnico / Arquitectura

### Tecnologías

- **Swift 5**
- **SwiftUI**
- **SwiftData** (persistencia local)
- **Foundation / Combine**
- **AuthenticationServices** (OAuth móvil)
- **Keychain** (gestión de tokens)
- **Xcode project** (`.xcodeproj`, sin workspace)

### Estructura del proyecto

```text
SportBoardApp/
├── Models/                 # Entidades de dominio (Activity, Athlete, SyncState, etc.)
├── Services/               # Auth, Strava API, sync e inteligencia
│   └── Intelligence/       # Motor de análisis local
├── ViewModels/             # Lógica de presentación (MVVM)
├── Views/                  # UI por módulos (Dashboard, Activities, Intelligence, Auth, Sync)
└── Utilities/              # Helpers, extensiones, export JSON, constants
SportBoardAppTests/
├── Intelligence/
├── Fixtures/
├── GoldenFiles/
└── TestSupport/
```

### Patrón

- Enfoque **MVVM + Services + SwiftData**.
- Flujo general: `Strava API -> SyncService -> SwiftData -> ViewModels -> Views`.

---

## ⚙️ Instalación (paso a paso)

### Requisitos

- macOS con Xcode instalado.
- Simulador iOS disponible.
- App de Strava registrada para OAuth (client id/secret/redirect URI).

### 1) Clonar el repositorio

```bash
git clone https://github.com/DavidCerroS/SportBoard.git
cd SportBoard
```

### 2) Configurar constantes privadas

Hay un archivo ejemplo:

- `SportBoardApp/Utilities/Constants.example.swift`

Crea tu archivo real `Constants.swift` (o adapta el existente según tu setup) con:

- `clientId`
- `clientSecret`
- `redirectUri`

> No subas credenciales reales al repositorio.

### 3) Abrir en Xcode

Abre:

- `SportBoardApp.xcodeproj`

### 4) Ejecutar

Selecciona esquema **SportBoardApp** y ejecuta en simulador/dispositivo.

---

## ▶️ Uso básico

1. Abre la app.
2. Inicia sesión con Strava.
3. Lanza sincronización inicial.
4. Revisa:
   - **Dashboard** para métricas generales.
   - **Inteligencia** para análisis y sugerencias.
   - **Actividades** para detalle, laps/splits y exportación.

---

## 🧪 Testing

Comando sugerido del proyecto:

```bash
xcodebuild test -project SportBoardApp.xcodeproj -scheme SportBoardApp -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

Notas:

- Fixtures en `SportBoardAppTests/Fixtures`.
- Soporte de test en `SportBoardAppTests/TestSupport`.
- Casos de inteligencia en `SportBoardAppTests/Intelligence`.

---

## 🗺️ Roadmap (propuesto)

- [ ] CI en GitHub Actions (build + tests automáticos).
- [ ] Capturas reales y mejora visual de README.
- [ ] Métricas comparativas por bloques/mesociclos.
- [ ] Exportes adicionales (CSV/PDF).
- [ ] Soporte para más tipos de deporte con vistas específicas.
- [ ] Internacionalización completa de la UI.

---

## 🤝 Contribución

Las contribuciones son bienvenidas.

1. Haz fork del repo.
2. Crea una rama de trabajo:
   - `feature/...`
   - `fix/...`
3. Abre Pull Request con:
   - contexto,
   - cambios realizados,
   - validación/tests.

Si vas a proponer cambios grandes, abre antes un issue para alinear enfoque.

---

## 📄 Licencia

Actualmente no hay un archivo `LICENSE` en el repositorio.  
Recomendación: añadir una licencia explícita (por ejemplo, MIT) para aclarar uso y contribución.
