# 🏃‍♂️ SportBoard

<p align="left">
  <img src="https://img.shields.io/badge/iOS-SwiftUI-blue?logo=swift" alt="iOS SwiftUI" />
  <img src="https://img.shields.io/badge/Language-Swift%205-orange?logo=swift" alt="Swift 5" />
  <img src="https://img.shields.io/badge/Architecture-MVVM%20%2B%20SwiftData-6f42c1" alt="MVVM + SwiftData" />
  <img src="https://img.shields.io/badge/Integration-Strava%20API-FC4C02?logo=strava" alt="Strava API" />
  <img src="https://img.shields.io/badge/Status-Active%20Development-brightgreen" alt="Active Development" />
</p>

SportBoard es una app iOS para **sincronizar, analizar y entender entrenamientos de Strava** (especialmente running), con foco en métricas accionables, consistencia y señales de fatiga para mejorar el rendimiento.

---

## ✨ Qué ofrece SportBoard

- **Sincronización con Strava** (OAuth + gestión segura de tokens).
- **Dashboard de rendimiento** con métricas clave de entrenamiento.
- **Capa de inteligencia local** para detectar patrones y anomalías.
- **Detalle avanzado de actividades** (splits, laps, reflexión post-run).
- **Exportación de datos** para uso web/análisis externo.
- **Suite de tests** con fixtures y golden files.

---

## 👥 Público objetivo

SportBoard está pensado para:

- Runners que quieren una lectura más útil de su historial.
- Deportistas que buscan constancia y control de carga/fatiga.
- Usuarios de Strava que quieren una “segunda capa” de análisis.

---

## 🚀 Features principales

### 🔐 Autenticación y seguridad
- Login OAuth con Strava (`ASWebAuthenticationSession`).
- Almacenamiento de credenciales en Keychain.

### 🔄 Sincronización
- Sincronización incremental + histórica.
- Control de rate limits de Strava API.
- Flujo robusto de reintentos/estado de sync.

### 📊 Dashboard y métricas
- Distancia, tiempo, elevación y métricas cardiovasculares.
- Vista consolidada por periodos recientes.

### 🧠 Inteligencia deportiva local
- Clasificación de entrenos.
- Detección de “bad runs” y picos sospechosos.
- Consistencia semanal y comparativas.
- Señales de fatiga.
- Sugerencias de próximo entrenamiento.
- Narrativa semanal automática.

### 🧩 Detalle por actividad
- Splits y laps.
- Reflexión post actividad.
- Exportación JSON para integración web.

---

## 🧱 Stack técnico

- **Swift 5**
- **SwiftUI**
- **SwiftData**
- **Foundation / Combine**
- **AuthenticationServices**
- **Keychain**
- Proyecto Xcode: `.xcodeproj` (sin workspace)

---

## 🏛️ Arquitectura (resumen)

Enfoque: **MVVM + Services + SwiftData**

Flujo principal:

`Strava API → SyncService → Persistencia (SwiftData) → ViewModels → Views`

Estructura relevante del proyecto:

```text
SportBoardApp/
├── Models/
├── Services/
│   └── Intelligence/
├── ViewModels/
├── Views/
│   ├── Activities/
│   ├── ActivityDetail/
│   ├── Auth/
│   ├── Dashboard/
│   ├── Intelligence/
│   └── Sync/
└── Utilities/

SportBoardAppTests/
├── Fixtures/
├── GoldenFiles/
├── TestSupport/
└── (tests de inteligencia y utilidades)
```

---

## ⚙️ Instalación

### Requisitos

- macOS + Xcode actualizado.
- Simulador iOS.
- App de Strava registrada (OAuth).

### 1) Clonar repo

```bash
git clone https://github.com/DavidCerroS/SportBoard.git
cd SportBoard
```

### 2) Configurar credenciales

Usa `SportBoardApp/Utilities/Constants.example.swift` como base y crea/ajusta `Constants.swift` con:

- `clientId`
- `clientSecret`
- `redirectUri`

> No subas secretos reales al repositorio.

### 3) Abrir en Xcode

Abre:

`SportBoardApp.xcodeproj`

### 4) Ejecutar

Selecciona esquema `SportBoardApp` y ejecuta en simulador o dispositivo.

---

## ▶️ Uso rápido

1. Inicia sesión con Strava.
2. Lanza sincronización inicial.
3. Explora:
   - Dashboard (métricas globales)
   - Intelligence (insights y sugerencias)
   - Activities (detalle, splits/laps, export)

---

## 🧪 Testing

Ejemplo de ejecución:

```bash
xcodebuild test \
  -project SportBoardApp.xcodeproj \
  -scheme SportBoardApp \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

Consulta también: `TESTING.md`.

---

## 🛣️ Roadmap sugerido

- [ ] CI con GitHub Actions (build + tests).
- [ ] Capturas reales y sección visual del producto.
- [ ] Métricas por bloques/mesociclos.
- [ ] Exportes extra (CSV/PDF).
- [ ] Mejoras en internacionalización.
- [ ] Mejor documentación de arquitectura interna.

---

## 🤝 Contribución

PRs bienvenidas. Recomendado:

1. Crear rama (`feature/...`, `fix/...`).
2. Hacer commits pequeños y claros.
3. Abrir PR con contexto, alcance y validación.
4. Para cambios grandes: abrir issue antes.

---

## 📄 Licencia

No se detecta `LICENSE` en el repo actualmente.  
Recomendado añadir una licencia explícita (por ejemplo MIT) para clarificar uso y contribución.
