# Instalador Automático Windows 11

Configurador automático de PC nuevo con Windows 11 64-bit: instala apps con winget y aplica configuración básica de Git y VSCode.

## Requisitos

- Windows 11 64-bit (Build >= 22000), en cualquier idioma de visualización.
- **PowerShell 7** (`pwsh`). No vale `cmd` ni Windows PowerShell 5.1. Si no lo tienes:
  ```powershell
  winget install --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
  ```
- `winget` (App Installer desde Microsoft Store).
- Ejecutar como **Administrador** (el método en línea se auto-eleva solo).
- Probar primero en máquina virtual o PC secundario.

## Instalación

### En línea (sin clonar, recomendado)

Desde PowerShell 7 (**no** hace falta abrirlo como admin: `bootstrap.ps1` se auto-eleva solo):

```powershell
# Opción A: un solo comando con menú interactivo (elige con flechas + Espacio)
irm https://raw.githubusercontent.com/alexp11mon/windows-11-auto-setup/master/bootstrap.ps1 | iex
```

El menú te deja elegir alcance (`All`, `Base`, `Dev`, `Gaming` o personalizado por app con Espacio), configurar u omitir Git, y confirmar o simular antes de instalar. La ventana nunca se cierra sola: al terminar (o cancelar) vuelve al prompt y el resultado queda en `$LASTEXITCODE` (`0` ok).

```powershell
# Opción B: descargar el lanzador y ejecutarlo con parámetros
Invoke-WebRequest https://raw.githubusercontent.com/alexp11mon/windows-11-auto-setup/master/bootstrap.ps1 -OutFile bootstrap.ps1

# Simular primero (recomendado)
.\bootstrap.ps1 -Category All -WhatIf

# Instalación completa
.\bootstrap.ps1 -Category All

# Con Git no interactivo
.\bootstrap.ps1 -Category Dev -GitUserName "Tu Nombre" -GitUserEmail "tu@email.com"
```

Notas:

- Descarga el ZIP de la rama `master` por defecto (`-Branch` para cambiarla), lo extrae en `%TEMP%\win11-setup-*`, ejecuta `install.ps1` y borra lo descargado (usa `-KeepDownload` para conservarlo).

### Local (clonando el repo)

Desde PowerShell 7 abierto como Administrador:

```powershell
cd "C:\ruta\al\proyecto\Instalador"

# Simular sin instalar (recomendado antes de la ejecución real)
.\install.ps1 -Category All -WhatIf

# Instalación completa (Base + Dev + Gaming, más config de Git y VSCode)
.\install.ps1 -Category All

# Solo una categoría
.\install.ps1 -Category Base
.\install.ps1 -Category Dev
.\install.ps1 -Category Gaming

# Git no interactivo (evita las preguntas de nombre/email)
.\install.ps1 -Category Dev -GitUserName "Tu Nombre" -GitUserEmail "tu@email.com"

# Combinado: simulación con datos de Git (no pregunta nada)
.\install.ps1 -Category All -GitUserName "Tu Nombre" -GitUserEmail "tu@email.com" -WhatIf
```

### Códigos de salida (ambos métodos)

- `0` = todo correcto.
- `1` = falta Admin, SO no compatible, falta winget/módulo, o hubo errores de instalación/configuración (revisa `logs/`). El `exit code` de `bootstrap.ps1` es el de `install.ps1`.

## Programas por defecto

Con `-Category All` se instala todo lo siguiente. Con `-Category Base|Dev|Gaming` solo su bloque.

### Base (uso diario)

| Programa | ID winget |
|---|---|
| Brave | `Brave.Brave` |
| WinRAR | `RARLab.WinRAR` |
| Revo Uninstaller | `RevoUninstaller.RevoUninstaller` |
| WizTree | `AntibodySoftware.WizTree` |
| Obsidian | `Obsidian.Obsidian` |
| Spotify | `Spotify.Spotify` |

### Dev (desarrollo)

| Programa | ID winget |
|---|---|
| Visual Studio Code | `Microsoft.VisualStudioCode` |
| Git | `Git.Git` |
| GitKraken | `Axosoft.GitKraken` |
| PowerShell 7 | `Microsoft.PowerShell` |
| Windows Terminal | `Microsoft.WindowsTerminal` |
| Warp | `Warp.Warp` |

Con `Dev` o `All` además se aplica configuración de Git (`user.name`, `user.email`, `init.defaultBranch=main` y alias `tree`) y se instalan las extensiones de VSCode.

### Gaming

| Programa | ID winget |
|---|---|
| Steam | `Valve.Steam` |
| Epic Games Launcher | `EpicGames.EpicGamesLauncher` |
| Prism Launcher | `PrismLauncher.PrismLauncher` |
| Discord | `Discord.Discord` |

### Extensiones de VSCode (10)

| Extensión | ID |
|---|---|
| C/C++ Extension Pack | `ms-vscode.cpptools-extension-pack` |
| CMake Tools | `ms-vscode.cmake-tools` |
| HTML5 Boilerplate | `sidthesloth.html5-boilerplate` |
| HTML CSS Support | `ecmel.vscode-html-css` |
| Markdown All in One | `yzhang.markdown-all-in-one` |
| PowerShell | `ms-vscode.powershell` |
| Pylance | `ms-python.vscode-pylance` |
| Python | `ms-python.python` |
| Python Debugger | `ms-python.debugpy` |
| Python Envs | `ms-python.vscode-python-envs` |

## Tests (no instalan nada, todo mockeado)

```powershell
# Suite principal sin dependencias (102 checks)
pwsh -NoProfile -File tests/Runner-Mock.ps1

# Tests Pester 5 (requiere Install-Module Pester -MinimumVersion 5.0)
Invoke-Pester -Path ./tests -Output Detailed
```

## Notas

- La configuración de Git y VSCode solo se aplica con `-Category Dev` o `-Category All`.
- Git es interactivo por defecto (pregunta nombre/email). Pásalos con `-GitUserName`/`-GitUserEmail` para automatizar, omítelo con `-SkipGit` (igual `-SkipVSCode` para extensiones), o usa `-WhatIf` (no pregunta nada en simulación). El menú en línea ofrece ambas omisiones.
- Cada ejecución genera un log fechado en `logs/install-YYYYMMDD-HHmmss.log` (`*.log` están ignorados por git).
- La instalación es idempotente: lo ya instalado se omite y el script puede re-ejecutarse.
- Tras instalar apps en la misma ejecución, el script refresca el `PATH` de la sesión (proceso + Machine + User, sin duplicados) para detectar `git`/`code` sin reiniciar. Si aun así su configuración se omite, abre una terminal nueva y re-ejecuta.
- Todos los fallos críticos salen con código `1`, apto para automatización (cualquier `ERROR` en el log marca la ejecución como fallida).
- La detección de Windows 11 64-bit es independiente del idioma (acepta `64-bit`, `64 bits`, etc.) y ante un aborto muestra los valores detectados.

## Estructura

- `install.ps1`: punto de entrada. Chequea administrador, Windows 11 64-bit y winget. Flags `-Category` (`Base`, `Dev`, `Gaming`, `All`), `-GitUserName`/`-GitUserEmail`, `-SkipGit`/`-SkipVSCode` y `-WhatIf`. Marca `exit 1` si hubo algún `ERROR`.
- `bootstrap.ps1`: instalación en línea. Descarga el ZIP de GitHub, se auto-eleva a admin y ejecuta `install.ps1` con los mismos flags más `-Branch` y `-KeepDownload`. Sin parámetros abre menú con flechas (alcance, personalizado, Git, VSCode, confirmación).
- `config/apps.json`: lista de apps winget por categoría (`Base`, `Dev`, `Gaming`).
- `config/vscode/extensions.json`: extensiones de VSCode a instalar.
- `config/git/`: reservado para futura configuración de Git por fichero (hoy la config es interactiva vía `Config-Git.ps1` o por parámetros).
- `modules/`: `Common.ps1` (log fechado, chequeo idempotente, instalación winget), `Install-Category.ps1` (orquesta categorías), `Config-Git.ps1`, `Config-VSCode.ps1`.
- `tests/`: `Runner-Mock.ps1` (suite sin dependencias, todo mockeado) + tests Pester 5 por módulo.
- `logs/`: un `.log` fechado por ejecución.
- `docs/`: notas del proyecto (`estructura-proyecto.md`).

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| En `cmd`, `.\install.ps1 ...` "no hace nada" | Esa sintaxis es de PowerShell, no de `cmd` | Abre `pwsh` como admin, o desde `cmd`: `pwsh -File install.ps1 -Category All -WhatIf` |
| Aborto "exclusivamente para Windows 11 de 64 bits" en un Win11 válido | Comparación contra texto localizado (p. ej. `64 bits` en español) | Corregido: actualiza el script; el mensaje ahora muestra los valores detectados |
| La config de Git/VSCode se omite justo tras instalarlos | El `PATH` de la sesión aún no los incluye | El script lo refresca solo; si persiste, nueva terminal y re-ejecutar |
| Pide nombre/email de Git y se queda parado | `Config-Git.ps1` es interactivo | Introduce los datos, pásalos por parámetro (`-GitUserName "Tu Nombre" -GitUserEmail "tu@email.com"`), u omite la config con `-SkipGit` (igual `-SkipVSCode`) |
| Spotify falla con código `-1978335146` ("no se puede ejecutar desde un contexto de administrador") | Su instalador es por-usuario y rechaza la sesión elevada | El script continúa con el resto y sale con `1`. Instala Spotify por separado sin elevar: `winget install --id Spotify.Spotify`. Otras apps por-usuario (p. ej. Discord) pueden comportarse igual |

## Créditos

Los tests de este proyecto (`tests/`) se crearon con IA, específicamente con OpenCode usando el agente gratuito Muse Spark 1.3.
