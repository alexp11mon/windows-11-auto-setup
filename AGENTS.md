# AGENTS.md - Instalador Automático Windows 11

> Instrucciones para agentes IA que trabajan en este repo. La constitución (`docs/constitution.md`) manda; este archivo es la guía operativa.

## Qué es

Configurador de PC nuevo con Windows 11 64-bit: instala apps vía winget por categorías y configura Git + extensiones VSCode. Idempotente, re-ejecutable, con simulación `-WhatIf` y logs fechados.

## Requisitos (no negociables)

- Windows 11 64-bit Build >= 22000, PowerShell 7 (`pwsh`), winget, ejecución como Administrador.
- Nunca uses `cmd` ni Windows PowerShell 5.1 para ejecutar. Sintaxis `.\install.ps1` solo funciona en `pwsh`.
- Detección OS independiente de idioma: `[Environment]::Is64BitOperatingSystem -and ($arch -match '64')`.

## Comandos clave

```powershell
# Simular (siempre antes de tocar nada real)
.\install.ps1 -Category All -WhatIf
.\bootstrap.ps1 -Category All -WhatIf

# Local (pwsh como admin)
.\install.ps1 -Category All
.\install.ps1 -Category Base|Dev|Gaming
.\install.ps1 -Category Dev -GitUserName "Nombre" -GitUserEmail "a@b.com"
.\install.ps1 -Category All -SkipGit -SkipVSCode

# Online (pwsh 7, auto-eleva solo)
irm https://raw.githubusercontent.com/alexp11mon/windows-11-auto-setup/master/bootstrap.ps1 | iex
.\bootstrap.ps1 -Category All -Branch master
```

Salidas: `0` ok, `1` falta admin/OS/winget/módulo o cualquier `ERROR` en `logs/`. `bootstrap` propaga el exit de `install`; bajo `iex` usa `return` + `$LASTEXITCODE`, nunca `exit`.

## Estructura

- `install.ps1`: entry local. Guards admin/OS/winget, `Join-Path` rutas, `Update-SessionPath`, orquesta categorías + Git/VSCode solo si Dev/All.
- `bootstrap.ps1`: entry online. ZIP de `$Repo/$Branch` a `%TEMP%\win11-setup-*`, 2 intentos descarga, `Show-Menu` flechas + `Show-NumberedMenu` fallback, custom filtra `apps.json`, `-KeepDownload` conserva.
- `config/apps.json`: `{Base[], Dev[], Gaming[]}` con IDs winget exactos. Datos, no lógica.
- `config/vscode/extensions.json`: `{extensions[]}`.
- `config/git/`: reservado, sin tokens.
- `modules/Common.ps1`: `Write-InstallLog` (ERROR→`$global:InstallHadErrors`), `Test-AppInstalled` (`winget list --exact`), `Install-WingetApp` (`--exact --silent` + verificación, único con `ShouldProcess`).
- `modules/Install-Category.ps1`: expande `All`, sin doble `ShouldProcess`.
- `modules/Config-Git.ps1`: omite si no hay `git`; en `-WhatIf` sin datos no pregunta; valida email regex; aplica `main` + alias `tree`.
- `modules/Config-VSCode.ps1`: instala ausentes con `code --install-extension --force`.
- `tests/Runner-Mock.ps1`: suite sin dependencias (102 checks, todo mockeado). `tests/*.Tests.ps1`: Pester 5.
- `docs/constitution.md`: ley del proyecto. `specs/001-instalador-win11/{spec,plan,tasks}.md`: contrato SDD. `docs/estructura-proyecto.md`: mapa carpetas.

## Convenciones para IA

- Español en docs, mensajes, logs y respuestas. Inglés solo en IDs winget/comandos. v2 prevé inglés en código (ver `tasks.md` T9).
- `PascalCase` funciones, `Join-Path` siempre, `[CmdletBinding(SupportsShouldProcess=$true)]` en todo lo que cambie el sistema.
- JSON en UTF-8, sin comentarios. Comentarios de código concisos, sin restos obvios de IA (v2 T8).
- Prohibido: `choco`/`scoop`/`.exe` manuales, módulos PSGallery en instalación, credenciales/tokens, soporte Win10/Linux/macOS, cerrar consola bajo `iex`.
- Apps por-usuario (Spotify `-1978335146`, Discord) pueden fallar como admin: continuar + `exit 1` + documentar instalación manual sin elevar.

## Tests (no instalan nada)

```powershell
pwsh -NoProfile -File tests/Runner-Mock.ps1
Invoke-Pester -Path ./tests -Output Detailed  # requiere Pester 5
```

Toda tarea de código exige su test primero o cita el test que la cierra. Si tocas `Common`, `Install-Category`, `Config-Git/VSCode` o entries, la suite mockeada debe seguir en verde.

## Flujo SDD obligatorio

1. Lee `docs/constitution.md` + `specs/001-instalador-win11/spec.md` + `plan.md` antes de proponer cambios.
2. Orden: constitution → spec (QUÉ) → plan (CÓMO) → tasks (T1..Tn con `Hecho cuando` + `Cubre`) → código.
3. Un RF, una frase; un módulo, una responsabilidad; toda tarea traza a RF + módulo.
4. Pide aprobación explícita antes de cambiar de fase. Marca huecos como `[NECESITA ACLARACION: ...]`, nunca inventes.
5. Verifica siempre: `Runner-Mock` verde + `-WhatIf` con salida 0 + log sin `ERROR` imprevisto.

## Al revisar / implementar

- Si un RF es inviable, repórtalo y detente; no cambies la spec en silencio.
- Si el diff toca mensajes de usuario, mantén español (hasta T9). Si toca docs SDD, actualiza trazabilidad RF→módulo→tarea.
- `logs/*.log` ignorados por git; no los commitees. No commitees `%TEMP%\win11-setup-*`.
