# Instalador Automático Windows 11

Configurador automático de PC nuevo con Windows 11 64-bit: instala apps con winget y aplica configuración básica de Git y VSCode.

## Requisitos

- Windows 11 64-bit (Build >= 22000), en cualquier idioma de visualización.
- **PowerShell 7** (`pwsh`). No vale `cmd` ni Windows PowerShell 5.1. Si no lo tienes:
  ```powershell
  winget install --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
  ```
- `winget` (App Installer desde Microsoft Store).
- Ejecutar como **Administrador**.
- Probar primero en máquina virtual o PC secundario.

## Uso

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
```

Notas:

- La configuración de Git y VSCode solo se aplica con `-Category Dev` o `-Category All`.
- Cada ejecución genera un log fechado en `logs/install-YYYYMMDD-HHmmss.log` (`*.log` están ignorados por git).
- La instalación es idempotente: lo ya instalado se omite y el script puede re-ejecutarse.
- Tras instalar apps en la misma ejecución, el script refresca el `PATH` de la sesión para detectar `git`/`code` sin reiniciar. Si aun así su configuración se omite, abre una terminal nueva y re-ejecuta.
- Todos los fallos críticos salen con código `1`, apto para automatización.
- La detección de Windows 11 64-bit es independiente del idioma (acepta `64-bit`, `64 bits`, etc.) y ante un aborto muestra los valores detectados.

## Estructura

- `install.ps1`: punto de entrada. Chequea administrador, Windows 11 64-bit y winget. Flags `-Category` (`Base`, `Dev`, `Gaming`, `All`) y `-WhatIf`.
- `config/apps.json`: lista de apps winget por categoría (`Base`, `Dev`, `Gaming`).
- `config/vscode/extensions.json`: extensiones de VSCode a instalar.
- `config/git/`: reservado para futura configuración de Git por fichero (hoy la config es interactiva vía `Config-Git.ps1`).
- `modules/`: `Common.ps1` (log fechado, chequeo idempotente, instalación winget), `Install-Category.ps1` (orquesta categorías), `Config-Git.ps1`, `Config-VSCode.ps1`.
- `logs/`: un `.log` fechado por ejecución.
- `docs/`: notas del proyecto (`estructura-proyecto.md`).

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| En `cmd`, `.\install.ps1 ...` "no hace nada" | Esa sintaxis es de PowerShell, no de `cmd` | Abre `pwsh` como admin, o desde `cmd`: `pwsh -File install.ps1 -Category All -WhatIf` |
| Aborto "exclusivamente para Windows 11 de 64 bits" en un Win11 válido | Comparación contra texto localizado (p. ej. `64 bits` en español) | Corregido: actualiza el script; el mensaje ahora muestra los valores detectados |
| La config de Git/VSCode se omite justo tras instalarlos | El `PATH` de la sesión aún no los incluye | El script lo refresca solo; si persiste, nueva terminal y re-ejecutar |
| Pide nombre/email de Git y se queda parado | `Config-Git.ps1` es interactivo | Introduce los datos, o pásalos por parámetro si automatizas |

## Pendiente

- Publicar el repo en GitHub y añadir `bootstrap.ps1` para instalación en una línea (descarga ZIP + auto-elevación + paso de `-Category`/`-WhatIf`).
