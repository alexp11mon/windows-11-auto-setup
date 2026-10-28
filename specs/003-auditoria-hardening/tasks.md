# Tasks 003 - Correcciones de la auditoría

Spec: `specs/003-auditoria-hardening/spec.md`. Plan: `specs/003-auditoria-hardening/plan.md`. Todas empiezan por su test (P6). Numeración continúa tras T18.

Línea base antes de empezar (2026-10-28): Runner 158/159 y Pester 54/59. Todos los fallos venían de que `winget` no está en el PATH de la sesión de pruebas (entorno, no código).

## Tareas

- [x] T19 Corregir la auto-elevación de `bootstrap`
  Hecho cuando: test AST (T28) en verde y `bootstrap` no usa `-Redirect*` con `-Verb RunAs`; el exit del hijo se propaga. Cubre: RF-28 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, `Start-Process -Verb RunAs -Wait -PassThru` con `-EncodedCommand`; un hijo falso real sale con 7 y el padre lee 7 (Runner + Pester). Si falla, se muestran las últimas 20 líneas del log persistente.
- [x] T20 Propagar la selección Custom al proceso elevado
  Hecho cuando: test mockeado verifica que `elevArgs` contiene `-Apps` con los IDs y que el hijo filtra `apps.json` solo con ellos. Cubre: RF-29 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, `$customApps` pasa a ser el parámetro `-Apps`, propagado en `$elevParams`; el hijo falso recibe `Valve.Steam,Discord.Discord`. `-Apps a,b` vía `pwsh -File` se separa por comas (`-WhatIf` real). Si ningún ID existe, se avisa y se conserva la lista completa (caso límite).
- [x] T21 Quitar el fichero temporal `bootstrap-iex.ps1`
  Hecho cuando: test verifica que bajo iex no se llama a `Set-Content` en `%TEMP%` y que el relanzamiento usa `scriptblock::Create` con la URL raw. Cubre: RF-30 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, sin `bootstrap-iex.ps1` ni `MyCommand.ScriptBlock`; el comando bajo iex descarga con `Invoke-RestMethod -ErrorAction Stop` (fallo → exit 1) y ejecuta en memoria. URL raw comprobada con HTTP 200.
- [x] T22 Conservar los logs del modo en línea
  Hecho cuando: test verifica que tras la limpieza existe el log en `%LOCALAPPDATA%\win11-setup\logs` (ruta redirigida en test) y que se imprime su ruta, también con salida 1. Cubre: RF-31 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, `Save-RunLogs` (extraída por AST) copia el log y este sobrevive al borrado del origen; sin logs no falla ni crea destino; se llama antes de la limpieza final, sea cual sea el exit code.
- [x] T23 Añadir `-Sha256` a `bootstrap`
  Hecho cuando: tests de hash correcto (continúa), distinto (ERROR, salida 1, sin extraer) y mayúsculas/minúsculas. Cubre: RF-32 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, `ValidatePattern` acepta 64 hex en mayúsculas o minúsculas y rechaza 63 (real con `Get-Command`); `Get-FileHash` antes de `Expand-Archive`; si no coincide, ERROR, borra el temporal y sale con 1. La ruta de descarga con hash distinto solo se comprueba de forma estática (sin red en tests). La URL pasa a `archive/$Branch.zip` para aceptar tags (HTTP 200 comprobado).
- [x] T24 Retirar `gk-hooks.js` del snapshot
  Hecho cuando: el fichero no está en `config/opencode/`, `Runner-Mock.ps1` espera 11 ficheros y el grep de rutas `C:/Users` da 0. Cubre: RF-33 | Módulo: config/opencode
  Verificado: 2026-10-28, `git rm`; Runner: 11 ficheros, sin `gk-hooks.js`, regex de rutas `X:\Users` sin resultados.
- [x] T25 Barrido de secretos por asignación
  Hecho cuando: tests: `token: abc12345` se omite; "uses a token to log in" se aplica; nombre de fichero con `secret` se omite; suite en verde. Cubre: RF-34 | Módulo: Config-OpenCode
  Verificado: 2026-10-28, más el caso JSON `"apiKey": "sk-123456"` (se omite). El caso previo `api_key = 12345` sigue omitiéndose.
- [x] T26 Test de no regresión para jsonc con comentarios
  Hecho cuando: test pasa con `opencode.jsonc` que contiene `//` y `/* */`; sin cambios de código. Cubre: RF-35 | Módulo: Config-OpenCode (test)
  Verificado: 2026-10-28, Runner + Pester; sin cambio en el módulo.
- [x] T27 Degradar a WARNING cuando winget falla pero la app está instalada
  Hecho cuando: tests: exit != 0 y app presente → WARNING sin `InstallHadErrors`; exit != 0 y ausente → ERROR. Cubre: RF-36 | Módulo: Common
  Verificado: 2026-10-28, Runner + Pester con el código `-1978335189`. Además, `Common.Tests.ps1` crea un stub de `winget` si no está en el PATH, lo que arregla los 5 fallos de entorno de la línea base.
- [x] T28 Test AST de forma de `Start-Process` y persistencia de logs
  Hecho cuando: el test falla si cualquier `Start-Process` del repo combina `-Verb` con `-Redirect*` (comprobado contra el código previo a T19) y cubre el caso de log tras limpieza. Cubre: RF-37 | Módulo: tests/
  Verificado: 2026-10-28, el mismo AST sobre `git show HEAD:bootstrap.ps1` marca la línea 214 y sobre el código nuevo no marca nada. También comprueba con `Get-Command Start-Process` que `-Verb` y `-RedirectStandardOutput` están en sets distintos.
- [x] T29 Módulo ausente es ERROR en `install.ps1`
  Hecho cuando: test con módulo renombrado → salida 1 y línea ERROR en log. Cubre: RF-38 | Módulo: install.ps1
  Verificado: 2026-10-28, test estático: las 4 líneas "configuration module not found" usan `-Level "ERROR"`. Desviación: no se ejecuta `install.ps1` con un módulo renombrado porque el entry aborta sin Admin antes; ERROR → `InstallHadErrors` → exit 1 ya lo cubre el Bloque 2.
- [x] T30 Comprobar cada `git config`
  Hecho cuando: test con mock que falla solo `init.defaultBranch` → ERROR que nombra ese ajuste. Cubre: RF-39 | Módulo: Config-Git
  Verificado: 2026-10-28, bucle sobre los 4 ajustes; el fallo en `init.defaultBranch` registra ERROR con su nombre y no aplica `alias.tree` (3 llamadas a git).
- [x] T31 Una sola lectura de políticas en Brave
  Hecho cuando: test cuenta una sola llamada a `Get-ItemProperty` por ejecución y los slots no colisionan con 5 extensiones. Cubre: RF-40 | Módulo: Config-Brave
  Verificado: 2026-10-28, con el slot `2` ya ocupado: 1 lectura y 6 slots únicos (Runner + Pester).
- [x] T32 `Update-SessionPath` con `HashSet`
  Hecho cuando: test con PATH duplicado/mayúsculas devuelve entradas únicas en el mismo orden. Cubre: RF-41 | Módulo: install.ps1
  Verificado: 2026-10-28, `HashSet[string]` con `OrdinalIgnoreCase` + `List[string]`; `C:\RF41First;c:\rf41first;C:\RF41Second` → 2 entradas en orden.
- [x] T33 Aviso de política forzada de Brave
  Hecho cuando: el título del menú en línea y el README mencionan que las extensiones se fuerzan por política; test del menú lo verifica. Cubre: RF-42 | Módulo: bootstrap.ps1, docs
  Verificado: 2026-10-28, confirmación del menú, log de `Config-Brave` y README (con cómo quitarlas) mencionan la política de equipo.
- [x] T34 Actualizar docs
  Hecho cuando: README (uso de `-Sha256`, tags, ruta de logs, política Brave), AGENTS.md y `docs/estructura-proyecto.md` actualizados en español y el recuento de tests correcto. Cubre: RF-32, RF-42 | Módulo: docs
  Verificado: 2026-10-28, diff revisado; recuentos 208 checks / 74 tests.
- [x] T35 Validar RF-28 a RF-42 y demo real
  Hecho cuando: Runner + Pester en verde, `-WhatIf` de `install` y `bootstrap` con salida 0, log sin ERROR imprevisto, y demo manual de elevación desde terminal normal con el one-liner. Cubre: todos | Módulo: validación
  Verificado: 2026-10-28, Runner 204/205 (el único fallo es "winget disponible en esta sesion", de entorno y previo) + Pester 72/72; `bootstrap -WhatIf` sale con 0 (también con `-Apps`/`-Sha256`/nombre con espacio); `-Sha256 abc` rechazado. Pendiente del usuario, en sesión real: `install -WhatIf` como admin (aquí aborta sin admin, como está diseñado) y demo del one-liner desde una terminal sin elevar (UAC no se puede automatizar). Hasta entonces, el one-liner de `master` solo usará este código cuando se haga push.

## Hallazgo adicional durante la implementación

- `Start-Process -ArgumentList` no entrecomilla los valores: `-GitUserName "Ana Lopez"` llegaba como `GitUserName=Ana` y `GitUserEmail=Lopez` (reproducido). Afectaba a la elevación y a la llamada a `install.ps1`. Se corrige dentro de T19/T20: la elevación usa `-EncodedCommand` con literales entrecomillados, e `install.ps1` se invoca con `& pwsh @installArgs`. Cubierto por el test de ida y vuelta con `"Ana O'Brien"`.
- En `-WhatIf` no se escribía ningún log: `Add-Content` (y el `New-Item` de `logs/`) en `Write-InstallLog` también obedecen `$WhatIfPreference`, así que cada mensaje imprimía "What if: Agregar contenido..." y `logs/` quedaba vacío. Contradecía el plan 001 ("si `-WhatIf` solo loguea simulación"), y la comprobación "log sin ERROR" de T18 no tenía log que revisar. Detectado en la demo de T35 y corregido con `-WhatIf:$false` en ambas llamadas (el log no es un cambio en el sistema, P5). Test en Runner (Bloque 2) y Pester (`Common.Tests.ps1`): falla antes del arreglo y pasa después. Suites: Runner 206/206 y Pester 73/73 con el PATH de usuario corregido.

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

- Sin bloqueantes. Aprobado el 2026-10-28 (spec, plan y tasks). Resueltas: tags `vMAJOR.MINOR.PATCH` con SHA256 en las notas de release (T23, T34) y script elevado bajo `iex` descargado de la URL raw (T21).
- Pendiente fuera de esta spec: crear el tag `v1.0.0` y publicar su SHA256 tras la demo real de T35.
- El one-liner (`irm ... | iex`) fallaba al arrancar con "No se puede agregar el atributo porque la variable Sha256 con valor ya no sería válida": bajo `iex` el bloque `param()` se evalúa como código y `ValidatePattern` se aplica al valor vacío por defecto. Lo detectó el usuario tras el push de T35. Corregido con el patrón `^([0-9a-fA-F]{64})?$`. Nuevo test en Runner y Pester que ejecuta `bootstrap.ps1` de verdad vía `Invoke-Expression` (sin consola, cancela con 0): falla antes del arreglo y pasa después. Suites: Runner 208/208 y Pester 74/74.
