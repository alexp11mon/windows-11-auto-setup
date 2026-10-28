# Plan 004 - Menú: selección de apps por categoría

Spec de origen: `specs/004-menu-seleccion-apps/spec.md`. Constitución: `docs/constitution.md`. Planes 001 a 003 siguen vigentes.

## Resumen de arquitectura

Solo cambia `bootstrap.ps1`: menú multi con Enter sobre la opción resaltada, lista de apps por categoría y una función pura que convierte la selección en flags `-Skip*`. `install.ps1` y los módulos no cambian.

Flujo del menú: categoría → lista de apps marcadas → (Git si `Git.Git`) → (VSCode si `Microsoft.VisualStudioCode`) → (OpenCode si alcance Dev) → confirmación → elevación o instalación.

## Módulos y responsabilidades

- `bootstrap.ps1`:
  - `Read-MenuKey`: envoltorio de `[Console]::ReadKey` para poder simular teclas en tests. Cubre: RF-43.
  - `Show-Menu -Multi -Preselected`: marca todo al entrar; Enter sin marcas devuelve la opción resaltada. Cubre: RF-43, RF-44.
  - `Get-ConfigScope -Category -Apps -AppsData`: devuelve qué bloques aplican (`Git`, `VSCode`, `OpenCode`, `Brave`). Lo usan tanto el menú (para preguntar) como la ruta con `-Apps` (para fijar los `-Skip*`). Cubre: RF-47, RF-48.
  - Menú sin "Custom per-app"; lista de la categoría tras elegirla. Cubre: RF-44, RF-45, RF-46.
- `tests/`: checks con teclas simuladas y casos de `Get-ConfigScope`. Cubre: todos.
- `README.md`, `AGENTS.md`, `docs/estructura-proyecto.md`: flujo y teclas. Cubre: RF-49.

## Modelo de datos

- Selección: `string[]` de IDs winget (subconjunto de `apps.json`).
- `Get-ConfigScope` → `@{ Git; VSCode; OpenCode; Brave }` (bool). Reglas:
  - Sin selección: Git, VSCode y OpenCode = Category en Dev/All; Brave = Category en Base/All (igual que `install.ps1`).
  - Con selección: Git = contiene `Git.Git`; VSCode = contiene `Microsoft.VisualStudioCode`; Brave = contiene `Brave.Brave`; OpenCode = intersección con `AppsData.Dev` no vacía.

## Contratos e interfaces

- CLI sin cambios. Con `-Apps`, `bootstrap` añade `-SkipGit`, `-SkipVSCode`, `-SkipOpenCode` y `-SkipBrave` a `install.ps1` según `Get-ConfigScope`, leyendo el `apps.json` extraído.
- En el menú, si la selección es la categoría completa, no se pasa `-Apps`.

## Flujo principal paso a paso

1. Elegir categoría (All, Base, Dev, Gaming). Esc cancela con 0.
2. Descargar `apps.json` (ya se hace hoy para el modo personalizado) y mostrar las apps de la categoría, todas marcadas (RF-44). Enter confirma (RF-43). Vacío cancela con 0 (RF-46).
3. `Get-ConfigScope`; preguntar solo por los bloques que aplican (RF-47, RF-48); el resto se marca `-Skip*`.
4. Confirmación con el resumen; ejecución igual que hoy.

## Decisiones técnicas

- D27: Enter sin marcas devuelve la opción resaltada. Descartado mostrar un error y quedarse en el menú, porque el usuario espera que Enter elija. Cubre: RF-43.
- D28: Lista de la categoría con todo marcado. Descartado empezar sin marcar, porque instalar la categoría completa es el caso habitual (solo hay que pulsar Enter). Cubre: RF-44.
- D29: Retirar "Custom per-app" (aprobado el 2026-10-28). Cubre: RF-45.
- D30: Traducir la selección a flags `-Skip*` en `bootstrap` en vez de cambiar el gating de `install.ps1`. Motivo: `install.ps1` sigue siendo la referencia local y no cambia de contrato. Cubre: RF-47, RF-48.
- D31: `Read-MenuKey` como envoltorio, para testear `Show-Menu` sin consola. Cubre: RF-43.

## Trazabilidad RF -> módulo

- RF-43 -> `bootstrap.ps1` (`Show-Menu`, `Read-MenuKey`)
- RF-44 -> `bootstrap.ps1` (menú)
- RF-45 -> `bootstrap.ps1` (menú)
- RF-46 -> `bootstrap.ps1` (menú)
- RF-47 -> `bootstrap.ps1` (`Get-ConfigScope`)
- RF-48 -> `bootstrap.ps1` (`Get-ConfigScope`)
- RF-49 -> `bootstrap.ps1`, docs

## Riesgos y mitigaciones

- R13: Con `-Apps` sin Git ni VSCode, ya no se configuran aunque estén instalados de antes → mitigación: es lo que pide RF-47; se documenta en el README.
- R14: El menú con flechas solo se prueba de verdad en una consola real → mitigación: `Read-MenuKey` simulado en tests + demo manual.

## Dudas abiertas

- Sin bloqueantes. Plan aprobado el 2026-10-28 con las dos propuestas de la spec (retirar "Custom per-app"; OpenCode solo con alcance Dev).
