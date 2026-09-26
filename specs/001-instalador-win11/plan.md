# Plan 001 - Instalador Automático Windows 11

Spec de origen: `specs/001-instalador-win11/spec.md`. Constitución: `docs/constitution.md`.

## Resumen de arquitectura

Scripts de orquestación sin estado (`install.ps1` local, `bootstrap.ps1` en línea) + módulos de funciones dot-sourced + datos JSON en `config/`. Sin dependencias externas salvo winget/`git`/`code`. Diagrama textual: `bootstrap → ZIP %TEMP% → install → Install-Category → Common(winget) → Update-SessionPath → Config-Git → Config-VSCode → log + exit`.

## Módulos y responsabilidades

- `install.ps1`: entry local. Valida admin, Win11 64-bit, winget; resuelve rutas; orquesta categorías y configs. No instala directo. Cubre: RF-1, RF-2, RF-5, RF-6, RF-9, RF-10, RF-11, RF-12.
- `bootstrap.ps1`: entry en línea. Descarga ZIP (2 intentos), auto-eleva, menú flechas + fallback numerado, filtrado custom de `apps.json`, ejecuta `install.ps1`, propaga exit, limpia `%TEMP%`. No cierra consola bajo `iex` (`return` + `$LASTEXITCODE`). Cubre: RF-3, RF-4, RF-5, RF-11, RF-12.
- `modules/Common.ps1`: `Initialize-InstallLog`, `Write-InstallLog` (marca `InstallHadErrors` en `ERROR`), `Test-AppInstalled` (`winget list --exact`), `Install-WingetApp` (idempotente + `ShouldProcess` + verificación). No orquesta categorías. Cubre: RF-10, RF-11, RF-12, RF-13.
- `modules/Install-Category.ps1`: `Invoke-InstallCategory -Category -AppsConfigPath`; expande `All` a Base/Dev/Gaming; evita doble `ShouldProcess`. Cubre: RF-1, RF-10.
- `modules/Config-Git.ps1`: `Invoke-GitConfig`; omite si no hay `git`, no pregunta en `-WhatIf` sin datos, valida email, aplica `user.name/email/main/tree`. Solo Dev/All (decidido por el caller). Cubre: RF-6, RF-7, RF-8.
- `modules/Config-VSCode.ps1`: `Invoke-VSCodeConfig`; lista instalada una vez, instala ausentes con `code --install-extension --force`. Solo Dev/All. Cubre: RF-9, RF-10.
- `config/`: datos, no lógica. `apps.json` {Base[], Dev[], Gaming[] con IDs winget}, `vscode/extensions.json` {extensions[]}, `git/` reservado. Cubre: RF-1, RF-9.

## Modelo de datos

- App { id: winget-ID exacto (`Brave.Brave`), categoría: Base|Dev|Gaming, nombre derivado: `id.Split('.')[-1]` }.
- Validación: ID no vacío; categoría con lista no nula; JSON válido o `ERROR`.
- Extensión { id: marketplace (`ms-python.python`) }, lista instalada vía `code --list-extensions`.
- Git { user.name: no vacío, user.email: regex `^[^@\s]+@[^@\s]+\.[^@\s]+$`, `init.defaultBranch=main`, `alias.tree=log --graph...` }.
- Persistencia: JSON local UTF-8 leído con `Get-Content -Raw | ConvertFrom-Json`; logs append en `logs/install-*.log`; sin BD.

## Contratos e interfaces

- `.\install.ps1 [-Category Base|Dev|Gaming|All] [-GitUserName ""] [-GitUserEmail ""] [-SkipGit] [-SkipVSCode] [-WhatIf]` → salida 0 ok, 1 en falta admin/OS/winget/módulo o cualquier `ERROR`.
- `.\bootstrap.ps1 [mismos flags install + -Repo -Branch master -KeepDownload] [-WhatIf]` → bajo `-WhatIf` solo imprime `Would download: ZIP` y `Would extract...`; interactivo sin params abre menús; `Esc`/vacío = cancelado salida 0.
- `Invoke-InstallCategory -Category -AppsConfigPath`, `Install-WingetApp -AppId -AppName`, `Invoke-GitConfig -UserName -UserEmail`, `Invoke-VSCodeConfig -ExtensionsConfigPath`, `Write-InstallLog -Message -Level INFO|WARNING|ERROR`.
- Errores: `winget exit !=0` → `ERROR` y continúa; Spotify `-1978335146` documentado como caso por-usuario; `git/code` ausente → `WARNING` y omitir.

## Flujo principal paso a paso

1. Usuario `.\install.ps1 -Category All` (RF-1, RF-2) → chequeo admin/OS/winget → `Initialize-InstallLog` (RF-12).
2. `Invoke-InstallCategory All` → expande a 3 categorías → por cada ID `Test-AppInstalled`, si ausente `winget install --exact --silent`, verifica con `list` (RF-10, RF-13).
3. `Update-SessionPath` combina proceso+Machine+User sin duplicados para detectar `git`/`code` (RNF-3).
4. Si Dev/All → `Invoke-GitConfig` (RF-6/RF-7/RF-8) y `Invoke-VSCodeConfig` (RF-9); si `-WhatIf` solo loguea simulación (RF-11).
5. Cierre: si `InstallHadErrors` → mensaje rojo + `exit 1`, si no verde + `exit 0` (RF-12).
6. Online: `bootstrap` menú (RF-3) → descarga ZIP x2 → extrae → filtra `apps.json` si custom → `Start-Process pwsh install` → propaga exit → limpia salvo `-KeepDownload` (RF-4, RF-5).
7. v2: limpieza comentarios (RF-14), inglés en código (RF-15), README/docs (RF-16) sin cambiar lógica.

## Decisiones técnicas

- D1: `winget --exact --silent` + verificación `winget list --exact`. Descartado fuzzy-match por riesgo de app errónea. Motivo: idempotencia P3. Cubre: RF-10, RF-13.
- D2: Detección OS `[Environment]::Is64BitOperatingSystem -and ($arch -match '64')` + `Build>=22000`. Descartada comparación exacta `eq '64-bit'` por localización (`64 bits`). Motivo: RNF-1 independiente de idioma. Cubre: RF-12.
- D3: `ShouldProcess` solo en `Install-WingetApp`/`Config-*`, no en `Invoke-InstallCategory`. Descartado doble `ShouldProcess` por doble prompt/log en `-WhatIf`. Motivo: P5 simulación limpia. Cubre: RF-11.
- D4: `bootstrap` con `return + $LASTEXITCODE` bajo `iex`, `exit` en fichero. Descartado `exit` siempre por cerrar la consola del usuario. Motivo: RF-4. Cubre: RF-4.
- D5: Menú flechas `Show-Menu` + fallback `Show-NumberedMenu` por `KeyAvailable`. Descartado solo-flechas por fallo en ISE/redirección. Motivo: RF-3 portable. Cubre: RF-3.
- D6: JSON local sin esquema externo. Descartada SQLite/YAML por sobreingeniería para catálogo estático. Motivo: simplicidad y P2. Cubre: RF-1, RF-9.
- D7: `Update-SessionPath` por merge sin duplicados. Descartado reinicio obligatorio por fricción UX. Motivo: detectar `git`/`code` same-run. Cubre: RNF-3.
- D8: v2 inglés solo en código, español en docs. Descartado inglés total por decisión de usuario (docs en español). Motivo: P8/convención. Cubre: RF-15, RF-16.

## Trazabilidad RF -> módulo

- RF-1 -> `Install-Category`, `config`
- RF-2 -> `install.ps1`
- RF-3 -> `bootstrap.ps1`
- RF-4 -> `bootstrap.ps1`
- RF-5 -> `install.ps1`, `bootstrap.ps1`
- RF-6 -> `Config-Git`, `install.ps1`
- RF-7 -> `Config-Git`
- RF-8 -> `Config-Git`
- RF-9 -> `Config-VSCode`, `install.ps1`
- RF-10 -> `Common`, `Install-Category`, `Config-VSCode`
- RF-11 -> `Common`, `install.ps1`, `bootstrap.ps1`
- RF-12 -> `Common`, `install.ps1`, `bootstrap.ps1`
- RF-13 -> `Common`
- RF-14 -> v2 limpieza (todos los `modules/`)
- RF-15 -> v2 idioma (`install.ps1`, `modules/`)
- RF-16 -> v2 docs (`README.md`, `docs/`)

## Riesgos y mitigaciones

- R1: App por-usuario falla como admin (Spotify, Discord) → mitigación: continuar + `exit 1` + documentar instalación manual sin elevar, sin cambiar RF.
- R2: `winget` lento o `list` no refleja install inmediata → mitigación: verificación post-install con `ERROR` claro, re-ejecución segura.
- R3: UAC silenciosa deja log huérfano → mitigación: log `%TEMP%\win11-setup-elevated-*.log` con exit impreso.
- R4: `code`/`git` no en `PATH` same-run → mitigación: `Update-SessionPath` + aviso de re-ejecutar en terminal nueva.

## Dudas abiertas

- Sin `[NECESITA ACLARACION]` bloqueante. El repo/branch por defecto son parámetros, no contrato.
