# Tasks — 2026-08

## Housekeeping
### 2026-08-27: Memory Bank init + git reorganization
- Memory Bank created (v1, Debian-variant analysis) — re-committed on `rhel9` branch after user re-initialized the repo as full upstream clone
- Git: `origin` = user fork (dGilli), `upstream` = linuxserver (push disabled); branch `rhel9` cut from upstream master tip `69f4fc9`
- No task doc (housekeeping)

## Active
### [IN-PROGRESS] Add RHEL9 to supported images
- **State: `PLAN` (v2, fedora-based) — presented to user, awaiting approval**
- v1 (Debian port) superseded after user provided upstream fedora42-44 branches + `origin/el9` analysis
- Key references: upstream `fedora44` (current RPM-family pattern), upstream `el9` (deprecated, proves baseimage-el:9), CS9/EPEL9/RPMFusion package audit (live, 2026-08-27)
- See: `memory-bank/activeContext.md`, `memory-bank/systemPatterns.md#7-8`, `memory-bank/techContext.md`
- Plan doc: pending (created after approval, as `270827_rhel9-support.md`)

## Completed
(none yet)
