# Instalador Automático Windows 11

Configurador automático de PC nuevo con Windows 11 64-bit: instala apps con winget y aplica configuración básica de Git y VSCode.

## Requisitos

- Windows 11 64-bit solamente.
- PowerShell 7, winget (App Installer desde Microsoft Store).
- Ejecutar como Administrador.
- Probar primero en máquina virtual o PC secundario.

## Uso

```powershell
# Simular sin instalar (recomendado antes de la ejecución real)
.\install.ps1 -Category All -WhatIf

# Instalación completa (Base + Dev + Gaming, más config de Git y VSCode)
.\install.ps1 -Category All

# Solo una categoría
.\install.ps1 -Category Base
.\install.ps1 -Category Dev
.\install.ps1 -Category Gaming
```

La configuración de Git y VSCode solo se aplica con `-Category Dev` o `-Category All`.
Cada ejecución genera un log fechado en `logs/install-YYYYMMDD-HHmmss.log`.
La instalación es idempotente: lo ya instalado se omite y el script puede re-ejecutarse.

## Estructura

- `install.ps1`: punto de entrada. Chequea administrador, Windows 11 64-bit y winget. Flags `-Category` (`Base`, `Dev`, `Gaming`, `All`) y `-WhatIf`.
- `config/apps.json`: lista de apps winget por categoría (`Base`, `Dev`, `Gaming`).
- `config/vscode/extensions.json`: extensiones de VSCode a instalar.
- `config/git/`: reservado para futura configuración de Git por fichero (hoy la config es interactiva vía `Config-Git.ps1`).
- `modules/`: `Common.ps1` (log fechado, chequeo idempotente, instalación winget), `Install-Category.ps1` (orquesta categorías), `Config-Git.ps1`, `Config-VSCode.ps1`.
- `logs/`: un `.log` fechado por ejecución (`*.log` ignorados por git).
- `docs/`: notas del proyecto (`estructura-proyecto.md`).
