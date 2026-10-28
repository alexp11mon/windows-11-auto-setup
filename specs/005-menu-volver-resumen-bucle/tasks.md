# Tasks 005 - Menú: volver atrás, resumen y seguir instalando

Spec: `specs/005-menu-volver-resumen-bucle/spec.md`. Plan: `specs/005-menu-volver-resumen-bucle/plan.md`. Todas empiezan por su test (P6). Numeración continúa tras T42.

## Tareas

- [x] T43 Back y memoria en los menús
  Hecho cuando: tests con teclas simuladas: Esc devuelve `$MenuBack`; desmarcar todo + Enter devuelve `$null`; `-Checked 'B'` entra con solo B marcada; `-Start 2` entra con la tercera resaltada; en el numerado "0" devuelve `$MenuBack` y vacío `$null`. Los tests de spec 004 con `-Preselected` pasan a `-Checked`. Cubre: RF-50, RF-51, RNF-2 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, Runner (teclas simuladas y menú numerado con `Read-Host` simulado) + Pester. `$MenuBack = '<back>'`.
- [x] T44 `Format-InstallSummary`
  Hecho cuando: tests: Gaming completo lista las 4 apps bajo "Gaming" y "Git: skipped"; selección Base+Dev agrupa cada app en su categoría; Git con nombre y email los muestra; Brave marcado muestra "machine policy". Cubre: RF-53 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, Runner + Pester.
- [x] T45 `Invoke-InteractiveSetup`
  Hecho cuando: tests con menús simulados: Gaming → resumen → Back vuelve a la lista de apps con la selección previa; Dev → Git → Back vuelve a la lista; Back en categoría o "Exit" devuelve `$null`; cambiar de categoría reinicia la lista; Cancel en el resumen devuelve `$null`; Install devuelve las opciones con los `Skip*` de `Get-ConfigScope`; ya no aparece "Simulate first". Cubre: RF-50, RF-51, RF-52, RF-54 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, `Invoke-InteractiveSetup` con `Invoke-Menu` simulado (Runner + Pester), incluido Back desde OpenCode a Git en Dev. Git recuerda nombre y email: Enter sin texto conserva el valor anterior.
- [x] T46 `Invoke-InstallRound`
  Hecho cuando: tests con `Start-Process` simulado: sin admin usa `-Verb RunAs`, con admin no; el comando codificado lleva las opciones (incluido un nombre con espacios); devuelve el código del hijo; si `Start-Process` lanza (UAC rechazado) devuelve 1. Cubre: RF-55 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, `Start-Process` simulado (Runner + Pester). Con admin usa `-NoNewWindow` (mismo terminal). La ruta no interactiva sin admin reutiliza `Invoke-InstallRound`.
- [x] T47 Bucle de instalación
  Hecho cuando: test del flujo vía `iex` en proceso hijo (menú numerado, `Read-Host`, `Invoke-RestMethod` y `Start-Process` simulados): dos vueltas (Base y luego Gaming) lanzan dos instalaciones y salen con 0; una vuelta con código 1 y luego Exit sale con 1; Exit en el primer menú sale con 0 sin lanzar nada. Cubre: RF-55, RF-56, RF-57, RNF-4 | Módulo: bootstrap.ps1
  Verificado: 2026-10-28, flujo vía `iex` en proceso hijo: bucle Base → Gaming (2 instalaciones, 0), vuelta fallida (1), Exit (0, nada), Back numerado, Git con espacios, Cancel. El arnés usa `pwsh -OutputFormat Text`: sin él, `Write-Host` del hijo sale duplicado y los recuentos fallan.
- [x] T48 Docs
  Hecho cuando: README, AGENTS.md y `docs/estructura-proyecto.md` describen Back/Esc, el resumen, el bucle y los recuentos de tests; spec 005 en la lista de AGENTS. Cubre: RF-50 a RF-57 | Módulo: docs
  Verificado: 2026-10-28, recuentos 271 checks / 85 tests.
- [x] T49 Validar
  Hecho cuando: Runner y Pester en verde, `bootstrap -WhatIf` (con y sin `-Apps`) sale con 0, ruta `iex` sin errores y demo manual del menú por el usuario. Cubre: todos | Módulo: validación
  Verificado: 2026-10-28, Runner 271/271 + Pester 85/85; `bootstrap -WhatIf` con y sin `-Apps` sale con 0; ruta `iex` sin errores (cancela con 0). Pendiente: demo manual del menú con flechas por el usuario (requiere push a `master`).

## Trazabilidad RF -> Tareas

- RF-50 -> T43, T45
- RF-51 -> T43, T45
- RF-52 -> T45
- RF-53 -> T44
- RF-54 -> T45
- RF-55 -> T46, T47
- RF-56 -> T47
- RF-57 -> T47

## Orden sugerido

T43 → T44 → T45 → T46 → T47 → T48 → T49.

## Dudas abiertas

- Sin bloqueantes.
