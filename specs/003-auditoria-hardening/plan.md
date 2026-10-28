# Plan 003 - Correcciones de la auditoría

Spec de origen: `specs/003-auditoria-hardening/spec.md`. Constitución: `docs/constitution.md`. Planes 001 y 002 siguen vigentes.

## Resumen de arquitectura

Sin módulos nuevos. Se corrigen `bootstrap.ps1`, `install.ps1`, `modules/Common.ps1`, `Config-Git/OpenCode/Brave.ps1`, el snapshot de OpenCode y las docs, más tests nuevos. Flujo en línea corregido: `bootstrap` (no admin) → relanza elevado (sin redirección, sin fichero temporal) → descarga y verifica ZIP → filtra apps → `install.ps1` → copia logs a ruta estable → limpia → propaga exit.

## Módulos y responsabilidades

- `bootstrap.ps1`: elevación sin `-Redirect*`, paso de `-Apps` al hijo, relanzamiento bajo `iex` sin fichero temporal, `-Sha256`, copia de logs, texto del menú sobre Brave. Cubre: RF-28, RF-29, RF-30, RF-31, RF-32, RF-42.
- `install.ps1`: módulos ausentes → ERROR; `Update-SessionPath` con `HashSet`. Cubre: RF-38, RF-41.
- `modules/Common.ps1`: tras `winget install` con código != 0, comprobar `Test-AppInstalled` y degradar a WARNING. Cubre: RF-36.
- `modules/Config-OpenCode.ps1`: patrón de secretos por asignación. Cubre: RF-34, RF-35.
- `modules/Config-Git.ps1`: comprobar `$LASTEXITCODE` tras cada `git config`. Cubre: RF-39.
- `modules/Config-Brave.ps1`: una sola lectura de políticas. Cubre: RF-40.
- `config/opencode/`: retirar `plugins/gk-hooks.js`. Cubre: RF-33.
- `tests/`: nuevos checks (forma de `Start-Process`, persistencia de logs, secretos, jsonc con comentarios, módulos ausentes, códigos winget, git). Cubre: RF-37 y los demás.
- Docs (`README.md`, `AGENTS.md`, `docs/estructura-proyecto.md`): `-Sha256`, tags, logs, política de Brave. Cubre: RF-32, RF-42.

## Modelo de datos

- Parámetros nuevos opcionales de `bootstrap`: `-Sha256 [string]` (hex de 64 caracteres, validado con `ValidatePattern`) y `-Apps [string[]]` (IDs winget; el filtro ya descarta los que no estén en `apps.json`).
- Ruta de logs estable: `Join-Path $env:LOCALAPPDATA 'win11-setup\logs'`.
- Patrón de secreto (RF-34): `(?i)(token|password|secret|api[_-]?key)["']?\s*[:=]\s*["']?\S{4,}` sobre contenido; el patrón por nombre de fichero se mantiene.
- Sin BD ni cambios en los JSON de catálogo.

## Contratos e interfaces

- `.\bootstrap.ps1 [flags actuales] [-Sha256 <hex64>] [-Apps <id,...>]` → salida 0 ok, 1 si falla elevación, descarga, hash o `install.ps1`.
- `Write-InstallLog` y `Invoke-*Config` sin cambio de firma.
- Errores: hash distinto → `ERROR` + salida 1 antes de extraer; módulo ausente → `ERROR`; `winget` != 0 con app presente → `WARNING`.

## Flujo principal paso a paso

1. Sin admin: `bootstrap` construye args (incluye `-Apps` si hay Custom, RF-29). En fichero: relanza `$PSCommandPath`. Bajo `iex`: relanza con `pwsh -Command "& ([scriptblock]::Create((irm <rawUrl>))) <args>"`, sin escribir a `%TEMP%` (RF-28, RF-30).
2. Con admin: descarga ZIP (2 intentos), verifica SHA256 si se pasó (RF-32), extrae, filtra `apps.json` con `-Apps` (RF-29).
3. Ejecuta `install.ps1` (RF-36, RF-38, RF-39, RF-40, RF-41 aplican dentro).
4. Copia `logs/*.log` a la ruta estable y muestra la ruta (RF-31); luego limpia el temporal.
5. Propaga exit (`return` bajo iex).

## Decisiones técnicas

- D16: Quitar `-RedirectStandardOutput/-RedirectStandardError` del `Start-Process -Verb RunAs`. Descartado envolver en `cmd /c ... >log` por violar "nunca cmd". El hijo muestra su propia ventana y el log persistente (D19) cubre el diagnóstico. Cubre: RF-28.
- D17: `-Apps` como parámetro explícito hacia el hijo. Descartado un fichero temporal de selección por la misma exposición que RF-30. Cubre: RF-29.
- D18: Bajo `iex`, el hijo se descarga el mismo script (`scriptblock::Create`) en vez de guardar `bootstrap-iex.ps1`. Descartado `-EncodedCommand` por superar el límite de ~32 K caracteres de línea de comandos (el script pesa ~15 KB, ~40 KB en base64). Descartado proteger con ACL la carpeta temporal porque el atacante es el mismo usuario. Cubre: RF-30.
- D19: Copiar los logs a `%LOCALAPPDATA%\win11-setup\logs` antes de limpiar. Descartado cambiar `Initialize-InstallLog` (también usado en local, donde `logs/` es correcto). Cubre: RF-31.
- D20: Verificación SHA256 opcional con `Get-FileHash`. Descartado hacerla obligatoria hasta tener release con hash (duda abierta). Cubre: RF-32.
- D21: Eliminar `gk-hooks.js` del snapshot en vez de parametrizarlo: GitKraken lo regenera. Esto acota el alcance de "plugins" de la spec 002 (la carpeta sigue soportada, hoy vacía). Cubre: RF-33.
- D22: Secretos por asignación con valor, no por palabra. Descartado quitar el barrido (rompería P7/RF-21). Cubre: RF-34.
- D23: Fijar con test que `ConvertFrom-Json` acepta comentarios en PS 7 (comprobado en 7.6.9); sin cambio de código. Cubre: RF-35.
- D24: Degradar a WARNING si winget != 0 pero `Test-AppInstalled` es verdadero. Descartada una lista fija de códigos winget (frágil entre versiones). Cubre: RF-36.
- D25: Test estático (AST) que revisa llamadas a `Start-Process` con `-Verb` + `-Redirect*`. Cubre: RF-37.
- D26: Resto (RF-38 a RF-42): cambios locales y mínimos en el módulo afectado, sin refactor mayor.

## Trazabilidad RF -> módulo

- RF-28 -> `bootstrap.ps1`
- RF-29 -> `bootstrap.ps1`
- RF-30 -> `bootstrap.ps1`
- RF-31 -> `bootstrap.ps1`
- RF-32 -> `bootstrap.ps1`, docs
- RF-33 -> `config/opencode`
- RF-34 -> `Config-OpenCode`
- RF-35 -> `Config-OpenCode` (test)
- RF-36 -> `Common`
- RF-37 -> `tests/`
- RF-38 -> `install.ps1`
- RF-39 -> `Config-Git`
- RF-40 -> `Config-Brave`
- RF-41 -> `install.ps1`
- RF-42 -> `bootstrap.ps1`, docs

## Riesgos y mitigaciones

- R9: Bajo `iex` el hijo descarga código otra vez (misma fuente que el ZIP) → mitigación: mismo `-Branch`/tag; documentar; `-Sha256` para el ZIP.
- R10: Retirar `gk-hooks.js` cambia el recuento de ficheros del snapshot (12 → 11) → mitigación: actualizar el check de `Runner-Mock.ps1` (línea 590).
- R11: Degradar a WARNING podría ocultar un fallo real → mitigación: solo si `winget list --exact` confirma la app.
- R12: La elevación solo se prueba de verdad a mano → mitigación: test AST + demo manual en T35.

## Dudas abiertas

- Las dos de la spec (tags de release; origen del script elevado bajo `iex`).
