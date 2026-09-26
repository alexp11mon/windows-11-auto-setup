# Tasks 001 - Instalador Automático Windows 11

Spec: `specs/001-instalador-win11/spec.md`. Plan: `specs/001-instalador-win11/plan.md`.

## Tareas

- [x] T1 Congelar verificación base v1 con suite mockeada
  Hecho cuando: `pwsh -NoProfile -File tests/Runner-Mock.ps1` en verde (102 checks). Cubre: RF-1 a RF-13 | Módulo: validación
  Verificado: 2026-09-26, 104/104 en verde (supera los 102 de la spec), exit 0.
- [x] T2 Validar entries local y online en simulación
  Hecho cuando: `.\install.ps1 -Category All -WhatIf` y `.\bootstrap.ps1 -Category All -WhatIf` con salida 0 sin descargas ni instalaciones. Cubre: RF-2, RF-11, RF-12 | Módulo: install.ps1, bootstrap.ps1
  Verificado por usuario 2026-09-26: `.\install.ps1 -Category All -WhatIf` y `.\bootstrap.ps1 -Category All -WhatIf` con salida 0 como admin, sin descargas ni instalaciones.
- [x] T3 Validar categorías e idempotencia winget
  Hecho cuando: `Invoke-InstallCategory -Category All` omite lo instalado vía `winget list --exact` y `Install-WingetApp` verifica post-install. Cubre: RF-1, RF-10, RF-13 | Módulo: Install-Category, Common
  Verificado: 2026-09-26, mock winget (omit=0 calls, post-verify ERROR, WhatIf noop, All=16), exit 0.
- [x] T4 Validar Git solo Dev/All con modos interactivo/params/skip
  Hecho cuando: con `-GitUserName/-GitUserEmail` no pregunta, con `-SkipGit` omite, con email inválido avisa y continúa, en `-WhatIf` sin datos no bloquea. Cubre: RF-6, RF-7, RF-8 | Módulo: Config-Git
  Verificado: 2026-09-26, suite 104/104 + mocks (params=4 calls sin Read-Host, email vacío/inválido WARNING sin calls, WhatIf sin datos no bloquea, SkipGit gating en install).
- [x] T5 Validar VSCode solo Dev/All con skip e idempotencia
  Hecho cuando: extensiones ausentes se instalan con `code --install-extension --force`, presentes se omiten, `-SkipVSCode` omite todo. Cubre: RF-9, RF-10 | Módulo: Config-VSCode
  Verificado: 2026-09-26, suite 104/104 (9 faltantes instaladas, 1 omitida, WhatIf 0 calls) + `--force` confirmado en código + SkipVSCode gating en install.
- [x] T6 Validar menú online, elevación y no-cierre bajo iex
  Hecho cuando: menú flechas + fallback numerado, `Esc`/vacío cancela con 0, elevación propaga exit, bajo `iex` usa `return` + `$LASTEXITCODE` sin cerrar consola. Cubre: RF-3, RF-4, RF-5 | Módulo: bootstrap.ps1
  Verificado: 2026-09-26, suite 104/104 (fallback funcional 2->1 y multi 1,3->A,C) + 7 rutas cancel con exit 0 + 0 exit pelados + elevación propaga `$child.ExitCode` con log visible.
- [x] T7 Validar logs, exit codes y PATH refrescado
  Hecho cuando: cada ejecución crea `logs/install-*.log`, cualquier `ERROR` deja `exit 1`, `Update-SessionPath` detecta `git`/`code` same-run o avisa re-ejecutar. Cubre: RF-12, RNF-3 | Módulo: Common, install.ps1
  Verificado: 2026-09-26, suite 104/104 (ERROR marca InstallHadErrors, merge PATH conserva sentinel sin duplicados) + logs/ limpio sin ERROR.
- [x] T8 v2: limpiar comentarios redundantes de IA
  Hecho cuando: revisión del diff en `modules/*.ps1`, `install.ps1`, `bootstrap.ps1` sin comentarios explicativos obvios. Cubre: RF-14 | Módulo: todos
  Verificado: 2026-09-26, limpieza mínima (quitado parafraseo/numeración obvia, conservadas decisiones D1-D8/iex/localización); `bootstrap.ps1` sin cambios (ya conciso); lógica intacta, suite 104/104.
- [x] T9 v2: pasar comentarios/avisos/errores del código a inglés
  Hecho cuando: `grep` de mensajes de código en español sin resultados fuera de docs; docs siguen en español. Cubre: RF-15 | Módulo: install.ps1, modules
  Verificado: 2026-09-26, `install.ps1`+`modules/` sin español (grep acentos + literales limpio); asserts actualizados (Runner-Mock + 3 Pester); suite 104/104 y Pester 41/41 en verde; docs en español.
- [x] T10 v2: cerrar README y docs y eliminar temporal
  Hecho cuando: `README.md` cubre usos local/en línea/categorías/Git/códigos + crédito IA, `docs/estructura-proyecto.md` incluye SDD/`AGENTS.md`, y `ProximaActualizacion (Archivo Temporal).md` eliminado. Cubre: RF-16 | Módulo: validación
  Verificado: 2026-09-26, README (usos + códigos + crédito IA + nota inglés en código, 104 checks) y estructura-proyecto (SDD/AGENTS.md) completos; temporal ya ausente en raíz y en `git status`; convención de idioma actualizada en `AGENTS.md` y constitución.
- [x] T11 Validar cobertura RF por RF y fuera de alcance
  Hecho cuando: checklist RF-1 a RF-16 con test o revisión que lo cubre, y nada de Fuera de alcance en código/CLI. Cubre: todos | Módulo: validación
  Verificado: 2026-09-26, RF-1..13 suite 104/104 + T1-T7, RF-14 diff T8, RF-15 grep + Pester 41/41, RF-16 revisión T10; fuera de alcance limpio en código/CLI (único hit `credentials` renombrado a `identity`; sin choco/scoop/tokens/telemetría/otros SO).

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

- Sin bloqueantes. T8/T9/T10 (v2) aprobados por el usuario el 2026-09-26 (traducción código+tests, limpieza mínima) y cerrados con suite + Pester en verde.
