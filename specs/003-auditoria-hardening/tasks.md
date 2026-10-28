# Tasks 003 - Correcciones de la auditoría

Spec: `specs/003-auditoria-hardening/spec.md`. Plan: `specs/003-auditoria-hardening/plan.md`. Todas empiezan por su test (P6). Numeración continúa tras T18.

## Tareas

- [ ] T19 Corregir la auto-elevación de `bootstrap`
  Hecho cuando: test AST (T28) en verde y `bootstrap` no usa `-Redirect*` con `-Verb RunAs`; el exit del hijo se propaga. Cubre: RF-28 | Módulo: bootstrap.ps1
- [ ] T20 Propagar la selección Custom al proceso elevado
  Hecho cuando: test mockeado verifica que `elevArgs` contiene `-Apps` con los IDs y que el hijo filtra `apps.json` solo con ellos. Cubre: RF-29 | Módulo: bootstrap.ps1
- [ ] T21 Quitar el fichero temporal `bootstrap-iex.ps1`
  Hecho cuando: test verifica que bajo iex no se llama a `Set-Content` en `%TEMP%` y que el relanzamiento usa `scriptblock::Create` con la URL raw. Cubre: RF-30 | Módulo: bootstrap.ps1
- [ ] T22 Conservar los logs del modo en línea
  Hecho cuando: test verifica que tras la limpieza existe el log en `%LOCALAPPDATA%\win11-setup\logs` (ruta redirigida en test) y que se imprime su ruta, también con salida 1. Cubre: RF-31 | Módulo: bootstrap.ps1
- [ ] T23 Añadir `-Sha256` a `bootstrap`
  Hecho cuando: tests de hash correcto (continúa), distinto (ERROR, salida 1, sin extraer) y mayúsculas/minúsculas. Cubre: RF-32 | Módulo: bootstrap.ps1
- [ ] T24 Retirar `gk-hooks.js` del snapshot
  Hecho cuando: el fichero no está en `config/opencode/`, `Runner-Mock.ps1` espera 11 ficheros y el grep de rutas `C:/Users` da 0. Cubre: RF-33 | Módulo: config/opencode
- [ ] T25 Barrido de secretos por asignación
  Hecho cuando: tests: `token: abc12345` se omite; "uses a token to log in" se aplica; nombre de fichero con `secret` se omite; suite en verde. Cubre: RF-34 | Módulo: Config-OpenCode
- [ ] T26 Test de no regresión para jsonc con comentarios
  Hecho cuando: test pasa con `opencode.jsonc` que contiene `//` y `/* */`; sin cambios de código. Cubre: RF-35 | Módulo: Config-OpenCode (test)
- [ ] T27 Degradar a WARNING cuando winget falla pero la app está instalada
  Hecho cuando: tests: exit != 0 y app presente → WARNING sin `InstallHadErrors`; exit != 0 y ausente → ERROR. Cubre: RF-36 | Módulo: Common
- [ ] T28 Test AST de forma de `Start-Process` y persistencia de logs
  Hecho cuando: el test falla si cualquier `Start-Process` del repo combina `-Verb` con `-Redirect*` (comprobado contra el código previo a T19) y cubre el caso de log tras limpieza. Cubre: RF-37 | Módulo: tests/
- [ ] T29 Módulo ausente es ERROR en `install.ps1`
  Hecho cuando: test con módulo renombrado → salida 1 y línea ERROR en log. Cubre: RF-38 | Módulo: install.ps1
- [ ] T30 Comprobar cada `git config`
  Hecho cuando: test con mock que falla solo `init.defaultBranch` → ERROR que nombra ese ajuste. Cubre: RF-39 | Módulo: Config-Git
- [ ] T31 Una sola lectura de políticas en Brave
  Hecho cuando: test cuenta una sola llamada a `Get-ItemProperty` por ejecución y los slots no colisionan con 5 extensiones. Cubre: RF-40 | Módulo: Config-Brave
- [ ] T32 `Update-SessionPath` con `HashSet`
  Hecho cuando: test con PATH duplicado/mayúsculas devuelve entradas únicas en el mismo orden. Cubre: RF-41 | Módulo: install.ps1
- [ ] T33 Aviso de política forzada de Brave
  Hecho cuando: el título del menú en línea y el README mencionan que las extensiones se fuerzan por política; test del menú lo verifica. Cubre: RF-42 | Módulo: bootstrap.ps1, docs
- [ ] T34 Actualizar docs
  Hecho cuando: README (uso de `-Sha256`, tags, ruta de logs, política Brave), AGENTS.md y `docs/estructura-proyecto.md` actualizados en español y el recuento de tests correcto. Cubre: RF-32, RF-42 | Módulo: docs
- [ ] T35 Validar RF-28 a RF-42 y demo real
  Hecho cuando: Runner + Pester en verde, `-WhatIf` de `install` y `bootstrap` con salida 0, log sin ERROR imprevisto, y demo manual de elevación desde terminal normal con el one-liner. Cubre: todos | Módulo: validación

## Trazabilidad RF -> Tareas

- RF-28 -> T19, T28
- RF-29 -> T20
- RF-30 -> T21
- RF-31 -> T22, T28
- RF-32 -> T23, T34
- RF-33 -> T24
- RF-34 -> T25
- RF-35 -> T26
- RF-36 -> T27
- RF-37 -> T28
- RF-38 -> T29
- RF-39 -> T30
- RF-40 -> T31
- RF-41 -> T32
- RF-42 -> T33, T34

## Orden sugerido

T28 → T19 → T20 → T21 → T22 → T23 → T24 → T25 → T26 → T27 → T29 → T30 → T31 → T32 → T33 → T34 → T35.

## Dudas abiertas

- Las de la spec: esquema de tags de release (T23, T34) y origen del script elevado bajo `iex` (T21).
