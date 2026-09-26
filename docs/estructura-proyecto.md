# Estructura del Proyecto - Instalador Automático Windows 11

Documento breve para saber qué va en cada carpeta y archivo. Proyecto v1: Windows 11 64-bit solamente, solo winget, instalación idempotente y re-ejecutable. V2 (spec 002): OpenCode vía instalador oficial (excepción a solo-winget) + extensiones de Brave.

## Árbol actual

```text
Instalador/
├── config/
│   ├── apps.json
│   ├── git/
│   ├── vscode/
│   │   └── extensions.json
│   ├── opencode/          # snapshot config global (agents, skills, plugins, opencode.jsonc)
│   └── brave/
│       └── extensions.json
├── modules/
│   ├── Common.ps1
│   ├── Install-Category.ps1
│   ├── Config-Git.ps1
│   ├── Config-VSCode.ps1
│   ├── Config-OpenCode.ps1
│   └── Config-Brave.ps1
├── tests/
│   ├── Runner-Mock.ps1
│   ├── Common.Tests.ps1
│   ├── Install-Category.Tests.ps1
│   ├── Config-Git.Tests.ps1
│   ├── Config-VSCode.Tests.ps1
│   ├── Config-OpenCode.Tests.ps1
│   ├── Config-Brave.Tests.ps1
│   ├── Install.Entry.Tests.ps1
│   └── Bootstrap.Entry.Tests.ps1
├── logs/
├── docs/
│   ├── constitution.md
│   └── estructura-proyecto.md
├── specs/001-instalador-win11/
│   ├── spec.md
│   ├── plan.md
│   └── tasks.md
├── specs/002-opencode-brave-v2/
│   ├── spec.md
│   ├── plan.md
│   └── tasks.md
├── install.ps1
├── bootstrap.ps1
├── AGENTS.md
├── .gitignore
├── LICENSE
└── README.md
```

## Carpetas

### `config/`
Datos, no lógica. `apps.json` con la lista de apps winget por categorías: Base, Dev, Gaming.

### `config/git/`
Reservado para futura configuración de Git por fichero (nombre, email y valores por defecto). Sin tokens ni credenciales. Hoy la configuración es interactiva desde `Config-Git.ps1` o por parámetros `-GitUserName`/`-GitUserEmail`.

### `config/vscode/`
Configuración de VSCode: `extensions.json` con la lista de extensiones a instalar.

### `config/opencode/`
Copia versionada de la configuración global de OpenCode: `agents/`, `skills/`, `plugins/` y `opencode.jsonc`. Sin secretos, tokens ni datos personales (verificado con grep en tests). Se excluyen artefactos npm (`node_modules/`, `package.json`, locks).

### `config/brave/`
Catálogo de extensiones de Brave: `extensions.json` con objetos `{id, name}` (IDs de 32 caracteres de Chrome Web Store).

### `modules/`
Funciones PowerShell:

- `Common.ps1`: log fechado por ejecución, chequeo idempotente vía `winget list --exact`, instalación con soporte `-WhatIf` y verificación por `$LASTEXITCODE`. Los `ERROR` marcan `$global:InstallHadErrors` para el `exit 1` final.
- `Install-Category.ps1`: `Invoke-InstallCategory -Category -AppsConfigPath`; expande `All` a `Base, Dev, Gaming` y delega en `Install-WingetApp` (sin doble `ShouldProcess`).
- `Config-Git.ps1`: `Invoke-GitConfig -UserName -UserEmail`; en `-WhatIf` sin datos no pregunta (no bloquea), si no pide nombre/email, valida formato y aplica `user.name`, `user.email`, `init.defaultBranch=main` y alias `tree`.
- `Config-VSCode.ps1`: `Invoke-VSCodeConfig -ExtensionsConfigPath`; instala extensiones ausentes con `code --install-extension` y verifica el resultado.
- `Config-OpenCode.ps1`: `Invoke-OpenCodeConfig -ConfigSourcePath [-DestinationRoot]`; instala con el instalador oficial si falta (2 intentos, verificado con `--version`) y fusiona el snapshot sin borrar nada del usuario (distinto → conservar con aviso; secretos → omitir con aviso).
- `Config-Brave.ps1`: `Invoke-BraveConfig -ExtensionsConfigPath [-PolicyRoot]`; asegura Brave vía winget y aplica las extensiones de forma idempotente con aviso de reinicio.

### `tests/`
Suite mockeada sin dependencias (`Runner-Mock.ps1`, 159 checks: sintaxis, JSON, winget/Git/VSCode/OpenCode/Brave con mocks, guards del entry, bootstrap y menú) + tests Pester 5+ por módulo (`Common`, `Install-Category`, `Config-Git`, `Config-VSCode`, `Config-OpenCode`, `Config-Brave`, `Install.Entry`, `Bootstrap.Entry`; 59 tests). No instalan nada: el registro solo se toca en clave HKCU temporal con limpieza. Requieren Pester 5+ solo para los `*.Tests.ps1`.

### `logs/`
Un `.log` fechado por ejecución (`install-YYYYMMDD-HHmmss.log`). Qué fue instalado y qué falló. Los `*.log` están ignorados por git; la carpeta se conserva con `.gitkeep`.

### `docs/`
Notas del proyecto. `constitution.md` es la ley SDD (manda sobre spec/plan/tasks/código). Incluye este archivo.

### `specs/001-instalador-win11/`
Contrato SDD: `spec.md` (QUÉ + RF en EARS, v1+v2), `plan.md` (CÓMO + decisiones D1..D8), `tasks.md` (T1..T11 con Hecho cuando + trazabilidad).

### `specs/002-opencode-brave-v2/`
Contrato SDD de la V2: `spec.md` (RF-17..RF-27), `plan.md` (decisiones D9..D15 + addendums ratificados), `tasks.md` (T12..T18).

## Archivos

### `install.ps1`
Punto de entrada. Chequea administrador (sale con código 1 si falta), Windows 11 64-bit de SO (Build >= 22000 y `OSArchitecture`), y winget disponible. Resuelve rutas con `Join-Path`, refresca el `PATH` de la sesión (proceso + Machine + User, sin duplicados) tras instalar para detectar `git`/`code` sin reiniciar, y propaga `-WhatIf`. Flags: `-Category (Base, Dev, Gaming, All)`, `-GitUserName`/`-GitUserEmail`, `-SkipGit`/`-SkipVSCode`/`-SkipOpenCode`/`-SkipBrave` y `-WhatIf`. La config de Git/VSCode/OpenCode solo corre con `Dev` o `All`; la de Brave solo con `Base` o `All`. Sale con `1` si hubo algún `ERROR`.

### `bootstrap.ps1`
Instalación en línea sin clonar. Descarga el ZIP de GitHub (`$Repo`/`$Branch`), se auto-eleva a admin con UAC, lo extrae en `%TEMP%`, ejecuta `install.ps1` con `-Category`/`-GitUserName`/`-GitUserEmail`/`-SkipGit`/`-SkipVSCode`/`-SkipOpenCode`/`-SkipBrave`/`-WhatIf` y propaga su `exit code`. Limpia lo descargado salvo `-KeepDownload`. En `-WhatIf` solo describe lo que haría. Sin parámetros abre un menú interactivo con flechas (`Show-Menu`, con fallback numerado `Show-NumberedMenu`): alcance, personalizado por app (filtra el `apps.json` extraído), Git (pedir datos u omitir), VSCode (instalar u omitir), OpenCode (aplicar u omitir) y confirmación (Brave automático en `Base`/`All`). Bajo `iex` se auto-guarda en `%TEMP%` para poder elevarse, y ninguna salida cierra la consola (`return` + `$LASTEXITCODE` en vez de `exit`).

### `.gitignore`
Ignora `logs/*.log` y temporales de Windows y VSCode. Conserva carpetas vacías con `.gitkeep`.

### `README.md`
Portada del repo: requisitos, cómo ejecutar (categorías, Git no interactivo, códigos de salida, tests), categorías y modo `-WhatIf`. Incluye créditos de tests con IA.

### `AGENTS.md`
Guía operativa para IA: comandos, estructura, convenciones, tests y flujo SDD obligatorio.

### `.gitkeep`
Placeholder para que git conserve carpetas vacías (`logs/`, `config/git/`). Se borra cuando la carpeta tenga archivos reales.
