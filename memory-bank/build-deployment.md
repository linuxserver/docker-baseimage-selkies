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

podman build -f Dockerfile.rhel9 -t dgilli/baseimage-selkies:rhel9-p1-gnome .

# PUSH (phase 1.5 dev registry — Docker Hub, user decision 2026-08-28 / F30):
podman login docker.io            # rootless user (creds live in the rootless auth store)
podman tag dgilli/baseimage-selkies:rhel9-p1-gnome docker.io/dgilli/selkies-rhel9:latest
podman push docker.io/dgilli/selkies-rhel9:latest   # pushes an OCI manifest
# Registry manifest digest (for pinning — local store digest differs, see F30):
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:dgilli/selkies-rhel9:pull" | jq -r .token)
curl -sH "Authorization: Bearer $TOKEN" -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  https://registry-1.docker.io/v2/dgilli/selkies-rhel9/manifests/latest | sha256sum
```
- **Entitled-host build constraint (PLAN v4)**: the rhel9 variant's vendored base stage (`FROM registry.access.redhat.com/ubi9/ubi`) resolves RHEL packages via podman's automatic entitlement passthrough — builds only succeed on **subscription-registered RHEL hosts**. Runtime needs no entitlement; NRP just pulls the image. (Rationale: `decisions.md` 2026-08-27 SLU-owned base ADR.)
- **Dev registry (F30, resolved 2026-08-28)**: Docker Hub `dgilli/selkies-rhel9:latest` — currently = c8 `5c835fb6a147` (manifest `sha256:b70d42e3…`; first push was c7 = manifest `sha256:46246466…`). Production registry + tag scheme: open (SLU registry + NRP template merge). Upstream "no latest" convention applies to the public LSIO lineage, not the SLU dev namespace.
- podman → Docker Hub pushes **OCI** manifests: the local store's docker-format digest ≠ registry manifest digest — always pin/verify by registry digest.
- NRP k8s mapping for this image: `deploy/nrp-selkies-rhel9.yaml` (single port 3000; ws same-origin via nginx `/websocket`; no securityContext — F28).

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
