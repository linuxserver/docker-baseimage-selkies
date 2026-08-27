# Tasks — 2026-08

## Housekeeping
### 2026-08-27: Memory Bank init + git reorganization
- Memory Bank created (v1, Debian-variant analysis) — re-committed on `rhel9` branch after user re-initialized the repo as full upstream clone
- Git: `origin` = user fork (dGilli), `upstream` = linuxserver (push disabled); branch `rhel9` cut from upstream master tip `69f4fc9`
- No task doc (housekeeping)

## Active
### [IN-PROGRESS] Add RHEL9 to supported images
- **State: `PLAN v4` — vetted + approved 2026-08-27; docs/MB updated; build ON HOLD per user**
- History: v1 (Debian port) → v2/v3 (fedora44-modeled, baseimage-el:9) → **vetting** found baseimage-el deprecated + Oracle-repo-based + 6 defects → **v4** (SLU-owned UBI9 base + entitled RHEL repos, D1–D6 fixes)
- **Vetting/defect log: `270827_rhel9-vetting-plan-v4.md`** (evidence for every finding)
- Key references: upstream `fedora44` (current RPM-family pattern), upstream `el9` (deprecated; proved the stack, and its svc-xorg/-vfbdevice deletion = D5 evidence), entitled RHEL 9.8 host repoquery (authoritative package audit)
- See: `memory-bank/activeContext.md#PLAN-v4`, `memory-bank/decisions.md` (2 new ADRs), `memory-bank/techContext.md`

## Completed
(none yet)
