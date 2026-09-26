# Constitution - Instalador Automático Windows 11

## Contexto y objetivo

El proyecto configura un PC nuevo con Windows 11 64-bit: instala aplicaciones vía winget por categorías (Base, Dev, Gaming, All) y aplica configuración base de Git y extensiones de VSCode. Incluye modo local (`install.ps1`) y modo en línea (`bootstrap.ps1` con auto-elevación y menú interactivo).

No es un gestor de paquetes general, no soporta Windows 10, Linux, macOS ni Windows 11 de 32-bit, no instala software fuera de winget ni guarda credenciales o tokens.

## Principios innegociables

- P1: Solo Windows 11 64-bit (Build >= 22000) con PowerShell 7 (`pwsh`). Se verifica con los guards de `install.ps1` (aborto con salida 1 si no cumple) y con `tests/Runner-Mock.ps1` en verde.
- P2: Solo instalación vía winget con `--exact --accept-source-agreements --accept-package-agreements`. Se verifica inspeccionando `modules/Common.ps1`: prohibido `choco`, `scoop`, `.exe` manuales o `Install-Module` en ruta de instalación.
- P3: Instalación idempotente y re-ejecutable; lo ya instalado se omite sin error. Se verifica con `Test-AppInstalled` (`winget list --exact`) y re-ejecutando `.\install.ps1 -Category All` con salida 0.
- P4: Todo `ERROR` en log marca fallo global (`$global:InstallHadErrors`) y salida 1; log fechado en `logs/install-YYYYMMDD-HHmmss.log`. Se verifica revisando `logs/` y `$LASTEXITCODE` = 1 ante cualquier `ERROR`.
- P5: Todo cambio soporta `-WhatIf` vía `SupportsShouldProcess` sin efectos secundarios y sin preguntas interactivas en simulación. Se verifica con `.\install.ps1 -Category All -WhatIf` y `.\bootstrap.ps1 -Category All -WhatIf` sin descargas ni instalaciones.
- P6: Ninguna tarea se da por hecha sin tests mockeados en verde que no instalan nada. Se verifica con `pwsh -NoProfile -File tests/Runner-Mock.ps1` en verde; Pester 5 solo para `*.Tests.ps1`.
- P7: Prohibidas credenciales, tokens o datos personales en el repo; Git pide `user.name`/`user.email` interactivo o por parámetros con validación de email. Se verifica con `grep` de `token|password|secret` sin resultados y revisión del diff.
- P8: La constitución manda sobre spec, plan, tareas y código; sin aprobación explícita no se avanza de fase. Se verifica con aprobación registrada en cada documento antes de implementar.

## Stack permitido

- Lenguaje y versión: PowerShell 7+ (`pwsh`). No vale `cmd` ni Windows PowerShell 5.1.
- Dependencias aceptadas: winget (App Installer), JSON local (`config/apps.json`, `config/vscode/extensions.json`), comandos nativos `git` y `code` solo para configuración.
- Herramientas obligatorias: `pwsh`, `tests/Runner-Mock.ps1` sin dependencias, Pester >= 5.0 solo para `tests/*.Tests.ps1`.

## Stack prohibido

Exige aprobación explícita en la spec si se quiere usar: `cmd`/PowerShell 5.1 como runtime, Chocolatey/Scoop/instaladores manuales, módulos de PSGallery en ruta de instalación, soporte a Windows 10/Linux/macOS/32-bit, telemetría, credenciales hardcodeadas, dependencias de red distintas a `github.com`/`raw.githubusercontent.com` para `bootstrap.ps1`.

## Convenciones

- Formato: UTF-8, `Join-Path` para rutas, `[CmdletBinding(SupportsShouldProcess=$true)]` en todo entry/module que cambie el sistema.
- Nombres: `PascalCase` en funciones (`Invoke-InstallCategory`, `Write-InstallLog`), `kebab-case` en carpetas de specs (`specs/001-instalador-win11/`), `UPPER` en flags globales (`$global:InstallHadErrors`).
- Estructura: `install.ps1`, `bootstrap.ps1`, `config/`, `modules/`, `tests/`, `logs/`, `docs/constitution.md`, `specs/NNN-nombre/spec.md|plan.md|tasks.md`, `AGENTS.md` en raíz.
- Idioma: español en docs y respuestas; inglés en código (comentarios, mensajes y logs, v2 RF-15) además de IDs winget y comandos.

## Verificación obligatoria

- [ ] Tests en verde: `pwsh -NoProfile -File tests/Runner-Mock.ps1`
- [ ] Pester en verde si se tocan `*.Tests.ps1`: `Invoke-Pester -Path ./tests -Output Detailed`
- [ ] Simulación sin efectos: `.\install.ps1 -Category All -WhatIf` y `.\bootstrap.ps1 -Category All -WhatIf` con salida 0
- [ ] Log sin `ERROR` imprevisto y salida 0/1 correcta en `logs/`
- [ ] Aprobación explícita del usuario antes de pasar de constitution → spec → plan → tasks → código

## Dudas abiertas

- Sin dudas bloqueantes para v1. V2 (internacionalización a inglés y limpieza de comentarios IA) se acuerda en `specs/001-instalador-win11/spec.md`.
