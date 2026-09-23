# Estructura del Proyecto - Instalador Automático Windows 11

Documento breve para saber qué va en cada carpeta y archivo. Proyecto v1: Windows 11 64-bit solamente, solo winget, instalación idempotente y re-ejecutable.

## Árbol actual

```text
Instalador/
├── config/
│   ├── apps.json
│   ├── git/
│   └── vscode/
│       └── extensions.json
├── modules/
│   ├── Common.ps1
│   ├── Install-Category.ps1
│   ├── Config-Git.ps1
│   └── Config-VSCode.ps1
├── logs/
├── docs/
│   └── estructura-proyecto.md
├── install.ps1
├── .gitignore
├── LICENSE
└── README.md
```

## Carpetas

### `config/`
Datos, no lógica. `apps.json` con la lista de apps winget por categorías: Base, Dev, Gaming.

### `config/git/`
Reservado para futura configuración de Git por fichero (nombre, email y valores por defecto). Sin tokens ni credenciales. Hoy la configuración es interactiva desde `Config-Git.ps1`.

### `config/vscode/`
Configuración de VSCode: `extensions.json` con la lista de extensiones a instalar.

### `modules/`
Funciones PowerShell:

- `Common.ps1`: log fechado por ejecución, chequeo idempotente vía `winget list --exact`, instalación con soporte `-WhatIf` y verificación por `$LASTEXITCODE`.
- `Install-Category.ps1`: `Invoke-InstallCategory -Category -AppsConfigPath`; expande `All` a `Base, Dev, Gaming` y delega en `Install-WingetApp` (sin doble `ShouldProcess`).
- `Config-Git.ps1`: `Invoke-GitConfig`; pide nombre/email, valida formato y aplica `user.name`, `user.email`, `init.defaultBranch=main` y alias `tree`.
- `Config-VSCode.ps1`: `Invoke-VSCodeConfig -ExtensionsConfigPath`; instala extensiones ausentes con `code --install-extension` y verifica el resultado.

### `logs/`
Un `.log` fechado por ejecución (`install-YYYYMMDD-HHmmss.log`). Qué fue instalado y qué falló. Los `*.log` están ignorados por git; la carpeta se conserva con `.gitkeep`.

### `docs/`
Notas del proyecto. Incluye este archivo.

## Archivos

### `install.ps1`
Punto de entrada. Chequea administrador (sale con código 1 si falta), Windows 11 64-bit de SO (Build >= 22000 y `OSArchitecture`), y winget disponible. Resuelve rutas con `Join-Path`, refresca el `PATH` de la sesión tras instalar para detectar `git`/`code` sin reiniciar, y propaga `-WhatIf`. Flags: `-Category (Base, Dev, Gaming, All)` y `-WhatIf`. La config de Git/VSCode solo corre con `Dev` o `All`.

### `.gitignore`
Ignora `logs/*.log` y temporales de Windows y VSCode. Conserva carpetas vacías con `.gitkeep`.

### `README.md`
Portada del repo: requisitos, cómo ejecutar, categorías y modo `-WhatIf`.

### `.gitkeep`
Placeholder para que git conserve carpetas vacías (`logs/`, `config/git/`). Se borra cuando la carpeta tenga archivos reales.
