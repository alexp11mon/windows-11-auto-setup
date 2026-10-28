# Tasks 004 - Menú: selección de apps por categoría

Spec: `specs/004-menu-seleccion-apps/spec.md`. Plan: `specs/004-menu-seleccion-apps/plan.md`. Todas empiezan por su test (P6). Numeración continúa tras T35.

## Tareas

- [x] T36 Enter sin marcas selecciona la opción resaltada
  Hecho cuando: test con `Read-MenuKey` simulado (abajo, Enter) devuelve la segunda opción en modo múltiple; con Espacio y Enter devuelve solo las marcadas; Esc devuelve `$null`. Cubre: RF-43 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, Runner + Pester con teclas simuladas (`Read-MenuKey` envuelve `[Console]::ReadKey`). Ya no usa `$Options.IndexOf`, así que las opciones duplicadas no rompen nada.
- [x] T37 `Get-ConfigScope`
  Hecho cuando: tests: sin selección replica el gating de `install.ps1` para las 4 categorías; solo Steam → todo `false`; `Git.Git` → Git y OpenCode; `Microsoft.VisualStudioCode` → VSCode y OpenCode; `Brave.Brave` → solo Brave. Cubre: RF-47, RF-48 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, 9 casos en Runner (incluido `Warp.Warp` → solo OpenCode) + Pester.
- [x] T38 Lista de apps por categoría y retirada de "Custom per-app"
  Hecho cuando: test con teclas simuladas: Gaming → lista de 4 apps marcadas; desmarcar una deja 3 en `-Apps`; Enter sin cambios no pasa `-Apps`; desmarcar todo cancela con 0; el menú de alcance ya no ofrece "Custom per-app". Cubre: RF-44, RF-45, RF-46 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, flujo real de `bootstrap.ps1` vía `Invoke-Expression` en un proceso hijo (menú numerado, `Read-Host` y `apps.json` simulados): Gaming 3 de 4 → `Apps=3`; Dev completo → `Apps=all`; vacío → "Cancelled". Las teclas en la lista preseleccionada (Enter confirma todas, desmarcar todo cancela) se prueban con `Show-Menu`. El mismo flujo contra el `bootstrap.ps1` anterior muestra "Custom per-app" y las tres preguntas (el test detecta el bug).
- [x] T39 Preguntas solo para lo que aplica
  Hecho cuando: test: con Gaming no se llama a `Read-Host` ni al menú de Git, VSCode u OpenCode, y se pasan los 4 `-Skip*` que correspondan; con Dev completo se pregunta por los tres. Cubre: RF-47, RF-48 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, flujos Gaming (ninguna pregunta, todo `skipped`), Dev completo (tres preguntas), Dev solo Git (Git y OpenCode, no VSCode), Base sin Brave (`Brave=skipped`) y Base con Brave (`Brave=forced extensions`).
- [x] T40 `-Apps` sin menú aplica las mismas reglas
  Hecho cuando: test: `-Apps Valve.Steam` produce `-SkipGit -SkipVSCode -SkipOpenCode -SkipBrave` hacia `install.ps1` (comprobado en `-WhatIf`). Cubre: RF-47, RF-48 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, con una desviación: `-WhatIf` sale antes de descargar (P5), así que no conoce la lista Dev del ZIP y no puede mostrar los `-Skip*`. Se cubre con `Get-ConfigScope` (T37) y un check estático de que la ruta `-Apps` lo llama con el `apps.json` extraído y aplica los `-Skip*` solo si queda algún ID válido y antes de construir `installArgs`.
- [x] T41 Ayuda de teclas y docs
  Hecho cuando: el menú muestra "Space toggles, Enter confirms"; README, AGENTS.md y `docs/estructura-proyecto.md` describen el nuevo flujo y los recuentos de tests. Cubre: RF-49 | Módulo: bootstrap.ps1, docs
  Verificado: 2026-10-28, ayuda "Use ↑/↓ to move, Space toggles, Enter confirms, Esc cancels" en listas múltiples. README con el flujo en 4 pasos y la regla de `-Apps`; recuentos 238 checks / 79 tests. También se corrigió en `estructura-proyecto.md` una frase anterior a la spec 003 ("bajo iex se auto-guarda en %TEMP%").
- [x] T42 Validar
  Hecho cuando: Runner y Pester en verde, `bootstrap -WhatIf` y la ruta `iex` sin errores, y demo manual del menú por el usuario. Cubre: todos | Módulo: validación
  Verificado: 2026-10-28, Runner 238/238 + Pester 79/79; `bootstrap -WhatIf` (con y sin `-Apps`) sale con 0; ruta `iex` sin errores. Pendiente: demo manual del menú con flechas por el usuario (requiere push a `master` y consola real).

## Trazabilidad RF -> Tareas

- RF-43 -> T36
- RF-44 -> T38
- RF-45 -> T38
- RF-46 -> T38
- RF-47 -> T37, T39, T40
- RF-48 -> T37, T39, T40
- RF-49 -> T41

## Orden sugerido

T36 → T37 → T38 → T39 → T40 → T41 → T42.

## Dudas abiertas

- Sin bloqueantes. Aprobado el 2026-10-28: se retira "Custom per-app" (RF-45) y OpenCode se pregunta solo con alcance Dev (RF-48).
