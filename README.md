# 🏃‍♂️ SportBoard

<p align="left">
  <img src="https://img.shields.io/badge/iOS-SwiftUI-blue?logo=swift" alt="iOS SwiftUI" />
  <img src="https://img.shields.io/badge/Language-Swift%205-orange?logo=swift" alt="Swift 5" />
  <img src="https://img.shields.io/badge/Architecture-MVVM%20%2B%20SwiftData-6f42c1" alt="MVVM + SwiftData" />
  <img src="https://img.shields.io/badge/Integration-Strava%20API-FC4C02?logo=strava" alt="Strava API" />
  <img src="https://img.shields.io/badge/Status-Active%20Development-brightgreen" alt="Active Development" />
</p>

SportBoard es una app iOS para **sincronizar, analizar y entender entrenamientos de Strava** (especialmente running), con foco en métricas accionables, constancia y prevención de fatiga.

---

## ✨ Valor principal

- Convierte datos de Strava en señales prácticas para decidir mejor tus entrenos.
- Añade una capa de análisis local para detectar patrones de rendimiento.
- Mantiene experiencia rápida y clara con arquitectura iOS moderna.

---

## 🚀 Funcionalidades

### 🔐 Autenticación y seguridad
- OAuth con Strava (`ASWebAuthenticationSession`)
- Gestión de credenciales en Keychain

### 🔄 Sincronización
- Sync incremental + histórico
- Gestión de límites de API
- Estado de sincronización robusto

### 📊 Analítica
- Dashboard con métricas de distancia, tiempo, elevación y HR
- Comparativas y lectura de tendencias

### 🧠 Inteligencia local
- Clasificación de entrenos
- Detección de anomalías y picos sospechosos
- Señales de fatiga y consistencia
- Sugerencias de próximo entrenamiento
- Narrativa semanal automática

### 🧩 Detalle por actividad
- Splits, laps y reflexión post actividad
- Exportación JSON para integraciones web

---

## 🧱 Stack técnico

- Swift 5
- SwiftUI
- SwiftData
- Foundation / Combine
- AuthenticationServices
- Keychain

Patrón principal: **MVVM + Services + SwiftData**

---

## 📁 Estructura

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
- macOS + Xcode
- Simulador iOS
- App de Strava registrada (OAuth)

### Setup
```bash
git clone https://github.com/DavidCerroS/SportBoard.git
cd SportBoard
```

1. Usa `SportBoardApp/Utilities/Constants.example.swift` como base
2. Crea/ajusta `Constants.swift` con `clientId`, `clientSecret`, `redirectUri`
3. Abre `SportBoardApp.xcodeproj`
4. Ejecuta esquema `SportBoardApp`

> No subas secretos reales al repositorio.

---

## 🧪 Testing

```bash
xcodebuild test \
  -project SportBoardApp.xcodeproj \
  -scheme SportBoardApp \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

Más contexto en `TESTING.md`.

---

## 🤝 Contribución

Revisa `CONTRIBUTING.md` para flujo de ramas, criterios de calidad y etiquetas recomendadas.

---

## 📄 Licencia

Este proyecto está bajo licencia **MIT**. Revisa [`LICENSE`](./LICENSE).
