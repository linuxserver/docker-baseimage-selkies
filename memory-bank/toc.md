# Memory Bank — Table of Contents

**Project**: `slu-docker-rhel-selkies` (SLU fork of linuxserver/docker-baseimage-selkies)
**MB Version**: 2026-08 | **Last Updated**: 2026-08-27

## Core Files
| File | Purpose | Load When |
|------|---------|-----------|
| [projectbrief.md](./projectbrief.md) | Vision, goals, fork lineage | Complex tasks, orientation |
| [productContext.md](./productContext.md) | User goals, support scope, upstream | Complex tasks |
| [systemPatterns.md](./systemPatterns.md) | Architecture: build stages, s6 services, dual DE mode | Before arch changes |
| [techContext.md](./techContext.md) | Stack: base images, services, pinned versions | Session start |
| [activeContext.md](./activeContext.md) | Current sprint: RHEL9 support | Every session |
| [progress.md](./progress.md) | Status, blockers, priorities | Session start |

## Reference Files
| File | Purpose | Load When |
|------|---------|-----------|
| [projectRules.md](./projectRules.md) | Coding standards, generated-file rules | When uncertain |
| [decisions.md](./decisions.md) | ADRs | Arch decisions |
| [findings.md](./findings.md) | Cross-cutting findings registry (F01–F55, evidence-linked) | RHEL9 work, debugging |
| [quick-start.md](./quick-start.md) | Common commands, build/run/test | Fast track |
| [build-deployment.md](./build-deployment.md) | Build/deploy/Jenkins flow | Build work |
| [testing-patterns.md](./testing-patterns.md) | QA strategy, CI env vars | Test work |

## Tasks
| Path | Purpose |
|------|---------|
| [tasks/2026-08/README.md](./tasks/2026-08/README.md) | Monthly summary |
| [tasks/2026-08/270827_rhel9-vetting-plan-v4.md](./tasks/2026-08/270827_rhel9-vetting-plan-v4.md) | PLAN v3 vetting evidence + defect log (D1–D6) + PLAN v4 delta |
| [tasks/2026-08/270827_rhel9-build.md](./tasks/2026-08/270827_rhel9-build.md) | Phase-1 build log: 5 cycles (F31–F35/F41), test evidence, artifacts |
| [tasks/2026-08/280828_rhel9-gnome-desktop.md](./tasks/2026-08/280828_rhel9-gnome-desktop.md) | Task-2 build log: GNOME desktop (gnome-shell 40.10), 7 cycles (F42–F52, incl. SLU wallpaper), edge 4/4, artifacts |
| [tasks/2026-08/280828_phase1-5-nrp-dev-push.md](./tasks/2026-08/280828_phase1-5-nrp-dev-push.md) | Phase-1.5 dev: Docker Hub push (dgilli/selkies-rhel9:latest), pull-by-digest verify, NRP k8s mapping (deploy/), F28/F30/F55 closures |

## Operational
| Path | Purpose |
|------|---------|
| [ops-log.jsonl](./ops-log.jsonl) | Append-only session/state JSONL log |
