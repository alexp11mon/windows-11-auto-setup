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

El menú te deja elegir alcance (`All`, `Base`, `Dev`, `Gaming` o personalizado por app con Espacio), configurar u omitir Git, VSCode y OpenCode, y confirmar o simular antes de instalar. Las extensiones de Brave se aplican automáticamente con `Base` o `All` sin preguntar. La ventana nunca se cierra sola: al terminar (o cancelar) vuelve al prompt y el resultado queda en `$LASTEXITCODE` (`0` ok).

```powershell
# Opción B: descargar el lanzador y ejecutarlo con parámetros
Invoke-WebRequest https://raw.githubusercontent.com/alexp11mon/windows-11-auto-setup/master/bootstrap.ps1 -OutFile bootstrap.ps1

# Simular primero (recomendado)
.\bootstrap.ps1 -Category All -WhatIf

# Instalación completa
.\bootstrap.ps1 -Category All

# Con Git no interactivo
.\bootstrap.ps1 -Category Dev -GitUserName "Tu Nombre" -GitUserEmail "tu@email.com"

# Solo algunas apps (IDs de config/apps.json)
.\bootstrap.ps1 -Apps Valve.Steam,Brave.Brave

# Versión fija de una release, verificando el ZIP
.\bootstrap.ps1 -Category All -Branch v1.0.0 -Sha256 <hash-de-las-notas-de-la-release>
```

Notas:

- Descarga el ZIP de la rama `master` por defecto, lo extrae en `%TEMP%\win11-setup-*`, ejecuta `install.ps1` y borra lo descargado (usa `-KeepDownload` para conservarlo).
- `-Branch` acepta una rama o un tag de release (`vMAJOR.MINOR.PATCH`, p. ej. `v1.0.0`). Cada release publica en sus notas el SHA256 del ZIP; pásalo con `-Sha256` y, si no coincide, se aborta con salida `1` sin extraer nada. Usar un tag + `-Sha256` es lo más seguro: `master` puede cambiar en cualquier momento.
- El lanzador y el ZIP deben ir a la par: si pruebas una rama o tag (`-Branch mi-rama`), descarga el `bootstrap.ps1` de esa misma rama, o el `install.ps1` descargado puede no aceptar los flags nuevos.
- Si no eres admin, se abre el aviso UAC y la instalación corre en una ventana aparte; al terminar se imprime su código de salida aquí. Con el one-liner (`irm ... | iex`), el proceso elevado vuelve a descargar `bootstrap.ps1` de la misma rama en memoria: no se guarda ningún script en `%TEMP%`.
- Los logs se copian a `%LOCALAPPDATA%\win11-setup\logs` antes de borrar la carpeta temporal, también si la ejecución falla. Si el código de salida no es `0`, se muestran aquí las últimas 20 líneas del log.

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
- `1` = falta Admin, SO no compatible, falta winget/módulo, SHA256 del ZIP distinto, o hubo errores de instalación/configuración (revisa `logs/` en local o `%LOCALAPPDATA%\win11-setup\logs` en línea). El `exit code` de `bootstrap.ps1` es el de `install.ps1`.
- Si winget devuelve un código distinto de `0` pero la app sí queda instalada (p. ej. ya estaba instalada desde otra fuente), se registra `WARNING` y no cuenta como error.

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

Con `Dev` o `All` además se aplica configuración de Git (`user.name`, `user.email`, `init.defaultBranch=main` y alias `tree`), se instalan las extensiones de VSCode y se instala OpenCode con su configuración global (ver sección OpenCode). Con `Base` o `All` además se aplican automáticamente las extensiones de Brave (ver sección Brave).

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

### OpenCode (instalador oficial, excepción a solo-winget)

Con `Dev` o `All` (salvo `-SkipOpenCode`):

1. Si `opencode` no está instalado, se instala con el instalador oficial publicado por el proyecto OpenCode (`https://opencode.ai/install.ps1`, descargado con 2 intentos y verificado con `opencode --version`). Es la única excepción aprobada a la regla "solo winget" (RF-17, spec 002).
2. Se restaura la configuración global desde la copia versionada en `config/opencode/` (agentes, skills y `opencode.jsonc`; la carpeta `plugins/` se admite pero hoy no se versiona ninguno) fusionando sin borrar nada existente: ante el mismo fichero con distinto contenido se conserva el del usuario con aviso. Se omiten con aviso los ficheros cuyo nombre sugiere un secreto o que contienen una asignación tipo `token: valor` o `"apiKey": "valor"` (mencionar la palabra "token" en un texto no basta). El `snapshot` del repo nunca contiene secretos. `opencode.jsonc` admite comentarios `//` y `/* */`.

### Brave (extensiones automáticas)

Con `Base` o `All` (salvo `-SkipBrave` y sin pregunta en el menú):

1. Si Brave no está instalado, se instala primero vía winget.
2. Se aplican las 5 extensiones de `config/brave/extensions.json` de forma idempotente (las ya aplicadas se omiten). Son efectivas tras **reiniciar Brave**.
3. Se aplican como **política de equipo** (`ExtensionInstallForcelist` en `HKLM`): no se pueden desinstalar desde Brave y Brave muestra "gestionado por tu organización". Para quitar una, borra su valor en `HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist` como admin. Si no lo quieres, usa `-SkipBrave`.

| Extensión | ID |
|---|---|
| uBlock Origin Lite | `ddkjiahejlhfcafbddmgiahcphecmpfh` |
| Dark Reader | `eimadpbcbfnmbkopoojfekhnkhdbieeh` |
| Decentraleyes | `ldpochfccmkkmhdbclfhpagapcfdljkj` |
| Bitwarden | `nngceckbapebfimnlniiiahkandclblb` |
| Privacy Badger | `pkehgijcmpdhfbdbbnkijodmdjhbjlgp` |

## Tests (no instalan nada, todo mockeado)

```powershell
# Suite principal sin dependencias (205 checks)
pwsh -NoProfile -File tests/Runner-Mock.ps1

# Tests Pester 5 (requiere Install-Module Pester -MinimumVersion 5.0, 72 tests)
Invoke-Pester -Path ./tests -Output Detailed
```

## Notas

- La configuración de Git, VSCode y OpenCode solo se aplica con `-Category Dev` o `-Category All`; la de Brave solo con `-Category Base` o `-Category All`.
- Git es interactivo por defecto (pregunta nombre/email). Pásalos con `-GitUserName`/`-GitUserEmail` para automatizar, omítelo con `-SkipGit` (igual `-SkipVSCode`, `-SkipOpenCode`, `-SkipBrave` para el resto), o usa `-WhatIf` (no pregunta nada en simulación). El menú en línea ofrece omitir Git, VSCode y OpenCode (Brave es automático).
- Cada ejecución genera un log fechado en `logs/install-YYYYMMDD-HHmmss.log` (`*.log` están ignorados por git). En línea, además se copia a `%LOCALAPPDATA%\win11-setup\logs`.
- La instalación es idempotente: lo ya instalado se omite y el script puede re-ejecutarse.
- Tras instalar apps en la misma ejecución, el script refresca el `PATH` de la sesión (proceso + Machine + User, sin duplicados) para detectar `git`/`code` sin reiniciar. Si aun así su configuración se omite, abre una terminal nueva y re-ejecuta.
- Todos los fallos críticos salen con código `1`, apto para automatización (cualquier `ERROR` en el log marca la ejecución como fallida).
- Los mensajes del código y de los logs están en inglés; la documentación de usuario sigue en español.
- La detección de Windows 11 64-bit es independiente del idioma (acepta `64-bit`, `64 bits`, etc.) y ante un aborto muestra los valores detectados.

## Estructura

- `install.ps1`: punto de entrada. Chequea administrador, Windows 11 64-bit y winget. Flags `-Category` (`Base`, `Dev`, `Gaming`, `All`), `-GitUserName`/`-GitUserEmail`, `-SkipGit`/`-SkipVSCode`/`-SkipOpenCode`/`-SkipBrave` y `-WhatIf`. Marca `exit 1` si hubo algún `ERROR`.
- `bootstrap.ps1`: instalación en línea. Descarga el ZIP de GitHub (rama o tag), lo verifica con `-Sha256` si se indica, se auto-eleva a admin y ejecuta `install.ps1` con los mismos flags más `-Branch`, `-KeepDownload` y `-Apps`. Sin parámetros abre menú con flechas (alcance, personalizado, Git, VSCode, OpenCode, confirmación; Brave automático en `Base`/`All`).
- `config/apps.json`: lista de apps winget por categoría (`Base`, `Dev`, `Gaming`).
- `config/vscode/extensions.json`: extensiones de VSCode a instalar.
- `config/opencode/`: copia versionada de la configuración global de OpenCode (agentes, skills, `opencode.jsonc`), sin secretos ni rutas personales.
- `config/brave/extensions.json`: extensiones de Brave a aplicar (`{id, name}`).
- `config/git/`: reservado para futura configuración de Git por fichero (hoy la config es interactiva vía `Config-Git.ps1` o por parámetros).
- `modules/`: `Common.ps1` (log fechado, chequeo idempotente, instalación winget), `Install-Category.ps1` (orquesta categorías), `Config-Git.ps1`, `Config-VSCode.ps1`, `Config-OpenCode.ps1` (instalador oficial + fusión de snapshot), `Config-Brave.ps1` (Brave + extensiones).
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
| El one-liner pide UAC y termina con exit `1` sin ver por qué | La instalación elevada corre en otra ventana | Revisa `%LOCALAPPDATA%\win11-setup\logs` (se muestran las últimas 20 líneas del log al fallar) |
| `ZIP SHA256 mismatch` | El ZIP descargado no es el de la release indicada | Comprueba que `-Branch` y `-Sha256` son de la misma release; no continúes con un hash distinto |
| Spotify falla con código `-1978335146` ("no se puede ejecutar desde un contexto de administrador") | Su instalador es por-usuario y rechaza la sesión elevada | El script continúa con el resto y sale con `1`. Instala Spotify por separado sin elevar: `winget install --id Spotify.Spotify`. Otras apps por-usuario (p. ej. Discord) pueden comportarse igual |

## Créditos

Los tests de este proyecto (`tests/`) se crearon con IA, específicamente con OpenCode usando el agente gratuito Muse Spark 1.3.
