# Tasks 002 - OpenCode + Brave V2

Spec: `specs/002-opencode-brave-v2/spec.md`. Plan: `specs/002-opencode-brave-v2/plan.md`.

## Tareas

- [x] T12 Versionar snapshot de la configuración global de OpenCode
  Hecho cuando: `config/opencode/` contiene agents, skills, plugins y `opencode.jsonc` y el grep de `token|password|secret|api[_-]?key` da 0 resultados. Cubre: RF-19, RF-21 | Módulo: config/opencode
  Verificado: 2026-09-26, 12 ficheros idénticos al origen (cmp OK), grep 0 resultados, suite 104/104.
- [x] T13 Versionar catálogo de extensiones de Brave
  Hecho cuando: `config/brave/extensions.json` es JSON válido con las 5 extensiones (uBlock Origin Lite, Dark Reader, Decentraleyes, Bitwarden, Privacy Badger). Cubre: RF-22 | Módulo: config/brave
  Verificado: 2026-09-26, JSON válido con 5 IDs de 32 chars, suite 104/104.
- [x] T14 Implementar `Config-OpenCode` con tests primero
  Hecho cuando: `pwsh -NoProfile -File tests/Runner-Mock.ps1` en verde y `Config-OpenCode.Tests.ps1` en verde (detección, install oficial mockeado con reintento, fusión conserva-con-aviso, omisión de secretos, `-WhatIf` sin efectos). Cubre: RF-17, RF-18, RF-19, RF-20, RF-21, RF-25, RF-26 | Módulo: Config-OpenCode
  Verificado: 2026-09-26, Runner 148/148 (Bloque 9: 27 checks) + Pester 8/8. Hallazgos: Pester 6 no mockea `opencode` (.ps1 externo) → overrides con `function`; `AfterEach` dentro de `Describe`; fixtures de descarga con switch `-UseBasicParsing`; overrides de `Get-Command` en ámbito script.
- [x] T15 Implementar `Config-Brave` con tests primero
  Hecho cuando: `pwsh -NoProfile -File tests/Runner-Mock.ps1` en verde y `Config-Brave.Tests.ps1` en verde (Brave ausente → instalar primero, idempotencia por extensión, aviso de reinicio, `-WhatIf` sin efectos). Cubre: RF-22, RF-23, RF-26 | Módulo: Config-Brave
  Verificado: 2026-09-26, Runner 148/148 (Bloque 10: 16 checks) + Pester 6/6. Registro real solo en clave HKCU temporal con limpieza; reuso de `Install-WingetApp` para RF-23 (sin doble `ShouldProcess`, patrón D3).
- [x] T16 Integrar flags y menú en `install.ps1` y `bootstrap.ps1`
  Hecho cuando: `.\install.ps1 -Category All -WhatIf` y `.\bootstrap.ps1 -Category All -WhatIf` con salida 0, `-SkipOpenCode`/`-SkipBrave` omiten su bloque, y cancelar el menú nuevo sale con 0 sin cambios. Cubre: RF-24, RF-26 | Módulo: install.ps1, bootstrap.ps1
  Verificado: 2026-09-26, suite 159/159 + Pester 59/59 (gating, propagación elevArgs/installArgs, pregunta OpenCode, sin pregunta Brave, 0 `exit` pelados). Demo `-WhatIf` con salida 0 pendiente de sesión admin (pasa a T18).
- [x] T17 Actualizar docs y enmienda P2
  Hecho cuando: revisión del diff muestra README (OpenCode + Brave + skips), `docs/estructura-proyecto.md` (módulos y config nuevos), `docs/constitution.md` + `AGENTS.md` (excepción P2/RF-17), todo en español con código en inglés. Cubre: RF-27 | Módulo: docs
  Verificado: 2026-09-26, diff revisado (README secciones OpenCode/Brave + conteos 159/59, estructura-proyecto árbol V2, P2 con excepción RF-17, AGENTS actualizado); addendum menú (sin pregunta Brave) ratificado en plan.md.
- [x] T18 Validar cobertura RF por RF y fuera de alcance
  Hecho cuando: checklist RF-17 a RF-27 con test o revisión que lo cubre, suite mockeada + Pester en verde, log `-WhatIf` sin `ERROR` imprevisto, y nada de Fuera de alcance en código/CLI. Cubre: todos | Módulo: validación
  Verificado: 2026-09-26, Runner 159/159 + Pester 59/59; RF-17..27 trazados a Bloques 7-10/entry tests/T12/T13/diff T17; grep fuera-de-alcance 0 hits en `*.ps1`; demo admin por usuario: `install -WhatIf` EXIT 0 ("Completed successfully", implica sin `ERROR`) y `bootstrap -WhatIf` EXIT 0; `logs/` sin `ERROR`.

## Trazabilidad RF -> Tareas

- RF-17 -> T14
- RF-18 -> T14
- RF-19 -> T12, T14
- RF-20 -> T14
- RF-21 -> T12, T14
- RF-22 -> T13, T15
- RF-23 -> T15
- RF-24 -> T16
- RF-25 -> T14
- RF-26 -> T14, T15, T16
- RF-27 -> T17

## Dudas abiertas

- Sin bloqueantes. RF-20 resuelto en spec (conservar con aviso).
