# Carpinteria El Alamo - App de Produccion

Aplicacion movil desarrollada en Flutter para gestion de produccion en taller de carpinteria.

## Resumen

La app centraliza el flujo operativo del taller:

- Catalogo de muebles (con medidas e imagen).
- Definicion de partes y materiales por mueble.
- Seguimiento en proceso con checklist real de fabricacion.
- Produccion del dia con agrupacion de materiales y calculo de hojas.
- Visualizacion de cortes para optimizar aprovechamiento de tablero.
- Historial semanal e inventario de hojas.
- Herramientas extra: calculadora, calculadora de cortes, backup/restore y PDF.

## Funcionalidades Principales

- CRUD completo de muebles.
- Duplicado de muebles para variantes de produccion.
- Estados `En proceso` con cantidad en proceso por modelo.
- Agrupacion de materiales por tipo/material/espesor/medidas.
- Seccion dedicada para `Puertas y/o Cajones`.
- Simulacion de cortes en hoja base `244 x 122 cm`.
- Exportacion de produccion a PDF.
- Copia de seguridad y restauracion local.
- Persistencia local con `SharedPreferences`.

## Stack Tecnologico

- Flutter (Dart)
- `shared_preferences`
- `image_picker`
- `file_picker`
- `path_provider`
- `share_plus`
- `pdf`
- `printing`

## Estructura del Proyecto

```text
lib/
  main.dart
  models/
    mueble.dart
    parte_mueble.dart
    material_mueble.dart
  services/
    storage_service.dart
  screens/
    home_screen.dart
    mueble_screen.dart
    en_proceso_screen.dart
    produccion_screen.dart
    historial_screen.dart
    cortes_puertas_screen.dart
    calculadora_screen.dart
    calculadora_cortes_screen.dart
    calculadora_puertas_cajones_screen.dart
```

## Requisitos

- Flutter SDK 3.x
- Dart SDK (incluido con Flutter)
- Android Studio / VS Code
- Dispositivo Android o emulador

## Ejecucion Local

```bash
flutter pub get
flutter run
```

## Analisis Estatico

```bash
flutter analyze
```

## Build Android (Release)

```bash
flutter build apk --release
```

## Roadmap Comercial

- Multiusuario y sincronizacion en nube.
- Panel de configuracion por taller (materiales, formulas, branding).
- Reportes avanzados de consumo y costos.
- Publicacion en Play Store con modalidad freemium/pro.

## Autor

**Manuel E Carrillo**

- GitHub: [@ManuelECarrillo](https://github.com/ManuelECarrillo)

## Nota

Este repositorio representa una version funcional orientada a uso real en taller.
Las reglas de produccion y calculos pueden adaptarse por configuracion segun el proceso de cada negocio.
