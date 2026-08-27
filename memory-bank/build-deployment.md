# Build & Deployment

## Upstream CI (reference — this fork currently reuses it)
- Jenkins job: `Docker-Pipeline-Builders/docker-baseimage-selkies/<branch>` (`jenkins-vars.yml`: `project_name: docker-baseimage-selkies`, `ls_branch: master`, `release_tag: debiantrixie`).
- Triggers: `.github/workflows/package_trigger_scheduler.yml` (package check builds) and `external_trigger_scheduler.yml` (upstream release triggers), both curl Jenkins.
- Multiarch: `MULTIARCH=true` (`jenkins-vars.yml:19`) — Jenkins builds `Dockerfile` (amd64) and `Dockerfile.aarch64` (arm64v8) and merges manifests. **Per-arch Dockerfile convention** (no buildx matrix in-repo).
- Outputs: `lsio/base/selkies` (dockerhub `lsiobase/selkies`), `ghcr.io/linuxserver/baseimage-selkies`, GitLab, Quay; dev `lsiodev/selkies-base`, PR `lspipepr/selkies-base` (`jenkins-vars.yml:15-17`, `Jenkinsfile:200-250`).

## SLU-local build (current path until CI is sorted)
```bash
# PREFLIGHT (required once per host): entitlement passthrough must work
podman run --rm registry.access.redhat.com/ubi9/ubi dnf repolist   # expect rhel-9-for-x86_64-*

podman build -f Dockerfile.rhel9 -t <registry>/baseimage-selkies:<tag-rhel9> .
podman push <registry>/baseimage-selkies:<tag-rhel9>
```
- **Entitled-host build constraint (PLAN v4)**: the rhel9 variant's vendored base stage (`FROM registry.access.redhat.com/ubi9/ubi`) resolves RHEL packages via podman's automatic entitlement passthrough — builds only succeed on **subscription-registered RHEL hosts**. Runtime needs no entitlement; NRP just pulls the image. (Rationale: `decisions.md` 2026-08-27 SLU-owned base ADR.)
- Registry/tag naming for SLU: **TBD** (open question in `activeContext.md`).
- No `latest` tag, by upstream convention.

## Deployment notes
- Image assumes `/config` volume; SSL certs auto-generated into `/config/ssl` on first boot (`init-nginx/run`).
- GPU: pass `--gpus all` + `DRI_NODE`/`DRINODE` envs (upstream behavior; RHEL9 variant must keep the same env contract).
- DinD: run `--privileged` (or mount docker socket) with `START_DOCKER=true` default.

## Checklist for a new distro variant
1. `Dockerfile.<distro>` mirroring stage architecture (`systemPatterns.md#1`)
2. `Dockerfile.<distro>.aarch64` if arm is in scope
3. Shared `root/` tree — verify every sed/package path exists on the new distro
4. Regenerate `package_versions.txt` equivalent for the variant
5. Smoke test per `testing-patterns.md`
6. `readme-vars.yml`/docs update (new tag row) — requires upstream-style builder or manual var edit
