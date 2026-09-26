# Tasks 001 - Instalador Automático Windows 11

Spec: `specs/001-instalador-win11/spec.md`. Plan: `specs/001-instalador-win11/plan.md`.

## Tareas

- [ ] T1 Congelar verificación base v1 con suite mockeada
  Hecho cuando: `pwsh -NoProfile -File tests/Runner-Mock.ps1` en verde (102 checks). Cubre: RF-1 a RF-13 | Módulo: validación
- [ ] T2 Validar entries local y online en simulación
  Hecho cuando: `.\install.ps1 -Category All -WhatIf` y `.\bootstrap.ps1 -Category All -WhatIf` con salida 0 sin descargas ni instalaciones. Cubre: RF-2, RF-11, RF-12 | Módulo: install.ps1, bootstrap.ps1
- [ ] T3 Validar categorías e idempotencia winget
  Hecho cuando: `Invoke-InstallCategory -Category All` omite lo instalado vía `winget list --exact` y `Install-WingetApp` verifica post-install. Cubre: RF-1, RF-10, RF-13 | Módulo: Install-Category, Common
- [ ] T4 Validar Git solo Dev/All con modos interactivo/params/skip
  Hecho cuando: con `-GitUserName/-GitUserEmail` no pregunta, con `-SkipGit` omite, con email inválido avisa y continúa, en `-WhatIf` sin datos no bloquea. Cubre: RF-6, RF-7, RF-8 | Módulo: Config-Git
- [ ] T5 Validar VSCode solo Dev/All con skip e idempotencia
  Hecho cuando: extensiones ausentes se instalan con `code --install-extension --force`, presentes se omiten, `-SkipVSCode` omite todo. Cubre: RF-9, RF-10 | Módulo: Config-VSCode
- [ ] T6 Validar menú online, elevación y no-cierre bajo iex
  Hecho cuando: menú flechas + fallback numerado, `Esc`/vacío cancela con 0, elevación propaga exit, bajo `iex` usa `return` + `$LASTEXITCODE` sin cerrar consola. Cubre: RF-3, RF-4, RF-5 | Módulo: bootstrap.ps1
- [ ] T7 Validar logs, exit codes y PATH refrescado
  Hecho cuando: cada ejecución crea `logs/install-*.log`, cualquier `ERROR` deja `exit 1`, `Update-SessionPath` detecta `git`/`code` same-run o avisa re-ejecutar. Cubre: RF-12, RNF-3 | Módulo: Common, install.ps1
- [ ] T8 v2: limpiar comentarios redundantes de IA
  Hecho cuando: revisión del diff en `modules/*.ps1`, `install.ps1`, `bootstrap.ps1` sin comentarios explicativos obvios. Cubre: RF-14 | Módulo: todos
- [ ] T9 v2: pasar comentarios/avisos/errores del código a inglés
  Hecho cuando: `grep` de mensajes de código en español sin resultados fuera de docs; docs siguen en español. Cubre: RF-15 | Módulo: install.ps1, modules
- [ ] T10 v2: cerrar README y docs y eliminar temporal
  Hecho cuando: `README.md` cubre usos local/en línea/categorías/Git/códigos + crédito IA, `docs/estructura-proyecto.md` incluye SDD/`AGENTS.md`, y `ProximaActualizacion (Archivo Temporal).md` eliminado. Cubre: RF-16 | Módulo: validación
- [ ] T11 Validar cobertura RF por RF y fuera de alcance
  Hecho cuando: checklist RF-1 a RF-16 con test o revisión que lo cubre, y nada de Fuera de alcance en código/CLI. Cubre: todos | Módulo: validación

## Trazabilidad RF -> Tareas

- RF-1 -> T1, T3
- RF-2 -> T2
- RF-3 -> T6
- RF-4 -> T6
- RF-5 -> T6, T2
- RF-6 -> T4
- RF-7 -> T4
- RF-8 -> T4
- RF-9 -> T5
- RF-10 -> T3, T5
- RF-11 -> T2
- RF-12 -> T7, T2
- RF-13 -> T3
- RF-14 -> T8
- RF-15 -> T9
- RF-16 -> T10

## Dudas abiertas

- Sin bloqueantes. T8/T9/T10 son v2 y requieren aprobación de diff antes de cerrar.
