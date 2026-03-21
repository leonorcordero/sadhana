# AGENTS.md

## Objetivo
Garantizar persistencia de datos **local** entre actualizaciones de la app en el mismo dispositivo.

## Reglas Obligatorias de Persistencia

1. No romper `boxes` ni `keys` de Hive
- No renombrar `AppConstants.*Box` existentes.
- No renombrar keys de `settings` sin migración explícita.
- No eliminar keys históricas sin migración y compatibilidad.

2. Nunca borrar datos en arranque
- Prohibido hacer `clear()` global de almacenamiento al iniciar app.
- Cualquier limpieza debe ser puntual, versionada y reversible.

3. Migraciones versionadas
- Mantener y usar `schemaVersion` en `LocalStorageDatasource`.
- Toda modificación estructural de datos requiere paso de migración en `_runMigrations()`.
- Cada migración debe ser idempotente (si se ejecuta dos veces, no rompe datos).

4. Compatibilidad hacia atrás en modelos
- En `fromMap`, todo campo nuevo debe tener default seguro.
- Evitar asumir que un campo existe en datos viejos.
- No convertir campos obligatorios sin fallback.

5. Escrituras seguras
- Al actualizar entidades, preservar campos existentes no modificados.
- Evitar reemplazos masivos que puedan eliminar atributos viejos accidentalmente.

6. Export/Import de respaldo
- Mantener `exportAllAsJsonMap()` y `importAllFromJsonMap()` compatibles con versiones anteriores.
- Si cambia formato, agregar traducción en import para payloads viejos.

7. Pruebas mínimas obligatorias antes de cerrar cambios
- `flutter analyze` sin errores.
- `flutter test` pasando.
- Si hay migración: agregar/actualizar test que valide lectura de datos antiguos.

8. Regla de no regresión
- Ningún cambio de UI o feature puede comprometer persistencia existente.
- Si hay duda, priorizar compatibilidad de datos sobre refactor visual.

9. No pérdida de datos al actualizar en teléfono
- Al actualizar la app en el teléfono del usuario, no se debe eliminar ningún recurso ni configuración cargada por el usuario.
- Se debe conservar toda la información del usuario entre versiones.

## Checklist para cada cambio con datos
- ¿Cambió modelo o key? -> agregar migración.
- ¿`fromMap` soporta datos viejos? -> verificar defaults.
- ¿Se ejecutó analyze + tests? -> obligatorio.
- ¿Se mantiene lectura de backups viejos? -> verificar.

## Alcance
Estas reglas aplican a:
- `lib/data/datasources/local_storage_datasource.dart`
- `lib/data/repositories/sadhana_repository.dart`
- `lib/data/models/*`
- cualquier feature que persista datos en Hive/settings.
