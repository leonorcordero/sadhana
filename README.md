# Sadhana

Aplicacion movil multiplataforma en Flutter para seguimiento de ciclos espirituales (sadhana), tareas diarias, rachas y calendario ritual.

## Stack tecnico

- Flutter + Dart
- Riverpod (state management)
- Hive (almacenamiento local)
- flutter_local_notifications
- workmanager (Android)
- background_fetch (iOS)
- table_calendar

## Estructura

```text
lib/
  core/
  data/
    datasources/
    models/
    repositories/
  features/
    app_shell/
    calendar/
    cycles/
    dashboard/
    notifications/
    streaks/
    tasks/
```

## Reglas implementadas

- No se puede eliminar tarea si el ciclo esta activo.
- No se puede editar el sankalpa cuando el ciclo ya esta activo.
- Cierre diario automatico a las 23:59 (timer en primer plano + background worker).
- Racha actual y maxima calculadas al cierre del dia.

## Funcionalidades

- CRUD de ciclos
- CRUD de tareas por ciclo
- Marcar tareas por fecha
- Dashboard con progreso, sankalpa y rachas
- Calendario mensual con estados (verde/rojo), fase lunar y dias especiales
- Notificaciones: 3 recordatorios diarios + notificacion al completar el dia

## Comandos

### Instalar dependencias

```bash
flutter pub get
```

### Ejecutar app

```bash
flutter run
```

### Analisis estatico

```bash
flutter analyze
```

### Tests

```bash
flutter test
```

### Cobertura

```bash
flutter test --coverage
```

### Build Android

```bash
flutter build apk --release
```

### Build iOS

```bash
flutter build ios --release
```

## Notas de plataforma

- Android: `workmanager` ejecuta tarea periodica para cierre diario cuando la app no esta en foreground.
- iOS: `background_fetch` se inicializa para callbacks periodicos del sistema.


## Git Workflow Basico

```bash
git checkout master
git pull
git checkout -b feat/nombre-tarea
git add .
git commit -m "feat: descripcion"
git push -u origin feat/nombre-tarea