# Plan 002 - OpenCode + Brave V2

Spec de origen: `specs/002-opencode-brave-v2/spec.md`. Constitución: `docs/constitution.md`. Plan 001 (`specs/001-instalador-win11/plan.md`) sigue vigente para la v1; este plan solo añade la V2.

## Resumen de arquitectura

Dos módulos nuevos dot-sourced (`Config-OpenCode`, `Config-Brave`) + datos versionados en `config/` + orquestación en los entries existentes, con los mismos patrones de la v1 (idempotencia, `ShouldProcess`, log fechado, salida 0/1). Diagrama textual: `install → Config-OpenCode (instalar oficial + fusionar snapshot) → Config-Brave (asegurar Brave + aplicar extensiones) → log + exit`; `bootstrap` propaga flags y amplía el menú.

## Módulos y responsabilidades

- `install.ps1`: entry local. Añade flags `-SkipOpenCode` y `-SkipBrave`; invoca OpenCode solo en Dev/All y Brave solo en Base/All. No instala directo. Cubre: RF-17, RF-18, RF-19, RF-22, RF-23, RF-24, RF-26.
- `bootstrap.ps1`: entry en línea. Propaga `-SkipOpenCode`/`-SkipBrave` en auto-elevación y en la llamada a `install.ps1`; añade preguntas OpenCode (aplicar u omitir) y Brave (aplicar u omitir) al menú con la misma cancelación en 0. Cubre: RF-24, RF-26.
- `modules/Config-OpenCode.ps1`: `Invoke-OpenCodeConfig`; detecta presencia, instala con el instalador oficial si falta (1 reintento), fusiona el snapshot sin borrar nada del usuario, omite ficheros con secretos con aviso. No orquesta categorías. Cubre: RF-17, RF-18, RF-19, RF-20, RF-21, RF-25, RF-26.
- `modules/Config-Brave.ps1`: `Invoke-BraveConfig`; asegura Brave instalado, aplica las 5 extensiones de forma idempotente, avisa del reinicio. No toca otros navegadores. Cubre: RF-22, RF-23, RF-26.
- `config/opencode/`: datos versionados, no lógica. Copia de la configuración global (agentes, skills, plugins, ajustes) sin secretos. Cubre: RF-19, RF-21.
- `config/brave/extensions.json`: datos, no lógica. Lista de las 5 extensiones {id, nombre}. Cubre: RF-22.
- Docs (`README.md`, `docs/estructura-proyecto.md`, `docs/constitution.md`, `AGENTS.md`): enmienda de la excepción P2 y usos nuevos en español. Cubre: RF-27.

## Modelo de datos

- Snapshot OpenCode { agents[]: ficheros markdown, skills[]: carpetas con `SKILL.md`, plugins[]: ficheros js, settings: fichero `opencode.jsonc` }.
- Validación: fichero ausente en repo → `ERROR`; JSON de ajustes inválido → `ERROR` y se omite solo ese fichero.
- Fusión (RF-20): fichero ausente en destino → se copia; idéntico → se omite; distinto → se conserva el del usuario con `WARNING`, sin backup (no se modifica nada del usuario).
- Secreto (RF-21): patrón `token|password|secret|api[_-]?key` (insensible a mayúsculas) en nombre o contenido → se omite el fichero con `WARNING` y se continúa.
- Extensión Brave { id: 32 caracteres de Chrome Web Store, name: nombre visible para el log }.
- Validación: ID vacío o con formato inválido → aviso y continuar; lista vacía → `WARNING` y omitir bloque.
- Persistencia: ficheros locales UTF-8 en el repo; destino global de OpenCode del usuario; políticas de Brave para extensiones. Sin BD.

## Contratos e interfaces

- `.\install.ps1 [-Category Base|Dev|Gaming|All] [...flags v1...] [-SkipOpenCode] [-SkipBrave] [-WhatIf]` → salida 0 ok, 1 si cualquier `ERROR` (incluido fallo persistente del instalador oficial).
- `.\bootstrap.ps1 [mismos flags install + -SkipOpenCode -SkipBrave + -Repo -Branch -KeepDownload] [-WhatIf]` → en `-WhatIf` anuncia lo que haría con OpenCode/Brave; menú nuevo con omisiones y cancelación en 0.
- `Invoke-OpenCodeConfig -ConfigSourcePath [-DestinationRoot = "$HOME/.config/opencode"]`, `Invoke-BraveConfig -ExtensionsConfigPath [-PolicyRoot = HKLM ExtensionInstallForcelist]`, mismos niveles `INFO|WARNING|ERROR` de `Write-InstallLog`.
- Addendum ratificado en implementación (T14/T15): params opcionales con defaults reales para testear sin tocar HKLM ni HOME; instalador oficial descargado a `%TEMP%` con 2 intentos y ejecutado (D9/D13); tests de registro contra clave HKCU temporal con limpieza garantizada.
- Detección OpenCode: comando disponible y comprobación de versión con salida 0 → instalado; si no → no instalado (incluye el caso límite "presente pero versión falla").
- Errores: instalador oficial con salida != 0 tras reintento → `ERROR` y continúa; Brave ausente → se instala primero vía winget (categoría Base ya lo incluye) y después se aplican extensiones.

## Flujo principal paso a paso

1. Usuario `.\install.ps1 -Category All` (RF-17, RF-19, RF-22) → guards v1 sin cambios → categorías winget (Brave incluido en Base, cubre RF-23) → `Update-SessionPath`.
2. Si Dev/All → `Invoke-OpenCodeConfig`: detecta presencia (RF-18 omite install si existe) → si falta, instalador oficial con 1 reintento (RF-17, RF-25) → fusiona snapshot (RF-19, RF-20 conserva-con-aviso, RF-21 omite secretos) → en `-WhatIf` solo describe (RF-26).
3. Si Base/All → `Invoke-BraveConfig`: asegura Brave (RF-23) → aplica las 5 extensiones omitiendo las ya aplicadas (RF-22) → avisa del reinicio → en `-WhatIf` solo describe (RF-26).
4. Cierre v1 sin cambios: `InstallHadErrors` → `exit 1`, si no `exit 0`.
5. Online: `bootstrap` pregunta OpenCode (aplicar u omitir; RF-24, cancelación en 0) y deriva Brave del alcance sin preguntar (addendum ratificado en T16: Brave automático en Base/All) → propaga flags → `install.ps1` → propaga exit.
6. Docs (RF-27): README/estructura-proyecto/constitución/AGENTS actualizados en español, sin cambiar lógica.

## Decisiones técnicas

- D9: Instalador oficial publicado por OpenCode con 1 reintento y verificación por comprobación de versión. Descartado `SST.opencode` de winget por ser paquete comunitario no soportado oficialmente. Motivo: fidelidad al método soportado + excepción P2 aprobada en spec. Cubre: RF-17, RF-18, RF-25.
- D10: Snapshot versionado en el repo con fusión que conserva el fichero del usuario con aviso. Descartada sobrescritura con backup por riesgo de romper la config activa del usuario. Motivo: P3 re-ejecución segura + RF-20 resuelto. Cubre: RF-19, RF-20.
- D11: Extensiones Brave aplicadas por el sistema de forma programada y persistente a nivel de equipo. Descartada apertura de URLs de la tienda por no ser automática (exige 5 clics) y descartada copia de ficheros de perfil por cifrado específico de máquina. Motivo: único método 100% scriptable e idempotente. Cubre: RF-22.
- D12: Detección de OpenCode por comando disponible + comprobación de versión con salida 0. Descartado `winget list` por no ser app winget. Motivo: coherencia con `code`/`git` (WARNING y omitir si no están). Cubre: RF-18.
- D13: Reintento único ante fallo de descarga del instalador oficial, luego `ERROR` y continuar. Descartado fallo rápido por transient errors de red y descartado abortar todo por P3/RF-13 (continuar con el resto). Motivo: simetría con los 2 intentos del ZIP de `bootstrap`. Cubre: RF-25.
- D14: Barrido de secretos por patrón en nombre y contenido con omisión por fichero. Descartado abortar todo el bloque por un solo fichero. Motivo: P7 sin bloquear RF-19. Cubre: RF-21.
- D15: Gating por categoría (OpenCode en Dev/All, Brave en Base/All) + flags `-SkipOpenCode`/`-SkipBrave`. Descartado aplicar siempre por mezclar perfiles. Motivo: simetría con Git/VSCode (RF-6/RF-9). Cubre: RF-24.

## Trazabilidad RF -> módulo

- RF-17 -> `Config-OpenCode`, `install.ps1`
- RF-18 -> `Config-OpenCode`
- RF-19 -> `Config-OpenCode`, `config/opencode`
- RF-20 -> `Config-OpenCode`
- RF-21 -> `Config-OpenCode`, `config/opencode`
- RF-22 -> `Config-Brave`, `config/brave`
- RF-23 -> `Config-Brave`, `install.ps1`
- RF-24 -> `install.ps1`, `bootstrap.ps1`
- RF-25 -> `Config-OpenCode`
- RF-26 -> `Config-OpenCode`, `Config-Brave`, `install.ps1`, `bootstrap.ps1`
- RF-27 -> docs (`README.md`, `estructura-proyecto.md`, `constitution.md`, `AGENTS.md`)

## Riesgos y mitigaciones

- R5: El instalador oficial no ofrece verificación `winget list` → mitigación: comprobación de versión post-install con `ERROR` claro y re-ejecución segura.
- R6: Las extensiones exigen reiniciar Brave para aplicarse → mitigación: `WARNING` en log + fila en README, sin marcar `ERROR`.
- R7: El snapshot puede arrastrar secretos en el futuro → mitigación: barrido RF-21 en ejecución + grep en tests + checklist P7 en revisión.
- R8: Brave recién instalado aún sin perfil → mitigación: extensiones programadas + aviso de reinicio, re-ejecución segura.

## Dudas abiertas

- Sin `[NECESITA ACLARACION]` bloqueante. RF-20 resuelto (conservar con aviso).
- Addendums ratificados en implementación: params opcionales `DestinationRoot`/`PolicyRoot` (T14/T15, no rompen contratos); menú en línea pregunta OpenCode pero no Brave (T16, RF-24 cubierto por `-SkipBrave`).
