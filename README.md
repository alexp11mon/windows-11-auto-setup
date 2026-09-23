# Instalador Automático Windows 11

Configurador automático de PC nuevo con Windows 11 64-bit: instala apps con winget y aplica configuración básica de Git y VSCode.

Estado: idea, sin código empezado.

## Requisitos

- Windows 11 64-bit solamente.
- PowerShell 7, winget, Git.
- Probar primero en máquina virtual o PC secundario.

## Uso futuro

Punto de entrada previsto: `install.ps1` con flags `-Category` (Base, Dev, Audio, Gaming) y `-WhatIf` para simular sin instalar.

## Estructura

- `config/`: datos (futuro `apps.json` por categorías) y subcarpetas `git/`, `vscode/`.
- `modules/`: funciones por categoría (`Install-Base`, `Install-Dev`, `Install-Gaming`, `Install-Audio`, `Common`).
- `logs/`: salida de cada ejecución con fecha.
- `docs/`: instalaciones manuales (FL Studio, VST) y notas.
